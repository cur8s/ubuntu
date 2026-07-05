#!/usr/bin/env sh
# qemu-vm.sh — a disposable Ubuntu VM on QEMU, in one vendorable file.
#
# The contract: give it a cloud-init user-data file, get an Ubuntu cloud
# VM on localhost:$QVM_SSH_PORT in a couple of minutes; destroy leaves
# nothing behind but the cached image. The guest architecture follows the
# host (hvf on macOS, KVM on Linux); arm64 boots via EDK2 UEFI pflash,
# amd64 on QEMU's default SeaBIOS. Networking is QEMU user-mode with one
# forwarded SSH port — no root, no bridges, no daemons.
#
# Upstream: https://github.com/cur8s/qemu        Version: 0.1.0
# This file is designed to be vendored: copy it into any repository that
# needs a quick VM and keep this header. Refresh a vendored copy with:
#   gh api -H "Accept: application/vnd.github.raw" \
#     "repos/cur8s/qemu/contents/qemu-vm.sh?ref=vX.Y.Z" > qemu-vm.sh
# Patches go upstream, never into vendored copies.
#
# Requirements:
#   macOS:  brew install qemu           (hdiutil builds the seed ISO)
#   Linux:  qemu-system-x86 or qemu-system-arm, qemu-utils, genisoimage,
#           and access to /dev/kvm
#
# Usage: qemu-vm.sh <command> [args]
#   fetch                       cache + checksum-verify the cloud image
#   create                      overlay disk + NoCloud seed (needs QVM_USER_DATA)
#   boot                        start daemonized; serial log in $QVM_DIR/console.log
#   wait <user> <identity>      block until cloud-init is done (rides out a
#                               first-boot reboot; detects the error state)
#   ssh <user> <identity> [cmd] SSH into the VM (known_hosts lives in $QVM_DIR)
#   status                      image / state-dir / process facts
#   console                     follow the serial log
#   image-path                  print the resolved cached image path
#   destroy                     SIGTERM the VM and delete its state dir
#
# Configuration (environment; every value has a default):
#   QVM_DIR            VM state dir                 (default: ./.qvm/vm)
#   QVM_CACHE_DIR      image cache dir              (default: ./.qvm/cache)
#   QVM_NAME           instance-id + hostname       (default: qemu-vm)
#   QVM_USER_DATA      cloud-init user-data file    (required by create)
#   QVM_IMAGE_URL      cloud image                  (default: Ubuntu 24.04
#                      noble, current, host architecture)
#   QVM_SHA256SUMS_URL checksum file                (default: SHA256SUMS
#                      beside the image URL)
#   QVM_SSH_PORT       forwarded SSH port           (default: 2222)
#   QVM_CPUS / QVM_MEMORY / QVM_DISK_SIZE           (default: 4 / 4G / 20G)
#   QVM_WAIT_TIMEOUT_SECONDS                        (default: 1200)
set -eu

QVM_DIR="${QVM_DIR:-./.qvm/vm}"
QVM_CACHE_DIR="${QVM_CACHE_DIR:-./.qvm/cache}"
# QEMU -daemonize chdirs to /: every path handed to it must be absolute.
case "$QVM_DIR" in /*) ;; *) QVM_DIR="$PWD/${QVM_DIR#./}" ;; esac
case "$QVM_CACHE_DIR" in /*) ;; *) QVM_CACHE_DIR="$PWD/${QVM_CACHE_DIR#./}" ;; esac
QVM_NAME="${QVM_NAME:-qemu-vm}"
QVM_SSH_PORT="${QVM_SSH_PORT:-2222}"
QVM_CPUS="${QVM_CPUS:-4}"
QVM_MEMORY="${QVM_MEMORY:-4G}"
QVM_DISK_SIZE="${QVM_DISK_SIZE:-20G}"

# --- platform selection -------------------------------------------------
case "$(uname -m)" in
  arm64|aarch64) QVM_GUEST_ARCH="arm64" ;;
  x86_64)        QVM_GUEST_ARCH="amd64" ;;
  *) echo "qemu-vm: unsupported host architecture: $(uname -m)" >&2; exit 1 ;;
esac
if [ "$QVM_GUEST_ARCH" = "arm64" ]; then
  QVM_SYSTEM_BIN="qemu-system-aarch64"
  QVM_MACHINE="virt"
  if [ "$(uname -s)" = "Darwin" ]; then
    QVM_EFI_CODE="$(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd"
    QVM_EFI_VARS_TEMPLATE="$(brew --prefix qemu)/share/qemu/edk2-arm-vars.fd"
  else
    QVM_EFI_CODE="/usr/share/AAVMF/AAVMF_CODE.fd"
    QVM_EFI_VARS_TEMPLATE="/usr/share/AAVMF/AAVMF_VARS.fd"
  fi
else
  QVM_SYSTEM_BIN="qemu-system-x86_64"
  QVM_MACHINE="q35"
  QVM_EFI_CODE=""
  QVM_EFI_VARS_TEMPLATE=""
fi
case "$(uname -s)" in
  Darwin) QVM_ACCEL="hvf" ;;
  *)      QVM_ACCEL="kvm" ;;
esac
QVM_IMAGE_URL="${QVM_IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-$QVM_GUEST_ARCH.img}"
QVM_SHA256SUMS_URL="${QVM_SHA256SUMS_URL:-$(dirname "$QVM_IMAGE_URL")/SHA256SUMS}"

image_path() { echo "$QVM_CACHE_DIR/$(basename "$QVM_IMAGE_URL")"; }

vm_running() {
  [ -f "$QVM_DIR/qemu.pid" ] && kill -0 "$(cat "$QVM_DIR/qemu.pid")" 2>/dev/null
}

# --- commands -----------------------------------------------------------
cmd_fetch() {
  image="$(image_path)"
  if [ -f "$image" ]; then
    echo "Using cached image $image"
    return 0
  fi
  mkdir -p "$QVM_CACHE_DIR"
  echo "Fetching $QVM_IMAGE_URL"
  curl -fL --progress-bar -o "$image.partial" "$QVM_IMAGE_URL"
  image_name="$(basename "$QVM_IMAGE_URL")"
  expected="$(curl -fsSL "$QVM_SHA256SUMS_URL" | awk -v f="*$image_name" '$2 == f {print $1}')"
  if [ -z "$expected" ]; then
    echo "$image_name not found in $QVM_SHA256SUMS_URL" >&2
    exit 1
  fi
  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$image.partial" | awk '{print $1}')"
  else
    actual="$(sha256sum "$image.partial" | awk '{print $1}')"
  fi
  if [ "$expected" != "$actual" ]; then
    echo "Checksum mismatch for $image_name: expected $expected, got $actual" >&2
    exit 1
  fi
  mv "$image.partial" "$image"
  echo "Fetched and verified $image"
}

cmd_create() {
  if [ -e "$QVM_DIR" ]; then
    echo "A VM already exists at $QVM_DIR (destroy it first)." >&2
    exit 1
  fi
  if [ -z "${QVM_USER_DATA:-}" ] || [ ! -f "$QVM_USER_DATA" ]; then
    echo "Set QVM_USER_DATA to a cloud-init user-data file." >&2
    exit 1
  fi
  cmd_fetch
  mkdir -p "$QVM_DIR"

  # Copy-on-write overlay: the cached base image stays pristine;
  # cloud-init's growpart expands the filesystem on first boot.
  qemu-img create -q -f qcow2 -b "$QVM_CACHE_DIR/$(basename "$QVM_IMAGE_URL")" -F qcow2 \
    "$QVM_DIR/disk.qcow2" "$QVM_DISK_SIZE"

  # NoCloud seed: an ISO labeled "cidata" with the user-data verbatim
  # plus a minimal meta-data.
  seed_dir="$QVM_DIR/seed"
  mkdir -p "$seed_dir"
  cp "$QVM_USER_DATA" "$seed_dir/user-data"
  printf 'instance-id: %s\nlocal-hostname: %s\n' "$QVM_NAME" "$QVM_NAME" \
    > "$seed_dir/meta-data"
  if command -v hdiutil >/dev/null 2>&1; then
    hdiutil makehybrid -quiet -iso -joliet -default-volume-name cidata \
      -o "$QVM_DIR/seed.iso" "$seed_dir"
  else
    genisoimage -quiet -output "$QVM_DIR/seed.iso" -volid cidata -joliet -rock "$seed_dir"
  fi

  # Writable UEFI variable store (arm64 only; amd64 boots via SeaBIOS).
  if [ "$QVM_GUEST_ARCH" = "arm64" ]; then
    cp "$QVM_EFI_VARS_TEMPLATE" "$QVM_DIR/efivars.fd"
  fi
  echo "VM prepared in $QVM_DIR (boot it with: qemu-vm.sh boot)"
}

cmd_boot() {
  if [ ! -d "$QVM_DIR" ]; then
    echo "No VM found at $QVM_DIR (run create first)." >&2
    exit 1
  fi
  if vm_running; then
    echo "The VM is already running (pid $(cat "$QVM_DIR/qemu.pid"))." >&2
    exit 1
  fi
  set --
  if [ "$QVM_GUEST_ARCH" = "arm64" ]; then
    set -- \
      -drive if=pflash,format=raw,readonly=on,file="$QVM_EFI_CODE" \
      -drive if=pflash,format=raw,file="$QVM_DIR/efivars.fd"
  fi
  "$QVM_SYSTEM_BIN" \
    -machine "$QVM_MACHINE" \
    -accel "$QVM_ACCEL" \
    -cpu host \
    -smp "$QVM_CPUS" \
    -m "$QVM_MEMORY" \
    "$@" \
    -drive if=virtio,format=qcow2,file="$QVM_DIR/disk.qcow2" \
    -drive if=virtio,format=raw,readonly=on,file="$QVM_DIR/seed.iso" \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${QVM_SSH_PORT}-:22" \
    -device virtio-net-pci,netdev=net0 \
    -display none \
    -daemonize \
    -pidfile "$QVM_DIR/qemu.pid" \
    -serial "file:$QVM_DIR/console.log"
  echo "VM booting: SSH forwarded to 127.0.0.1:$QVM_SSH_PORT (serial: qemu-vm.sh console)"
}

cmd_ssh() {
  [ $# -ge 2 ] || { echo "usage: qemu-vm.sh ssh <user> <identity-file> [command...]" >&2; exit 1; }
  _user="$1"; _identity="$2"; shift 2
  ssh \
    -o UserKnownHostsFile="$QVM_DIR/known_hosts" \
    -o StrictHostKeyChecking=accept-new \
    -o IdentitiesOnly=yes \
    -o IdentityAgent=none \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=4 \
    -i "$_identity" \
    -p "$QVM_SSH_PORT" \
    "$_user@127.0.0.1" "$@"
}

cmd_wait() {
  [ $# -eq 2 ] || { echo "usage: qemu-vm.sh wait <user> <identity-file>" >&2; exit 1; }
  _wait_deadline=$(( $(date +%s) + ${QVM_WAIT_TIMEOUT_SECONDS:-1200} ))
  _until_done() {
    until cmd_ssh "$1" "$2" cloud-init status --wait >/dev/null 2>&1; do
      # A reachable VM whose cloud-init landed in the error state will
      # never turn done: fail now instead of spinning out the deadline.
      if cmd_ssh "$1" "$2" cloud-init status 2>/dev/null | grep -q 'status: error'; then
        echo "cloud-init finished in the error state; inspect the console log." >&2
        exit 1
      fi
      if [ "$(date +%s)" -ge "$_wait_deadline" ]; then
        echo "Timed out waiting for cloud-init to finish." >&2
        exit 1
      fi
      sleep 10
    done
  }
  echo "Waiting for cloud-init to finish (a first boot may upgrade and reboot)..."
  _until_done "$1" "$2"
  # A first-boot power_state reboot fires the moment cloud-init reports
  # done, so a success here may be the pre-reboot instance. Let the
  # reboot land, then require done again on the far side; on a settled
  # VM the second pass returns immediately.
  sleep 15
  _until_done "$1" "$2"
  echo "cloud-init is done; the VM is ready."
}

cmd_status() {
  if [ -f "$(image_path)" ]; then echo "image     cached   $(image_path)"; else echo "image     missing  (run fetch)"; fi
  if vm_running; then
    echo "vm        running  pid $(cat "$QVM_DIR/qemu.pid"), ssh 127.0.0.1:$QVM_SSH_PORT"
  elif [ -d "$QVM_DIR" ]; then
    echo "vm        stopped  state in $QVM_DIR"
  else
    echo "vm        absent   (run create)"
  fi
}

cmd_console() {
  if [ ! -f "$QVM_DIR/console.log" ]; then
    echo "No console log yet (boot the VM first)." >&2
    exit 1
  fi
  exec tail -n 100 -F "$QVM_DIR/console.log"
}

cmd_destroy() {
  if [ ! -e "$QVM_DIR" ]; then
    echo "No VM to destroy."
    return 0
  fi
  if vm_running; then
    pid="$(cat "$QVM_DIR/qemu.pid")"
    kill "$pid"
    # Do not remove the disk under a live process.
    waited=0
    while kill -0 "$pid" 2>/dev/null; do
      if [ "$waited" -ge 30 ]; then
        echo "QEMU (pid $pid) did not exit after SIGTERM; refusing to delete its state." >&2
        exit 1
      fi
      sleep 1
      waited=$((waited + 1))
    done
  fi
  rm -rf "$QVM_DIR"
  echo "VM destroyed (cached image kept in $QVM_CACHE_DIR)."
}

# --- dispatch -----------------------------------------------------------
cmd="${1:-}"
[ $# -ge 1 ] && shift
case "$cmd" in
  fetch)      cmd_fetch "$@" ;;
  create)     cmd_create "$@" ;;
  boot)       cmd_boot "$@" ;;
  wait)       cmd_wait "$@" ;;
  ssh)        cmd_ssh "$@" ;;
  status)     cmd_status "$@" ;;
  console)    cmd_console "$@" ;;
  image-path) image_path ;;
  destroy)    cmd_destroy "$@" ;;
  *)
    sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
