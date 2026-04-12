#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
	scripts/aur-push.sh <package_dir_or_aur_repo_dir> [commit_message]

Examples:
	scripts/aur-push.sh arch/hyprquery-git
	scripts/aur-push.sh arch/hyprquery-git "hyprquery-git: update pkgver"

Notes:
- If the target is not a git repo, it is treated as package source and
	AUR is cloned to ${TMPDIR:-/tmp}/hyde-aur/<pkgname> on first run.
- Override clone URL with AUR_SSH_URL, and clone root with AUR_CHECKOUT_ROOT.
EOF
}

if [ $# -lt 1 ]; then
	usage
	exit 1
fi

target_dir=$1
commit_msg=${2:-"Update package from distro repo"}

if [ ! -d "$target_dir" ]; then
	echo "Error: package directory not found: $target_dir" >&2
	exit 1
fi

if [ ! -f "$target_dir/PKGBUILD" ]; then
	echo "Error: PKGBUILD not found in $target_dir" >&2
	exit 1
fi

pkgname=$(basename "$target_dir")
src_dir="$target_dir"

if [ -d "$target_dir/.git" ]; then
	aur_repo="$target_dir"
else
	checkout_root=${AUR_CHECKOUT_ROOT:-"${TMPDIR:-/tmp}/hyde-aur"}
	aur_repo="$checkout_root/$pkgname"
	aur_url=${AUR_SSH_URL:-"ssh://aur@aur.archlinux.org/${pkgname}.git"}

	if [ ! -d "$aur_repo/.git" ]; then
		mkdir -p "$checkout_root"
		echo "Bootstrapping AUR checkout: $aur_url -> $aur_repo"
		git clone "$aur_url" "$aur_repo"
	fi
fi

pushd "$aur_repo" >/dev/null

# Keep first push on AUR's expected branch name.
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
	git checkout -b master >/dev/null 2>&1 || true
fi

# Sync primary metadata from source package dir.
install -Dm644 "$OLDPWD/$src_dir/PKGBUILD" "$aur_repo/PKGBUILD"

# Sync optional metadata files; remove stale ones from AUR checkout.
for f in *.install *.patch *.service *.hook *.desktop; do
	if [ -e "$OLDPWD/$src_dir/$f" ]; then
		install -Dm644 "$OLDPWD/$src_dir/$f" "$aur_repo/$f"
	elif [ -e "$aur_repo/$f" ]; then
		rm -f "$aur_repo/$f"
	fi
done

# Regenerate metadata from current PKGBUILD.
makepkg -o --nodeps --skippgpcheck >/dev/null
makepkg --printsrcinfo > .SRCINFO

git add -f PKGBUILD .SRCINFO

# Optional AUR metadata files if present.
for f in *.install *.patch *.service *.hook *.desktop; do
	if [ -e "$f" ]; then
		git add -f "$f"
	fi
done

# Drop local build outputs created while generating .SRCINFO.
rm -rf src pkg

if git diff --cached --quiet; then
	echo "No changes to push to AUR."
	exit 0
fi

git commit -m "$commit_msg" >/dev/null
git push origin HEAD

echo "Pushed to AUR from: $aur_repo"
popd >/dev/null
