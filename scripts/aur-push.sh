#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/aur-push.sh <package_dir> <aur_ssh_url> [commit_message]

Examples:
  scripts/aur-push.sh arch/hyprquery-git ssh://aur@aur.archlinux.org/hyprquery-git.git
  scripts/aur-push.sh arch/hyprquery-git ssh://aur@aur.archlinux.org/hyprquery-git.git "hyprquery-git: update pkgver"

Notes:
- AUR is one git repo per package.
- This script syncs one package folder to one AUR repo.
- Make sure your AUR SSH key is configured.
EOF
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

pkg_dir=$1
aur_url=$2
commit_msg=${3:-"Update package from distro repo"}

if [ ! -d "$pkg_dir" ]; then
  echo "Error: package directory not found: $pkg_dir" >&2
  exit 1
fi

if [ ! -f "$pkg_dir/PKGBUILD" ]; then
  echo "Error: PKGBUILD not found in $pkg_dir" >&2
  exit 1
fi

pushd "$pkg_dir" >/dev/null
makepkg --printsrcinfo > .SRCINFO
popd >/dev/null

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

aur_repo="$tmp_root/aur"
git clone "$aur_url" "$aur_repo" >/dev/null

# Sync package metadata files only (exclude build outputs and local source trees).
rsync -a --delete \
  --exclude 'src/' \
  --exclude 'pkg/' \
  --exclude '*.pkg.tar.*' \
  --exclude '*.tar.gz' \
  --exclude '*.tar.xz' \
  --exclude '*.tar.zst' \
  --exclude 'hyprquery/' \
  "$pkg_dir/" "$aur_repo/"

pushd "$aur_repo" >/dev/null
git add -A

if git diff --cached --quiet; then
  echo "No changes to push to AUR."
  exit 0
fi

git commit -m "$commit_msg" >/dev/null
git push origin HEAD

echo "Pushed to AUR: $aur_url"
popd >/dev/null
