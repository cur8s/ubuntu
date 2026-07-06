#!/usr/bin/env bash
# qemu-vm.sh — a disposable Ubuntu VM on QEMU, in one vendorable file.
#
# Give it a plain cloud-init user-data file, get an Ubuntu cloud VM on
# localhost:$QVM_SSH_PORT in a couple of minutes — the same #cloud-config
# you would hand a real cloud host, passed through verbatim. destroy-vm
# leaves nothing behind but the cached image.
#
# Upstream: https://github.com/cur8s/qemu        Version: 0.3.0
# This file is designed to be vendored: copy it into any repository that
# needs a quick VM and keep this header. Refresh a vendored copy with:
#   gh api -H "Accept: application/vnd.github.raw" \
#     "repos/cur8s/qemu/contents/qemu-vm.sh?ref=vX.Y.Z" > qemu-vm.sh
# Patches go upstream, never into vendored copies.
#
# Requirements:
#   macOS:  Apple silicon; brew install qemu  (hdiutil builds the seed ISO)
#   Linux:  qemu-system-x86 or qemu-system-arm, qemu-utils, and
#           genisoimage or xorriso; access to /dev/kvm
#
# HOW IT WORKS
#   A VM is a directory. $QVM_DIR holds everything about one VM:
#     disk.qcow2    copy-on-write overlay; the cached image stays pristine
#     seed.iso      your user-data, verbatim, as a cloud-init NoCloud seed
#     seed/         the user-data + meta-data seed.iso is built from
#     efivars.fd    writable UEFI variable store (arm64 guests only)
#     qemu.pid      the single QEMU process; start-vm daemonizes, destroy-vm kills
#     console.log   the serial console output; show-boot-log follows it
#     known_hosts   this VM's host key; dies with the VM
#   $QVM_CACHE_DIR holds checksum-verified upstream images shared by every
#   VM. The guest architecture follows the host (hvf on macOS Apple
#   silicon, KVM on Linux) — no foreign-arch emulation. The guest reaches
#   the world through user-mode NAT; the host reaches the guest only via
#   one forwarded SSH port. No daemons, no root, no state anywhere else.
#
# USAGE: qemu-vm.sh <command> [args]
#   Lifecycle    build-vm          build the VM's on-disk state: overlay
#                                  disk, your user-data as the seed,
#                                  firmware vars; starts nothing
#                start-vm          start (or restart) the VM's process,
#                                  daemonized
#                wait-until-ready <user> <identity-file>
#                                  block until the VM is ready: ssh in as
#                                  <user> and poll cloud-init until it
#                                  reports done (rides out a first-boot
#                                  reboot; fails fast on the error state)
#                destroy-vm        kill the VM, delete $QVM_DIR
#   Access       ssh <user> <identity-file> [command...]
#   Support      fetch-image       download + checksum-verify the cloud
#                                  image into the cache (build-vm does this
#                                  itself; standalone for pre-warming)
#                status            image / state / process facts. The
#                                  vocabulary is stable for wrappers to
#                                  parse: image cached|missing, vm
#                                  running|stopped|absent
#                show-boot-log     print the VM's boot log (serial console
#                                  output) and follow new lines — the
#                                  debug window when SSH is down
#                help              this text
#
# A SESSION
#   QVM_USER_DATA=./user-data.yaml qemu-vm.sh build-vm
#   qemu-vm.sh start-vm
#   qemu-vm.sh wait-until-ready ubuntu ./key
#   qemu-vm.sh ssh              ubuntu ./key
#   qemu-vm.sh destroy-vm
#
# CONFIGURATION (environment; every value has a default)
#   QVM_DIR            VM state dir                 (default: ./.qvm/vm)
#   QVM_CACHE_DIR      image cache dir              (default: ./.qvm/cache)
#   QVM_NAME           instance-id + hostname       (default: qemu-vm)
#   QVM_USER_DATA      cloud-init user-data file    (required by build-vm)
#   QVM_IMAGE_URL      cloud image                  (default: Ubuntu 24.04
#                      noble, current, host architecture)
#   QVM_SHA256SUMS_URL checksum file                (default: SHA256SUMS
#                      beside the image URL)
#   QVM_SSH_PORT       forwarded SSH port           (default: 2222)
#   QVM_SSH_IDENTITY_AGENT                          (default: none)
#                      agent socket for ssh signatures. The default
#                      signs with the identity file alone and blocks a
#                      globally configured secrets-manager agent from
#                      intercepting; point it at a socket when the
#                      private half lives in an agent (e.g. -i key.pub)
#   QVM_QUIET          set to 1 to silence informational lines; errors,
#                      status, and the boot log always print
#   QVM_CPUS / QVM_MEMORY / QVM_DISK_SIZE           (default: 4 / 4G / 20G)
#   QVM_WAIT_TIMEOUT_SECONDS                        (default: 1200)
#   Keep QVM_DIR and QVM_CACHE_DIR free of commas (QEMU's -drive option
#   grammar) — simple absolute paths are safest.
set -euo pipefail

# === configuration ======================================================
# Case is the contract: UPPERCASE QVM_* variables are the documented,
# env-overridable interface; lowercase variables are internal and
# cannot be set from outside.

QVM_DIR="${QVM_DIR:-./.qvm/vm}"
QVM_CACHE_DIR="${QVM_CACHE_DIR:-./.qvm/cache}"
# QEMU -daemonize chdirs to /: every path handed to it must be absolute.
[[ $QVM_DIR = /* ]] || QVM_DIR="$PWD/${QVM_DIR#./}"
[[ $QVM_CACHE_DIR = /* ]] || QVM_CACHE_DIR="$PWD/${QVM_CACHE_DIR#./}"
QVM_NAME="${QVM_NAME:-qemu-vm}"
QVM_SSH_PORT="${QVM_SSH_PORT:-2222}"
QVM_SSH_IDENTITY_AGENT="${QVM_SSH_IDENTITY_AGENT:-none}"
QVM_QUIET="${QVM_QUIET:-}"
QVM_CPUS="${QVM_CPUS:-4}"
QVM_MEMORY="${QVM_MEMORY:-4G}"
QVM_DISK_SIZE="${QVM_DISK_SIZE:-20G}"
QVM_WAIT_TIMEOUT_SECONDS="${QVM_WAIT_TIMEOUT_SECONDS:-1200}"

# === helpers ===========================================================
# Function naming: every function is a verb phrase. detect_* probes
# the host; resolve_* derives values into variables; *_is_* answers
# yes/no; cmd_<verb> implements the CLI verb of the same name; the
# rest act (make_seed_iso, start_qemu_process).

# Informational output; QVM_QUIET=1 silences it so an embedding
# harness can own the narration. Errors never route through here.
say() {
  [[ -n $QVM_QUIET ]] || echo "$@"
}

# The guest architecture follows the host: hvf and KVM cannot cross.
detect_guest_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo arm64 ;;
    x86_64)        echo amd64 ;;
    *) echo "qemu-vm: unsupported host architecture: $(uname -m)" >&2; exit 1 ;;
  esac
}

# The image trio: where the image comes from (image_url), where its
# checksums live (checksums_url), where the cached copy lands
# (cached_image_path). Resolved on demand rather than at startup so
# that only the commands that touch the image pay for it — and so help
# still works on an unsupported host. QVM_IMAGE_URL and
# QVM_SHA256SUMS_URL are the env overrides.
resolve_image_locations() {
  image_url="${QVM_IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-$(detect_guest_arch).img}"
  # dirname is pure string surgery, so it works on URLs too.
  checksums_url="${QVM_SHA256SUMS_URL:-$(dirname "$image_url")/SHA256SUMS}"
  cached_image_path="$QVM_CACHE_DIR/$(basename "$image_url")"
}

# kill -0 sends no signal; it only probes that the pid exists. (Standard
# pidfile caveats apply: a recycled pid can read as running.)
vm_is_running() {
  [[ -f "$QVM_DIR/qemu.pid" ]] && kill -0 "$(cat "$QVM_DIR/qemu.pid")" 2>/dev/null
}

# The platform truth table: every host-dependent launch fact in one
# place, one row per supported host. Sets qemu_bin, machine, accel, and
# the EDK2 UEFI firmware pair — empty uefi_* means the platform boots
# its default BIOS (SeaBIOS) and needs no firmware drives. Called only
# by build-vm/start-vm: the brew lookup in the Darwin/arm64 row is the
# one thing here that can fail, and status/help must never pay for it.
# To support a new host, add a row.
detect_platform() {
  case "$(uname -s)/$(detect_guest_arch)" in
    # Apple silicon (Darwin is the macOS kernel)
    Darwin/arm64)
      local brew_qemu
      brew_qemu="$(brew --prefix qemu)/share/qemu"
      qemu_bin="qemu-system-aarch64" machine="virt" accel="hvf"
      uefi_code="$brew_qemu/edk2-aarch64-code.fd"
      uefi_vars="$brew_qemu/edk2-arm-vars.fd"
      ;;
    Linux/arm64)
      qemu_bin="qemu-system-aarch64" machine="virt" accel="kvm"
      uefi_code="/usr/share/AAVMF/AAVMF_CODE.fd"
      uefi_vars="/usr/share/AAVMF/AAVMF_VARS.fd"
      ;;
    Linux/amd64)
      qemu_bin="qemu-system-x86_64" machine="q35" accel="kvm"
      uefi_code="" uefi_vars=""
      ;;
    # Intel Macs (Darwin/amd64) are deliberately absent: untested and
    # unneeded. If that ever changes, support is one new row.
    *)
      echo "qemu-vm: unsupported host: $(uname -s) $(uname -m)" >&2
      exit 1
      ;;
  esac
}

# Build the NoCloud seed ISO (volume label "cidata") from a directory
# holding user-data + meta-data. hdiutil on macOS; genisoimage or
# xorriso on Linux.
make_seed_iso() {
  local seed_dir="$1" seed_iso="$2"
  if command -v hdiutil >/dev/null 2>&1; then
    hdiutil makehybrid -quiet -iso -joliet -default-volume-name cidata \
      -o "$seed_iso" "$seed_dir"
  elif command -v genisoimage >/dev/null 2>&1; then
    genisoimage -quiet -output "$seed_iso" -volid cidata -joliet -rock "$seed_dir"
  elif command -v xorriso >/dev/null 2>&1; then
    xorriso -as mkisofs -quiet -output "$seed_iso" -volid cidata -joliet -rock "$seed_dir" 2>/dev/null
  else
    echo "qemu-vm: no ISO tool found (install genisoimage or xorriso)." >&2
    exit 1
  fi
}

# Launch the guest, daemonized. One QEMU process per $QVM_DIR; the
# pidfile is the lifecycle handle, the serial console goes to a file.
# All host-dependent facts come from the platform table;
# -cpu host on every platform (no emulation). UEFI platforms boot from
# two pflash drives — read-only code plus the writable per-VM varstore
# that build-vm copied; the others boot SeaBIOS implicitly.
start_qemu_process() {
  detect_platform

  local overlay_disk="if=virtio,format=qcow2,file=$QVM_DIR/disk.qcow2"            # CoW overlay; cache stays pristine
  local cloud_init_seed="if=virtio,format=raw,readonly=on,file=$QVM_DIR/seed.iso" # your user-data, verbatim
  local ssh_forward="user,id=net0,hostfwd=tcp:127.0.0.1:${QVM_SSH_PORT}-:22"      # user-mode NAT: no root, no bridges
  local console_log="file:$QVM_DIR/console.log"                                   # serial console -> file

  # The pflash pair rides in an array: filled on UEFI platforms,
  # empty on SeaBIOS ones.
  local uefi_drives=()
  if [[ -n $uefi_code ]]; then
    uefi_drives=(
      -drive "if=pflash,format=raw,readonly=on,file=$uefi_code"
      -drive "if=pflash,format=raw,file=$QVM_DIR/efivars.fd"
    )
  fi

  # One option per line, simplest first. Two ordering rules matter to
  # QEMU: -netdev must precede the -device that references it, and the
  # overlay disk precedes the seed so it enumerates as the boot disk.
  "$qemu_bin" \
    -daemonize \
    -display none \
    -cpu host \
    -machine "$machine" \
    -accel "$accel" \
    -smp "$QVM_CPUS" \
    -m "$QVM_MEMORY" \
    -pidfile "$QVM_DIR/qemu.pid" \
    -serial "$console_log" \
    -drive "$overlay_disk" \
    -drive "$cloud_init_seed" \
    -netdev "$ssh_forward" \
    -device virtio-net-pci,netdev=net0 \
    "${uefi_drives[@]}"
}

# Poll cloud-init over SSH until it reports done; used twice by
# cmd_wait_until_ready to ride out a first-boot reboot.
wait_for_cloud_init() {
  local user="$1" identity="$2" deadline="$3" cloud_init_status
  until cmd_ssh "$user" "$identity" cloud-init status --wait >/dev/null 2>&1; do
    # A reachable VM whose cloud-init landed in the error state will
    # never turn done: fail now instead of spinning out the deadline.
    # (Not piped to grep: cloud-init status exits nonzero in the error
    # state, and pipefail would fail that pipeline before grep could
    # report the match.)
    cloud_init_status="$(cmd_ssh "$user" "$identity" cloud-init status 2>/dev/null || true)"
    if [[ $cloud_init_status == *'status: error'* ]]; then
      echo "cloud-init finished in the error state; inspect the console log." >&2
      exit 1
    fi
    if [[ $(date +%s) -ge $deadline ]]; then
      echo "Timed out waiting for cloud-init to finish." >&2
      exit 1
    fi
    sleep 10
  done
}

# === lifecycle =========================================================

cmd_build_vm() {
  if [[ -e $QVM_DIR ]]; then
    echo "A VM already exists at $QVM_DIR (run destroy-vm first)." >&2
    exit 1
  fi
  if [[ -z ${QVM_USER_DATA:-} || ! -f ${QVM_USER_DATA:-} ]]; then
    echo "Set QVM_USER_DATA to a cloud-init user-data file." >&2
    exit 1
  fi
  resolve_image_locations
  cmd_fetch_image
  mkdir -p "$QVM_DIR"

  # Copy-on-write overlay: the cached base image stays pristine;
  # cloud-init's growpart expands the filesystem on first boot.
  qemu-img create -q -f qcow2 -b "$cached_image_path" -F qcow2 \
    "$QVM_DIR/disk.qcow2" "$QVM_DISK_SIZE"

  # The NoCloud seed: your user-data verbatim, plus minimal meta-data.
  local seed_dir="$QVM_DIR/seed"
  mkdir -p "$seed_dir"
  cp "$QVM_USER_DATA" "$seed_dir/user-data"
  printf 'instance-id: %s\nlocal-hostname: %s\n' "$QVM_NAME" "$QVM_NAME" \
    > "$seed_dir/meta-data"
  make_seed_iso "$seed_dir" "$QVM_DIR/seed.iso"

  # UEFI platforms get their own writable variable store.
  detect_platform
  if [[ -n $uefi_vars ]]; then
    cp "$uefi_vars" "$QVM_DIR/efivars.fd"
  fi
  say "VM prepared in $QVM_DIR (start it with: qemu-vm.sh start-vm)"
}

cmd_start_vm() {
  [[ $# -eq 0 ]] || { echo "start-vm takes no arguments." >&2; exit 1; }
  if [[ ! -d $QVM_DIR ]]; then
    echo "No VM found at $QVM_DIR (run build-vm first)." >&2
    exit 1
  fi
  if vm_is_running; then
    echo "The VM is already running (pid $(cat "$QVM_DIR/qemu.pid"))." >&2
    exit 1
  fi
  # Probe the forward port before QEMU does: its own failure is option
  # grammar, not guidance. bash's /dev/tcp needs no extra tools.
  if (exec 3<>"/dev/tcp/127.0.0.1/$QVM_SSH_PORT") 2>/dev/null; then
    echo "qemu-vm: port $QVM_SSH_PORT on 127.0.0.1 is already in use (another VM, or a stale process?)." >&2
    exit 1
  fi
  start_qemu_process
  say "VM booting: SSH forwarded to 127.0.0.1:$QVM_SSH_PORT (watch: qemu-vm.sh show-boot-log)"
}

cmd_wait_until_ready() {
  [[ $# -eq 2 ]] || { echo "usage: qemu-vm.sh wait-until-ready <user> <identity-file>" >&2; exit 1; }
  local deadline
  deadline=$(( $(date +%s) + QVM_WAIT_TIMEOUT_SECONDS ))
  say "Waiting for cloud-init to finish (a first boot may upgrade and reboot)..."
  wait_for_cloud_init "$1" "$2" "$deadline"
  # A first-boot power_state reboot fires the moment cloud-init reports
  # done, so that success may be the pre-reboot instance. Let the reboot
  # land, then require done again on the far side; on a settled VM the
  # second pass returns immediately.
  sleep 15
  wait_for_cloud_init "$1" "$2" "$deadline"
  say "cloud-init is done; the VM is ready."
}

cmd_destroy_vm() {
  if [[ ! -e $QVM_DIR ]]; then
    say "No VM to destroy."
    return 0
  fi
  if vm_is_running; then
    local pid
    pid="$(cat "$QVM_DIR/qemu.pid")"
    kill "$pid"
    # Do not remove the disk under a live process.
    local waited=0
    while kill -0 "$pid" 2>/dev/null; do
      if [[ $waited -ge 30 ]]; then
        echo "QEMU (pid $pid) did not exit after SIGTERM; refusing to delete its state." >&2
        exit 1
      fi
      sleep 1
      waited=$((waited + 1))
    done
  fi
  rm -rf "$QVM_DIR"
  say "VM destroyed (cached image kept in $QVM_CACHE_DIR)."
}

# === access ============================================================

# SSH into the VM; also the probe wait_for_cloud_init polls with.
# Every option is load-bearing:
#   UserKnownHostsFile in $QVM_DIR   each fresh VM presents a new host
#   + StrictHostKeyChecking          key on the same port; trust it on
#     accept-new                     first contact, pin it for the VM's
#                                    lifetime, discard it with the VM
#   IdentitiesOnly + IdentityAgent   sign with the -i identity and
#     $QVM_SSH_IDENTITY_AGENT        nothing else. The default (none)
#                                    blocks a globally configured
#                                    secrets-manager agent (ssh config
#                                    IdentityAgent) from intercepting;
#                                    a consumer whose private half
#                                    lives in an agent points this at
#                                    that agent's socket
#   ConnectTimeout / ServerAlive*    fail fast while the VM boots; drop
#                                    dead connections during reboots
cmd_ssh() {
  [[ $# -ge 2 ]] || { echo "usage: qemu-vm.sh ssh <user> <identity-file> [command...]" >&2; exit 1; }
  local user="$1" identity="$2"; shift 2
  ssh \
    -o UserKnownHostsFile="$QVM_DIR/known_hosts" \
    -o StrictHostKeyChecking=accept-new \
    -o IdentitiesOnly=yes \
    -o IdentityAgent="$QVM_SSH_IDENTITY_AGENT" \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=4 \
    -i "$identity" \
    -p "$QVM_SSH_PORT" \
    "$user@127.0.0.1" "$@"
}

# === support ===========================================================

cmd_fetch_image() {
  resolve_image_locations
  if [[ -f $cached_image_path ]]; then
    say "Using cached image $cached_image_path"
    return 0
  fi
  mkdir -p "$QVM_CACHE_DIR"
  say "Fetching $image_url"
  # Download to .partial: the cache path only ever holds verified images.
  curl -fL --progress-bar -o "$cached_image_path.partial" "$image_url"

  local image_name expected actual
  image_name="$(basename "$image_url")"
  # pipefail keeps this honest: a checksum-download failure fails the
  # fetch instead of vanishing into the pipeline. SHA256SUMS lines read
  # "<hash> *<filename>" — the * is the format's binary-mode marker,
  # not a glob.
  expected="$(curl -fsSL "$checksums_url" | awk -v f="*$image_name" '$2 == f {print $1}')"
  if [[ -z $expected ]]; then
    echo "$image_name not found in $checksums_url" >&2
    exit 1
  fi
  # macOS ships shasum; Linux ships sha256sum.
  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$cached_image_path.partial" | awk '{print $1}')"
  else
    actual="$(sha256sum "$cached_image_path.partial" | awk '{print $1}')"
  fi
  if [[ $expected != "$actual" ]]; then
    echo "Checksum mismatch for $image_name: expected $expected, got $actual" >&2
    exit 1
  fi
  mv "$cached_image_path.partial" "$cached_image_path"
  say "Fetched and verified $cached_image_path"
}

cmd_status() {
  resolve_image_locations
  if [[ -f $cached_image_path ]]; then
    echo "image     cached   $cached_image_path"
  else
    echo "image     missing  $cached_image_path (run fetch-image)"
  fi
  if vm_is_running; then
    echo "vm        running  pid $(cat "$QVM_DIR/qemu.pid"), ssh 127.0.0.1:$QVM_SSH_PORT"
  elif [[ -d $QVM_DIR ]]; then
    echo "vm        stopped  state in $QVM_DIR"
  else
    echo "vm        absent   (run build-vm)"
  fi
}

cmd_show_boot_log() {
  if [[ ! -f $QVM_DIR/console.log ]]; then
    echo "No boot log yet (run start-vm first)." >&2
    exit 1
  fi
  # The whole log from line 1 (early cloud-init failures live at the
  # top), then follow new output. Ctrl-C to stop; read-only throughout.
  exec tail -n +1 -F "$QVM_DIR/console.log"
}

print_help() {
  # The header comment block (after the shebang, up to the first
  # non-comment line) is the manual; print it verbatim.
  awk 'NR == 1 { next } !/^#/ { exit } { sub(/^# ?/, ""); print }' "$0"
}

# === dispatch ===========================================================
# Grouped as the header presents them: the lifecycle in running order,
# then access, then support.
cmd="${1:-}"
if [[ $# -gt 0 ]]; then shift; fi
case "$cmd" in
  # lifecycle
  build-vm)         cmd_build_vm "$@" ;;
  start-vm)         cmd_start_vm "$@" ;;
  wait-until-ready) cmd_wait_until_ready "$@" ;;
  destroy-vm)       cmd_destroy_vm "$@" ;;
  # access
  ssh)              cmd_ssh "$@" ;;
  # support
  fetch-image)      cmd_fetch_image "$@" ;;
  status)           cmd_status "$@" ;;
  show-boot-log)    cmd_show_boot_log "$@" ;;
  help|-h|--help)   print_help ;;
  '')               print_help >&2; exit 1 ;;
  *)
    echo "qemu-vm: unknown command '$cmd'" >&2
    print_help >&2
    exit 1
    ;;
esac
