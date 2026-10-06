#!/usr/bin/env sh
# Install the Rust OpenCode CloudLink CLI and pinned tools from one verified release.
#
#   curl -fsSL https://raw.githubusercontent.com/alvarolorentedev/opencode-cloud-link-releases/main/install.sh | sh
#
# Environment:
#   VERSION  pin a version (default: latest)
#   DEST     install directory (default: ~/.local/bin)
#   LITE     1 to omit bundled OpenCode
set -eu

REPO="${REPO:-alvarolorentedev/opencode-cloud-link-releases}"
VERSION="${VERSION:-}"
DEST="${DEST:-$HOME/.local/bin}"
product=opencode-cloudlink

os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in
  linux) ;;
  darwin) echo "Install the universal macOS DMG from https://github.com/$REPO/releases" >&2; exit 1 ;;
  *) echo "unsupported OS: $os" >&2; exit 1 ;;
esac

arch=$(uname -m)
case "$arch" in
  arm64 | aarch64) arch=arm64 ;;
  x86_64 | amd64) arch=amd64 ;;
  *) echo "unsupported architecture: $arch" >&2; exit 1 ;;
esac

if [ -z "$VERSION" ]; then
  VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
    sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1)
fi
[ -n "$VERSION" ] || { echo "could not resolve a release version" >&2; exit 1; }
VERSION="${VERSION#v}"
case "$VERSION" in *[!0-9.]* | .* | *..* | *.) echo "invalid release version" >&2; exit 1 ;; esac

name="opencode-cloudlink_${os}_${arch}"
if [ "${LITE:-0}" = 1 ]; then name="${name}-lite"; fi
url="https://github.com/$REPO/releases/download/v${VERSION}/${name}.tar.gz"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $url"
curl -fsSL "$url" -o "$tmp/pkg.tar.gz"
curl -fsSL "$url.sha256" -o "$tmp/checksum"
expected=$(awk 'NR==1 {print $1}' "$tmp/checksum")
[ "${#expected}" = 64 ] || { echo "invalid archive checksum" >&2; exit 1; }
case "$expected" in *[!0-9a-f]*) echo "invalid archive checksum" >&2; exit 1 ;; esac
if command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$tmp/pkg.tar.gz" | awk '{print $1}'); else actual=$(shasum -a 256 "$tmp/pkg.tar.gz" | awk '{print $1}'); fi
[ "$actual" = "$expected" ] || { echo "archive checksum mismatch" >&2; exit 1; }
tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"
[ -f "$tmp/$name/opencode-cloudlink" ] && [ -f "$tmp/$name/cloudflared" ] || { echo "incomplete release archive" >&2; exit 1; }
if [ "${LITE:-0}" != 1 ]; then
  [ -f "$tmp/$name/opencode" ] || { echo "full archive is missing OpenCode" >&2; exit 1; }
fi

mkdir -p "$DEST"
# Keep all binaries in the same directory: the connector resolves its bundled
# cloudflared and opencode next to itself.
for bin in "$product" cloudflared opencode; do
  if [ -f "$tmp/$name/$bin" ]; then
    cp "$tmp/$name/$bin" "$DEST/"
    chmod +x "$DEST/$bin"
  fi
done
if [ -d "$tmp/$name/licenses" ]; then
  mkdir -p "$DEST/opencode-cloudlink-licenses"
  cp -R "$tmp/$name/licenses/." "$DEST/opencode-cloudlink-licenses/"
fi

echo "Installed $product to $DEST"
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo "Add $DEST to your PATH to run it." ;;
esac
