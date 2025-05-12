#!/bin/bash

# Libernet Installer with Full Authentication Removal and Completion Message

set -eo pipefail

# ---- Configuration ----
HOME="/root"
ARCH="$(grep 'DISTRIB_ARCH' /etc/openwrt_release | awk -F '=' '{print $2}' | sed "s/'//g")"
LIBERNET_DIR="${HOME}/libernet"
LIBERNET_WWW="/www/libernet"
DOWNLOADS_DIR="${HOME}/Downloads"
LIBERNET_TMP="${DOWNLOADS_DIR}/libernet"
REPOSITORY_URL="https://github.com/lutfailham96/libernet"
MOD_REPO="https://github.com/faiz007t/libernetmod"
REQUIRED_DIRS=("bin" "web" "system" "log")
REQUIRED_FILES=("update.sh" "requirements.txt" "binaries.txt" "packages.txt" "system/config.json")

handle_package_conflicts() {
    echo "=== Resolving Package Conflicts ==="
    if opkg list-installed | grep -q '^libnl-tiny '; then
        echo "Removing conflicting libnl-tiny..."
        opkg remove libnl-tiny
    fi
    if opkg list-installed | grep -q '^dnsmasq '; then
        sed -i '/^dnsmasq-full/d' "${LIBERNET_TMP}/requirements.txt"
    elif opkg list-installed | grep -q '^dnsmasq-full '; then
        sed -i '/^dnsmasq/d' "${LIBERNET_TMP}/requirements.txt"
    fi
}

fetch_missing_component() {
    local component=$1
    echo "Fetching missing ${component} from official repo..."
    tmp_dir=$(mktemp -d)
    curl -sL "${REPOSITORY_URL}/archive/main.tar.gz" | tar -xz -C "$tmp_dir" "libernet-main/${component}"
    if [ -d "${tmp_dir}/libernet-main/${component}" ]; then
        mv "${tmp_dir}/libernet-main/${component}" "${LIBERNET_TMP}/"
    else
        echo "Creating placeholder directory for ${component}"
        mkdir -p "${LIBERNET_TMP}/${component}"
    fi
    rm -rf "$tmp_dir"
}

verify_structure() {
    echo "=== Verifying Repository Structure ==="
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "${LIBERNET_TMP}/${dir}" ]; then
            fetch_missing_component "$dir"
        fi
    done
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "${LIBERNET_TMP}/${file}" ]; then
            echo "Fetching missing ${file}..."
            curl -sL "${REPOSITORY_URL}/raw/main/${file}" -o "${LIBERNET_TMP}/${file}"
        fi
    done
    if [ ! -f "${LIBERNET_TMP}/system/config.json" ]; then
        echo "Initializing default configuration"
        echo '{"servers":[],"settings":{}}' > "${LIBERNET_TMP}/system/config.json"
    fi
}

install_dependencies() {
    echo "=== Installing Dependencies ==="
    opkg update
    while IFS= read -r pkg; do
        [ -z "$pkg" ] || [[ "$pkg" == "#"* ]] && continue
        if ! opkg list-installed | grep -q "^${pkg} "; then
            echo "Installing ${pkg}..."
            if [ "$pkg" == "ip-full" ]; then
                opkg install --force-overwrite ip-full || true
            else
                opkg install "$pkg"
            fi
        fi
    done < "${LIBERNET_TMP}/requirements.txt"
}

setup_environment() {
    echo "=== Configuring Environment ==="
    if ! grep -q "LIBERNET_DIR" /etc/profile; then
        echo -e "\n# Libernet Environment\nexport LIBERNET_DIR='${LIBERNET_DIR}'" >> /etc/profile
    fi
    export LIBERNET_DIR="${LIBERNET_DIR}"
    uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci add_list uhttpd.main.index_page='index.php'
    uci commit uhttpd
    /etc/init.d/uhttpd restart
    chmod 755 "${LIBERNET_DIR}/system"
    chmod 644 "${LIBERNET_DIR}/system/config.json"
}

install_proprietary() {
    echo "=== Installing Proprietary Components ==="
    while IFS= read -r binary; do
        [ -z "$binary" ] && continue
        if [ ! -f "/usr/bin/${binary}" ]; then
            echo "Installing ${binary}..."
            curl -sL "https://github.com/lutfailham96/libernet-proprietary/raw/main/${ARCH}/binaries/${binary}" \
                -o "/usr/bin/${binary}"
            chmod +x "/usr/bin/${binary}"
        fi
    done < "${LIBERNET_TMP}/binaries.txt"
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        if ! opkg list-installed | grep -q "^${pkg} "; then
            echo "Installing ${pkg}..."
            tmp_pkg="/tmp/${pkg}.ipk"
            curl -sL "https://github.com/lutfailham96/libernet-proprietary/raw/main/${ARCH}/packages/${pkg}.ipk" \
                -o "$tmp_pkg"
            opkg install "$tmp_pkg"
            rm -f "$tmp_pkg"
        fi
    done < "${LIBERNET_TMP}/packages.txt"
}

configure_libernet_firewall() {
    if ! uci get network.libernet >/dev/null 2>&1; then
        echo "Configuring firewall..."
        uci set network.libernet=interface
        uci set network.libernet.proto='none'
        uci set network.libernet.ifname='tun1'
        uci commit network
        uci add firewall zone
        uci set firewall.@zone[-1].network='libernet'
        uci set firewall.@zone[-1].name='libernet'
        uci set firewall.@zone[-1].input='REJECT'
        uci set firewall.@zone[-1].forward='REJECT'
        uci set firewall.@zone[-1].output='ACCEPT'
        uci add firewall forwarding
        uci set firewall.@forwarding[-1].src='lan'
        uci set firewall.@forwarding[-1].dest='libernet'
        uci commit firewall
        /etc/init.d/network reload
    fi
}

remove_auth_checks() {
    echo "=== Removing Authentication System ==="
    rm -f "${LIBERNET_WWW}/login.php" "${LIBERNET_WWW}/auth.php"

    # Remove all auth checks from all PHP files
    find "${LIBERNET_WWW}" -type f -name "*.php" -exec sed -i \
        -e '/include[[:space:]]*(.\{0,1\}auth.php.\{0,1\});/d' \
        -e '/check_session[[:space:]]*(.*);/d' \
        -e '/header[[:space:]]*(.*login.php.*);/d' \
        {} \;

    # Set dashboard as default page if exists
    [ -f "${LIBERNET_WWW}/dashboard.php" ] && \
        ln -sf "dashboard.php" "${LIBERNET_WWW}/index.php"
}

finish_install() {
    if command -v ip >/dev/null 2>&1; then
        router_ip=$(ip -4 addr show br-lan | awk '/inet / {print $2}' | cut -d/ -f1)
    else
        router_ip=$(ifconfig br-lan 2>/dev/null | awk '/inet addr/ {print $2}' | cut -d: -f2)
    fi

    echo "========================================"
    echo " Libernet Installation Complete!"
    echo " Access: http://${router_ip}/libernet"
    echo " Username: admin"
    echo " Password: libernet"
    echo " Installed: $(date +'%Y-%m-%d %H:%M:%S')"
    echo "========================================"
}

main_installation() {
    mkdir -p "${DOWNLOADS_DIR}"
    cd "${DOWNLOADS_DIR}"

    # Clone repository (prefer mod repo, fallback to official)
    if [ ! -d "libernet" ]; then
        if ! git clone --depth 1 "${MOD_REPO}" libernet; then
            echo "Using official repository"
            git clone --depth 1 "${REPOSITORY_URL}" libernet
        fi
    fi

    cd libernet
    LIBERNET_TMP="${PWD}"

    verify_structure
    handle_package_conflicts
    install_dependencies
    install_proprietary

    # Deploy files
    echo "=== Deploying Libernet ==="
    mkdir -p "${LIBERNET_DIR}" "${LIBERNET_WWW}"
    cp -af bin system log "${LIBERNET_DIR}/"
    cp -af web/* "${LIBERNET_WWW}/"
    cp -f update.sh "${LIBERNET_DIR}/"

    setup_environment
    configure_libernet_firewall
    remove_auth_checks
    finish_install
}

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

main_installation
