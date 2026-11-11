#!/usr/bin/env bash
set -Eeuo pipefail

# LiroOS first milestone: customize an official Linux Mint XFCE live ISO.
# The input ISO is read-only; all work happens in .work/ and output in build/.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ISO_INPUT="${1:-}"
WORK_DIR="${ROOT_DIR}/.work"
ISO_TREE="${WORK_DIR}/iso"
ROOTFS="${WORK_DIR}/rootfs"
OUTPUT_DIR="${ROOT_DIR}/build"
MOUNTS=()

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
cleanup() {
  for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do
    mountpoint -q "${MOUNTS[i]}" && umount -lf "${MOUNTS[i]}" || true
  done
}
trap cleanup EXIT

[[ $EUID -eq 0 ]] || fail "Run as root: sudo bash ./build-iso.sh /path/to/linuxmint-xfce.iso"
[[ -n "$ISO_INPUT" && -f "$ISO_INPUT" ]] || fail "Usage: sudo bash ./build-iso.sh /path/to/linuxmint-xfce.iso"
ISO_INPUT="$(realpath "$ISO_INPUT")"

for tool in xorriso unsquashfs mksquashfs rsync sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || fail "Missing required tool: $tool"
done

rm -rf "$WORK_DIR"
# unsquashfs creates ROOTFS itself; its destination must not exist yet.
mkdir -p "$ISO_TREE" "$OUTPUT_DIR"

echo "[1/6] Extracting source ISO..."
xorriso -osirrox on -indev "$ISO_INPUT" -extract / "$ISO_TREE" >/dev/null 2>&1
SQUASHFS="$ISO_TREE/casper/filesystem.squashfs"
[[ -f "$SQUASHFS" ]] || fail "Not a supported Mint live ISO: casper/filesystem.squashfs was not found."

echo "[2/6] Unpacking live filesystem..."
unsquashfs -no-progress -d "$ROOTFS" "$SQUASHFS"

echo "[3/6] Applying LiroOS files..."
rsync -a "$ROOT_DIR/overlay/" "$ROOTFS/"

echo "[4/6] Installing desktop components into live filesystem..."
# Save the host DNS configuration before bind-mounting /run. On some runners
# /etc/resolv.conf points into /run, which would make cp see identical source
# and destination paths inside the chroot.
cp -L /etc/resolv.conf "$WORK_DIR/resolv.conf"
for d in dev proc sys run; do mkdir -p "$ROOTFS/$d"; done
mount --bind /dev "$ROOTFS/dev"; MOUNTS+=("$ROOTFS/dev")
mount --bind /dev/pts "$ROOTFS/dev/pts"; MOUNTS+=("$ROOTFS/dev/pts")
mount -t proc proc "$ROOTFS/proc"; MOUNTS+=("$ROOTFS/proc")
mount -t sysfs sysfs "$ROOTFS/sys"; MOUNTS+=("$ROOTFS/sys")
mount --bind /run "$ROOTFS/run"; MOUNTS+=("$ROOTFS/run")

# Replace any dangling/live-image resolv.conf symlink with a regular file.
rm -f "$ROOTFS/etc/resolv.conf"
install -m 0644 "$WORK_DIR/resolv.conf" "$ROOTFS/etc/resolv.conf"
chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  plank papirus-icon-theme arc-theme xfce4-whiskermenu-plugin
chroot "$ROOTFS" apt-get clean
rm -rf "$ROOTFS/var/lib/apt/lists/"*

cleanup
MOUNTS=()

echo "[5/6] Rebuilding compressed live filesystem..."
du -sx --block-size=1 "$ROOTFS" | cut -f1 > "$ISO_TREE/casper/filesystem.size"
rm -f "$SQUASHFS"
mksquashfs "$ROOTFS" "$SQUASHFS" -comp xz -b 1M -noappend -no-progress

# Update ISO checksums after replacing filesystem.squashfs.
(
  cd "$ISO_TREE"
  find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum > md5sum.txt
)

echo "[6/6] Rebuilding bootable ISO, preserving source boot records..."
BUILD_DATE="$(date -u +%Y%m%d)"
ISO_NAME="LiroOS-${BUILD_DATE}-x86_64.iso"
xorriso -indev "$ISO_INPUT" -outdev "$OUTPUT_DIR/$ISO_NAME" \
  -update_r "$ISO_TREE" / \
  -boot_image any replay \
  -commit

(
  cd "$OUTPUT_DIR"
  sha256sum "$ISO_NAME" > SHA256SUMS
)

echo "LiroOS ISO created: $OUTPUT_DIR/$ISO_NAME"
echo "Checksum file: $OUTPUT_DIR/SHA256SUMS"
