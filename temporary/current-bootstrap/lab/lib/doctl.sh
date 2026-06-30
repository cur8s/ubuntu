#!/usr/bin/env bash

# shellcheck source=../../lib/common.sh
source "${UBUNTU_BOOTSTRAP_ROOT:?}/lib/common.sh"

lab_state_dir() {
  printf '%s/.state\n' "$UBUNTU_BOOTSTRAP_ROOT"
}

lab_config_file() {
  printf '%s/digitalocean.env\n' "$(lab_state_dir)"
}

lab_state_file() {
  printf '%s/lab-vm.env\n' "$(lab_state_dir)"
}

lab_cloud_init_file() {
  printf '%s/lab/cloud-init.yaml\n' "$UBUNTU_BOOTSTRAP_ROOT"
}

lab_init_config() {
  local root
  local state_dir
  local config_file

  root="$UBUNTU_BOOTSTRAP_ROOT"
  state_dir="$(lab_state_dir)"
  config_file="$(lab_config_file)"

  mkdir -p "$state_dir"

  if [ -f "$config_file" ]; then
    log "local lab config already exists: $config_file"
    return 0
  fi

  cp "$root/lab/digitalocean.env.example" "$config_file"
  log "created local lab config: $config_file"
}

load_lab_config() {
  local config_file

  config_file="$(lab_config_file)"
  if [ -f "$config_file" ]; then
    # shellcheck disable=SC1090
    source "$config_file"
  fi

  : "${DO_REGION:=tor1}"
  : "${DO_SIZE:=s-1vcpu-1gb}"
  : "${DO_IMAGE:=ubuntu-24-04-x64}"
  : "${DO_DROPLET_NAME:=cur8s-ubuntu-lab}"
  : "${DO_TAG:=cur8s-ubuntu-test}"
  : "${DO_SSH_USER:=root}"
  : "${DO_SSH_KEY_NAME:=cur8s-ubuntu-lab}"
  : "${DO_SSH_KEY_PATH:=${HOME}/.ssh/cur8s-ubuntu-lab_ed25519}"
  : "${DO_SSH_RETRY_MAX:=60}"
  : "${DO_REMOTE_DIR:=/root/ubuntu-bootstrap}"
}

load_lab_state() {
  local state_file

  state_file="$(lab_state_file)"
  if [ -f "$state_file" ]; then
    # shellcheck disable=SC1090
    source "$state_file"
  fi
}

require_doctl() {
  require_command doctl
}

require_doctl_auth() {
  doctl account get >/dev/null || die "doctl is not authenticated or the token is invalid"
}

lab_generate_ssh_key() {
  local key_path="$DO_SSH_KEY_PATH"
  local key_dir

  key_dir="$(dirname -- "$key_path")"
  mkdir -p "$key_dir"
  chmod 700 "$key_dir"
  require_command ssh-keygen

  if [ -f "$key_path" ]; then
    log "SSH private key already exists: $key_path"
  else
    ssh-keygen -t ed25519 -f "$key_path" -N "" -C "$DO_SSH_KEY_NAME"
    chmod 600 "$key_path"
    log "generated SSH private key: $key_path"
  fi

  if [ ! -f "${key_path}.pub" ]; then
    ssh-keygen -y -f "$key_path" > "${key_path}.pub"
    chmod 644 "${key_path}.pub"
    log "generated SSH public key: ${key_path}.pub"
  fi
}

lab_ensure_local_ssh_key() {
  [ -f "$DO_SSH_KEY_PATH" ] || die "missing SSH private key: $DO_SSH_KEY_PATH; run ./lab/lab-vm init-key"
  [ -f "${DO_SSH_KEY_PATH}.pub" ] || die "missing SSH public key: ${DO_SSH_KEY_PATH}.pub; run ./lab/lab-vm init-key"
}

lab_do_ssh_key_id() {
  doctl compute ssh-key list --format ID,Name --no-header |
    awk -v name="$DO_SSH_KEY_NAME" '$2 == name { print $1; exit }'
}

lab_ensure_do_ssh_key() {
  local key_id

  lab_ensure_local_ssh_key
  key_id="$(lab_do_ssh_key_id)"

  if [ -n "$key_id" ]; then
    log "DigitalOcean SSH key already exists: $DO_SSH_KEY_NAME ($key_id)" >&2
    printf '%s\n' "$key_id"
    return 0
  fi

  doctl compute ssh-key import "$DO_SSH_KEY_NAME" \
    --public-key-file "${DO_SSH_KEY_PATH}.pub" \
    --format ID \
    --no-header
}

lab_droplet_info_by_name() {
  doctl compute droplet list --format ID,Name,PublicIPv4,Status --no-header |
    awk -v name="$DO_DROPLET_NAME" '$2 == name { print; exit }'
}

lab_droplet_info_by_id() {
  local droplet_id="$1"

  doctl compute droplet get "$droplet_id" --format ID,Name,PublicIPv4,Status --no-header
}

lab_write_state() {
  local droplet_id="$1"
  local droplet_name="$2"
  local public_ipv4="$3"
  local status="$4"
  local state_file

  state_file="$(lab_state_file)"
  mkdir -p "$(dirname -- "$state_file")"

  {
    printf 'DO_DROPLET_ID=%q\n' "$droplet_id"
    printf 'DO_DROPLET_NAME=%q\n' "$droplet_name"
    printf 'DO_DROPLET_IPV4=%q\n' "$public_ipv4"
    printf 'DO_DROPLET_STATUS=%q\n' "$status"
  } > "$state_file"

  log "wrote lab VM state: $state_file"
}

lab_refresh_state() {
  local info
  local droplet_id
  local droplet_name
  local public_ipv4
  local status

  load_lab_state

  if [ -n "${DO_DROPLET_ID:-}" ]; then
    info="$(lab_droplet_info_by_id "$DO_DROPLET_ID" 2>/dev/null || true)"
  else
    info="$(lab_droplet_info_by_name || true)"
  fi

  [ -n "$info" ] || return 1

  read -r droplet_id droplet_name public_ipv4 status <<< "$info"
  lab_write_state "$droplet_id" "$droplet_name" "$public_ipv4" "$status"
  return 0
}

lab_create_droplet() {
  local ssh_key_id
  local cloud_init_file
  local info
  local droplet_id
  local droplet_name
  local public_ipv4
  local status

  if info="$(lab_droplet_info_by_name)" && [ -n "$info" ]; then
    read -r droplet_id droplet_name public_ipv4 status <<< "$info"
    lab_write_state "$droplet_id" "$droplet_name" "$public_ipv4" "$status"
    log "lab Droplet already exists: $droplet_name ($droplet_id)"
    return 0
  fi

  ssh_key_id="$(lab_ensure_do_ssh_key)"
  cloud_init_file="$(lab_cloud_init_file)"

  log "creating DigitalOcean Droplet: $DO_DROPLET_NAME"
  info="$(
    doctl compute droplet create "$DO_DROPLET_NAME" \
      --image "$DO_IMAGE" \
      --size "$DO_SIZE" \
      --region "$DO_REGION" \
      --ssh-keys "$ssh_key_id" \
      --tag-name "$DO_TAG" \
      --user-data-file "$cloud_init_file" \
      --wait \
      --format ID,Name,PublicIPv4,Status \
      --no-header
  )"

  read -r droplet_id droplet_name public_ipv4 status <<< "$info"
  lab_write_state "$droplet_id" "$droplet_name" "$public_ipv4" "$status"
  log "created lab Droplet: $droplet_name ($droplet_id) $public_ipv4"
}

lab_status() {
  if lab_refresh_state; then
    load_lab_state
    printf 'id=%s\nname=%s\nipv4=%s\nstatus=%s\n' \
      "${DO_DROPLET_ID:-}" \
      "${DO_DROPLET_NAME:-}" \
      "${DO_DROPLET_IPV4:-}" \
      "${DO_DROPLET_STATUS:-}"
  else
    die "no lab Droplet found for name: $DO_DROPLET_NAME"
  fi
}

lab_ssh_target() {
  lab_refresh_state >/dev/null || die "no lab Droplet found; run ./lab/lab-vm create"
  load_lab_state
  [ -n "${DO_DROPLET_IPV4:-}" ] || die "lab Droplet has no public IPv4 address yet"
  printf '%s@%s\n' "$DO_SSH_USER" "$DO_DROPLET_IPV4"
}

lab_ssh_base() {
  ssh \
    -i "$DO_SSH_KEY_PATH" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=5 \
    "$@"
}

lab_ssh() {
  local target

  lab_ensure_local_ssh_key
  target="$(lab_ssh_target)"

  if [ "$#" -gt 0 ]; then
    lab_ssh_base "$target" "$@"
  else
    lab_ssh_base "$target"
  fi
}

lab_remote() {
  local command="$1"
  local target

  lab_ensure_local_ssh_key
  target="$(lab_ssh_target)"
  lab_ssh_base "$target" "$command"
}

lab_wait_for_ssh() {
  local attempt
  local target

  lab_ensure_local_ssh_key
  target="$(lab_ssh_target)"

  log "waiting for SSH on $target"
  for attempt in $(seq 1 "$DO_SSH_RETRY_MAX"); do
    if lab_ssh_base -o BatchMode=yes "$target" true >/dev/null 2>&1; then
      log "SSH is ready"
      return 0
    fi
    sleep 5
  done

  die "SSH did not become ready after $DO_SSH_RETRY_MAX attempts"
}

lab_validate_remote_dir() {
  case "$DO_REMOTE_DIR" in
    /*) ;;
    *) die "DO_REMOTE_DIR must be an absolute path" ;;
  esac

  case "$DO_REMOTE_DIR" in
    *[!A-Za-z0-9_./-]*)
      die "DO_REMOTE_DIR contains unsupported characters: $DO_REMOTE_DIR"
      ;;
  esac
}

lab_sync_repo() {
  local root
  local target

  lab_validate_remote_dir
  root="$UBUNTU_BOOTSTRAP_ROOT"
  target="$(lab_ssh_target)"

  log "syncing repo to $target:$DO_REMOTE_DIR"
  (
    cd "$root"
    tar --exclude .git --exclude .state -czf - .
  ) | lab_ssh_base "$target" "rm -rf '$DO_REMOTE_DIR' && mkdir -p '$DO_REMOTE_DIR' && tar -xzf - -C '$DO_REMOTE_DIR'"
}

lab_destroy_droplet() {
  local droplet_id=""

  load_lab_state
  if [ -n "${DO_DROPLET_ID:-}" ]; then
    droplet_id="$DO_DROPLET_ID"
  else
    local info
    info="$(lab_droplet_info_by_name || true)"
    [ -n "$info" ] || die "no lab Droplet found for name: $DO_DROPLET_NAME"
    read -r droplet_id _ <<< "$info"
  fi

  log "destroying lab Droplet: $droplet_id"
  doctl compute droplet delete "$droplet_id" --force
  rm -f "$(lab_state_file)"
  log "destroyed lab Droplet: $droplet_id"
}
