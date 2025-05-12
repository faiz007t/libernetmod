#!/bin/bash
# Libernet Installer (BusyBox Compatible)
# v1.3.2-busybox

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
REQUIRED_FILES=("update.sh" "requirements.txt" "binaries.txt" "packages.txt")

# ---- Core Functions ----
init_environment() {
  mkdir -p "${DOWNLOADS_DIR}" "${LIBERNET_DIR}" "${LIBERNET_WWW}"
}

fetch_from_repo() {
  local path=$1
  local target=$2
  for repo in "$MOD_REPO" "$ORIGINAL_REPO"; do
    raw_url="${repo/https:\/\/github.com/}/raw.githubusercontent.com"
    raw_url="${raw_url}/main/${path}"
    if curl -sfL "$raw_url" -o "$target"; then
      echo "Fetched $path from ${repo}"
      return 0
    fi
  done
  return 1
}

handle_directory() {
  local dir=$1
  tmp_extract="/tmp/libernet_extract_${RANDOM}"
  mkdir -p "$tmp_extract"
  
  echo "Downloading missing ${dir}..."
  curl -sL "${ORIGINAL_REPO}/archive/main.tar.gz" | \
    tar -xz -C "$tmp_extract" "libernet-main/${dir}"
  
  mv "${tmp_extract}/libernet-main/${dir}" "${LIBERNET_TMP}/"
  rm -rf "$tmp_extract"
}

verify_structure() {
  echo "Verifying repository structure..."
  
  # Check directories
  for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "${LIBERNET_TMP}/${dir}" ]; then
      handle_directory "$dir"
    fi
  done
  
  # Check critical files
  for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${LIBERNET_TMP}/${file}" ]; then
      echo "Downloading ${file}..."
      fetch_from_repo "$file" "${LIBERNET_TMP}/${file}"
    fi
  done
}

resolve_package_conflicts() {
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

  # Verify and repair structure
  cd "${LIBERNET_TMP}"
  verify_structure
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
