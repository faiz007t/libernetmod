#!/bin/bash

# Libernet Hybrid Installer
# Combines faiz007t/libernetmod with original libernet
# v1.2.0-stable

set -eo pipefail

# ---- Configuration ----
HOME="/root"
LIBERNET_DIR="${HOME}/libernet"
LIBERNET_WWW="/www/libernet"
DOWNLOADS_DIR="${HOME}/Downloads"
LIBERNET_TMP="${DOWNLOADS_DIR}/libernet"
MOD_REPO="https://github.com/faiz007t/libernetmod"
ORIGINAL_REPO="https://github.com/lutfailham96/libernet"
REQUIRED_DIRS=("bin" "web" "system" "log")

# ---- Core Functions ----
init_environment() {
  # Create required directories
  mkdir -p "${DOWNLOADS_DIR}" "${LIBERNET_DIR}" "${LIBERNET_WWW}"
}

verify_repo_structure() {
  echo "Verifying repository structure..."
  for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "${LIBERNET_TMP}/${dir}" ]; then
      echo "Downloading missing ${dir} from original repo..."
      curl -sL "${ORIGINAL_REPO}/archive/main.tar.gz" | \
        tar -xz -C "${LIBERNET_TMP}" --strip-components=1 "libernet-main/${dir}"
    fi
  done

  # Ensure critical files exist
  for file in "update.sh" "requirements.txt"; do
    if [ ! -f "${LIBERNET_TMP}/${file}" ]; then
      echo "Downloading missing ${file}..."
      curl -sL "${ORIGINAL_REPO}/raw/main/${file}" -o "${LIBERNET_TMP}/${file}"
    fi
  done
}

resolve_package_conflicts() {
  # Handle dnsmasq/dnsmasq-full conflict
  if opkg list-installed | grep -q '^dnsmasq-full'; then
    sed -i '/^dnsmasq$/d' "${LIBERNET_TMP}/requirements.txt"
  else
    sed -i '/^dnsmasq-full$/d' "${LIBERNET_TMP}/requirements.txt"
  fi
}

install_dependencies() {
  echo "Installing dependencies..."
  opkg update
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if ! opkg list-installed | grep -q "^${pkg} "; then
      opkg install "$pkg"
    fi
  done < "${LIBERNET_TMP}/requirements.txt"
}

install_proprietary() {
  # Binaries
  while IFS= read -r binary; do
    [ -z "$binary" ] && continue
    if [ ! -f "/usr/bin/${binary}" ]; then
      echo "Installing ${binary}..."
      curl -sL "https://github.com/lutfailham96/libernet-proprietary/raw/main/$(uname -m)/binaries/${binary}" \
        -o "/usr/bin/${binary}"
      chmod +x "/usr/bin/${binary}"
    fi
  done < "${LIBERNET_TMP}/binaries.txt"

  # Packages
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if ! opkg list-installed | grep -q "^${pkg} "; then
      echo "Installing ${pkg}..."
      tmp_pkg="/tmp/${pkg}.ipk"
      curl -sL "https://github.com/lutfailham96/libernet-proprietary/raw/main/$(uname -m)/packages/${pkg}.ipk" \
        -o "$tmp_pkg"
      opkg install "$tmp_pkg" || true
      rm -f "$tmp_pkg"
    fi
  done < "${LIBERNET_TMP}/packages.txt"
}

configure_system() {
  # PHP configuration
  uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
  uci add_list uhttpd.main.index_page='index.php'
  uci commit uhttpd
  /etc/init.d/uhttpd restart

  # Firewall rules
  if ! uci get network.libernet >/dev/null 2>&1; then
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

finalize_installation() {
  # Create log files
  mkdir -p "${LIBERNET_DIR}/log"
  touch "${LIBERNET_DIR}/log/"{status,service,connected}.log

  # Disable conflicting services
  for service in stubby shadowsocks-libev openvpn stunnel; do
    if [ -f "/etc/init.d/${service}" ]; then
      /etc/init.d/"${service}" stop
      /etc/init.d/"${service}" disable
    fi
  done

  # Display success message
  router_ip=$(ip -4 addr show br-lan | awk '/inet/ {print $2}' | cut -d/ -f1)
  cat <<-EOF

	========================================
	 Libernet Installation Successful!
	 Access: http://${router_ip}/libernet
	 Username: admin
	 Password: libernet
	 Install Date: $(date +'%Y-%m-%d %H:%M:%S')
	========================================
	EOF
}

# ---- Main Execution ----
main() {
  init_environment

  # Clone repository
  if [ ! -d "${LIBERNET_TMP}" ]; then
    echo "Cloning repository..."
    git clone --depth 1 "${MOD_REPO}" "${LIBERNET_TMP}" || {
      echo "Using original repository due to mod repo issues"
      git clone --depth 1 "${ORIGINAL_REPO}" "${LIBERNET_TMP}"
    }
  fi

  # Verify and repair repository structure
  cd "${LIBERNET_TMP}"
  verify_repo_structure
  resolve_package_conflicts

  # Installation steps
  install_dependencies
  install_proprietary
  configure_system

  # Copy files to final location
  echo "Installing Libernet..."
  cp -af update.sh "${LIBERNET_DIR}/"
  cp -af bin system log "${LIBERNET_DIR}/"
  cp -af web/* "${LIBERNET_WWW}/"

  finalize_installation
}

# Start installation
main
