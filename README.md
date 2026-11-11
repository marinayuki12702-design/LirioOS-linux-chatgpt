# LiroOS

**LiroOS** is a lightweight, visually distinctive Linux desktop remix based on **Linux Mint XFCE**.

## Visual identity

- Lavender: `#DCCBFA`
- White: `#FFFFFF`
- Vivid purple: `#A832E8`
- Dark charcoal panels and windows
- Lirio-inspired artwork, a slim top panel and a floating Plank dock

## What this repository builds

The first milestone customizes an official Linux Mint XFCE live ISO. It keeps the Mint/Ubuntu base, Linux kernel, installer and APT package system, while adding LiroOS branding and desktop defaults.

This is **not** a new kernel or an independent operating system kernel. Windows application compatibility is not included.

## Build an ISO with GitHub Actions

1. Open **Actions → Build LiroOS ISO → Run workflow**.
2. Paste the official Linux Mint XFCE ISO download URL.
3. Paste the SHA256 checksum published by Linux Mint for that exact ISO.
4. Run the workflow.
5. Download the `LiroOS-ISO` artifact when the job succeeds.

The workflow verifies the source ISO checksum before modifying it.

## Local build

On a Debian/Ubuntu host with root access:

```bash
sudo apt-get update
sudo apt-get install -y xorriso squashfs-tools rsync curl
sudo bash ./build-iso.sh /path/to/linuxmint-xfce.iso
```

The resulting ISO is written to `build/`.

## Current milestone

- LiroOS wallpaper and palette
- GTK theme accent layer
- Papirus icons and Arc-Dark GTK theme
- Plank dock autostart
- XFCE session defaults for the live user and new accounts
- Reproducible GitHub Actions build entry point

## Important

The ISO must be tested in a virtual machine before installation on physical hardware. A successful workflow is not, by itself, proof that every machine boots correctly. Do not overwrite or repartition an existing operating system during testing.
