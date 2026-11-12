#!/usr/bin/env bash
set -euo pipefail

# Build and install the Fedora-only tools used by HyDE.
# Override PREFIX to install somewhere other than /usr/local.

readonly HYPRQUERY_REV="4e1405cc7d07f1b6d611d6d96322f009cd298f23"
readonly AWWW_REV="f66e12a76dbc4c669b2f1375f78bce49f5b19d66"
readonly PREFIX="${PREFIX:-/usr/local}"
readonly BUILD_ROOT="$(mktemp -d)"

cleanup() {
	rm -rf "${BUILD_ROOT}"
}
trap cleanup EXIT

as_root() {
	if [[ "$(id -u)" -eq 0 ]]; then
		"$@"
	else
		sudo "$@"
	fi
}

if ! command -v dnf >/dev/null 2>&1; then
	echo "This installer requires Fedora's dnf package manager." >&2
	exit 1
fi

as_root dnf install -y \
	git cargo cmake make gcc-c++ pkgconf-pkg-config \
	hyprlang-devel cli11-devel json-devel \
	hyprutils-devel lz4-devel libxkbcommon-devel wayland-devel \
	wayland-protocols-devel scdoc

git clone https://github.com/HyDE-Project/hyprquery.git "${BUILD_ROOT}/hyprquery"
git -C "${BUILD_ROOT}/hyprquery" checkout --detach "${HYPRQUERY_REV}"
cmake -S "${BUILD_ROOT}/hyprquery" -B "${BUILD_ROOT}/hyprquery/build" \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
	-DHYPRQUERY_DISTRO_BUILD=ON
cmake --build "${BUILD_ROOT}/hyprquery/build" --parallel
as_root cmake --install "${BUILD_ROOT}/hyprquery/build"

git clone https://codeberg.org/LGFae/awww.git "${BUILD_ROOT}/awww"
git -C "${BUILD_ROOT}/awww" checkout --detach "${AWWW_REV}"
cargo build --manifest-path "${BUILD_ROOT}/awww/Cargo.toml" --release
as_root install -Dm755 "${BUILD_ROOT}/awww/target/release/awww" \
	"${PREFIX}/bin/awww"
as_root install -Dm755 "${BUILD_ROOT}/awww/target/release/awww-daemon" \
	"${PREFIX}/bin/awww-daemon"

printf 'Installed hyq, awww and awww-daemon under %s/bin\n' "${PREFIX}"
