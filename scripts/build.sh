#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET="${1:-}"
SUBTARGET="${2:-}"
PROFILE="${3:-}"
PACKAGES_PROFILE="${4:-}"
VERSION="${5:-}"

if [ -z "$TARGET" ] || [ -z "$SUBTARGET" ] || [ -z "$PROFILE" ] || [ -z "$PACKAGES_PROFILE" ]; then
    echo "Usage: $0 <TARGET> <SUBTARGET> <PROFILE> <PACKAGES_PROFILE> [VERSION]" >&2
    exit 1
fi

log() {
    printf '[%s] %s\n' "$(date +'%T')" "$*"
}

die() {
    printf '[%s] ERROR: %s\n' "$(date +'%T')" "$*" >&2
    exit 1
}

resolve_version() {
    local req="${1:-}"
    local default_major="25.12"
    if [ -z "$req" ] || [ "$req" = "latest" ]; then
        req="$default_major"
    fi

    local versions
    versions=$(curl -fsSL --retry 3 https://downloads.openwrt.org/releases/ 2>/dev/null | \
        grep -oE 'href="[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?/"' | \
        sed 's/href="//;s/\///;s/"//' | sort -V || true)

    if [ -z "$versions" ]; then
        versions=$(git ls-remote --tags --refs https://github.com/openwrt/openwrt.git 2>/dev/null | awk -F'/' '{print $NF}' | sed 's/^v//' || true)
    fi

    if echo "$versions" | grep -qx "$req"; then
        echo "$req"
        return
    fi

    local matched
    local escaped_req="${req//./\\.}"
    matched=$(echo "$versions" | grep -E "^${escaped_req}\.[0-9]+" | grep -v 'rc' | sort -V | tail -n 1 || true)
    if [ -n "$matched" ]; then
        echo "$matched"
        return
    fi

    matched=$(echo "$versions" | grep -E "^${escaped_req}" | grep -v 'rc' | sort -V | tail -n 1 || true)
    if [ -n "$matched" ]; then
        echo "$matched"
        return
    fi

    echo "${req:-25.12.6}"
}

VERSION=$(resolve_version "$VERSION")
log "Using OpenWrt release: ${VERSION}"

case "$TARGET" in
    x86)
        ARCH="x86_64"
        ;;
    rockchip)
        ARCH="aarch64_generic"
        ;;
    *)
        die "Unsupported target: ${TARGET}"
        ;;
esac

WORK_DIR="${ROOT_DIR}/build_${TARGET}_${SUBTARGET}_${PROFILE}"
OUTPUT_DIR="${ROOT_DIR}/artifact"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

IB_NAME="openwrt-imagebuilder-${VERSION}-${TARGET}-${SUBTARGET}.Linux-x86_64"
IB_DIR="${WORK_DIR}/${IB_NAME}"

if [ ! -d "$IB_DIR" ]; then
    IB_ARCHIVE="${WORK_DIR}/${IB_NAME}.tar.zst"
    IB_URL="https://downloads.openwrt.org/releases/${VERSION}/targets/${TARGET}/${SUBTARGET}/${IB_NAME}.tar.zst"
    log "Downloading ImageBuilder: ${IB_URL}"
    curl -fsSL --retry 3 --retry-delay 2 "$IB_URL" -o "$IB_ARCHIVE" || die "Failed to download ImageBuilder archive"
    tar --zstd -xf "$IB_ARCHIVE" -C "$WORK_DIR"
    rm -f "$IB_ARCHIVE"
fi

mkdir -p "${IB_DIR}/keys"
KEY_URL="https://qiusimons.github.io/OpenWrt-Add/keys/custom-feed.rsa.pub"
log "Fetching feed signing key: ${KEY_URL}"
curl -fsSL --retry 3 --retry-delay 2 "$KEY_URL" -o "${IB_DIR}/keys/custom-feed.rsa.pub" || die "Failed to download feed signing key"

FEED_URL="https://qiusimons.github.io/OpenWrt-Add/${ARCH}/packages.adb"
if ! grep -qxF "$FEED_URL" "${IB_DIR}/repositories"; then
    sed -i "1i ${FEED_URL}" "${IB_DIR}/repositories"
fi

OVERLAY_DIR="${WORK_DIR}/overlay"
rm -rf "$OVERLAY_DIR"
mkdir -p "$OVERLAY_DIR"

if [ -d "${ROOT_DIR}/files" ]; then
    cp -af "${ROOT_DIR}/files/." "$OVERLAY_DIR/"
fi

mkdir -p "${OVERLAY_DIR}/usr/bin"
FUCK_URL="https://raw.githubusercontent.com/QiuSimons/OpenWrt-Add/master/core/tools/clean-overlay.sh"
log "Fetching fuck utility: ${FUCK_URL}"
curl -fsSL --retry 3 --retry-delay 2 "$FUCK_URL" -o "${OVERLAY_DIR}/usr/bin/fuck" || die "Failed to download clean-overlay.sh"
chmod +x "${OVERLAY_DIR}/usr/bin/fuck"

mkdir -p "${OVERLAY_DIR}/etc/apk/keys"
cp -af "${IB_DIR}/keys/custom-feed.rsa.pub" "${OVERLAY_DIR}/etc/apk/keys/"

mkdir -p "${OVERLAY_DIR}/etc/apk/repositories.d"
echo "https://qiusimons.github.io/OpenWrt-Add/${ARCH}" > "${OVERLAY_DIR}/etc/apk/repositories.d/custom-feed.list"

if [ "$TARGET" = "rockchip" ]; then
    mkdir -p "${OVERLAY_DIR}/etc/apk"
    echo "aarch64_generic" >> "${OVERLAY_DIR}/etc/apk/arch"
fi

load_packages() {
    local file="$1"
    [ -f "$file" ] || die "Package profile not found: $file"
    grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$' | tr '\n' ' '
}

PACKAGES="$(load_packages "${ROOT_DIR}/profiles/packages.common") $(load_packages "${ROOT_DIR}/profiles/${PACKAGES_PROFILE}")"

log "Assembling firmware for ${PROFILE} (${VERSION})..."
make -C "$IB_DIR" image \
    PROFILE="$PROFILE" \
    PACKAGES="$PACKAGES" \
    FILES="$OVERLAY_DIR" \
    ROOTFS_PARTSIZE="1024"

IB_BIN_DIR="${IB_DIR}/bin/targets/${TARGET}/${SUBTARGET}"
[ -d "$IB_BIN_DIR" ] || die "Output directory not found: $IB_BIN_DIR"

DATE_STR=$(date +%Y-%m-%d)
PLATFORM_LABEL=$(echo "$PROFILE" | sed 's/^friendlyarm_nanopi-/nanopi-/; s/^generic$/x86-64/')

find "$IB_BIN_DIR" -type f \( -name "*sysupgrade.img.gz" -o -name "*combined*.img.gz" -o -name "*.img.gz" \) | while read -r img; do
    fname=$(basename "$img")
    clean_suffix=$(echo "$fname" | sed -E "s/^openwrt-[0-9.]+-${TARGET}-${SUBTARGET}-${PROFILE}-//")
    out_name="YAOF-${PLATFORM_LABEL}-${VERSION}-${DATE_STR}-${clean_suffix}"
    cp -f "$img" "${OUTPUT_DIR}/${out_name}"
    log "Saved: ${out_name}"
done

log "Build completed successfully for ${PROFILE}."
