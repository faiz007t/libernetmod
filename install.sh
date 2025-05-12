#!/bin/bash

# Libernet Installer (Hybrid Mod)
# Combines faiz007t/libernetmod with lutfailham96/libernet
# v1.1.0-hybrid

set -eo pipefail

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

HOME="/root"
ARCH="$(grep 'DISTRIB_ARCH' /etc/openwrt_release | awk -F '=' '{print $2}' | sed "s/'//g")"
LIBERNET_DIR="${HOME}/libernet"
LIBERNET_WWW="/www/libernet"
STATUS_LOG="${LIBERNET_DIR}/log/status.log"
DOWNLOADS_DIR="${HOME}/Downloads"
LIBERNET_TMP="${DOWNLOADS_DIR}/libernet"
MOD_REPO="https://github.com/faiz007t/libernetmod"
ORIGINAL_REPO="https://github.com/lutfailham96/libernet"
HYBRID_REPO=("$MOD_REPO" "$ORIGINAL_REPO")

function fetch_from_repo() {
  local path=$1
  local target=$2
  for repo in "${HYBRID_REPO[@]}"; do
    raw_url="${repo/https:\/\/github.com/}/raw.githubusercontent.com"
    raw_url="${raw_url}/main/${path}"
    if curl -sfL "$raw_url" -o "$target"; then
      echo "Fetched $path from ${repo}"
      return 0
    fi
  done
  return 1
}

function fetch_directory() {
  local dir=$1
  for repo in "${HYBRID_REPO[@]}"; do
    tmp_archive="/tmp/libernet-archive.tar.gz"
    if curl -sfL "${repo}/archive/main.tar.gz" -o "$tmp_archive"; then
      tar -xz -C "$LIBERNET_TMP" --strip-components=1 -f "$tmp_archive" "libernet-main/${dir}" && \
      rm "$tmp_archive" && \
      return 0
    fi
  done
  return 1
}

function verify_structure() {
  declare -a required_dirs=("bin" "web" "system" "log")
  for dir in "${required_dirs[@]}"; do
    if [ ! -d "${LIBERNET_TMP}/${dir}" ]; then
      echo "Downloading missing directory: ${dir}"
      fetch_directory "$dir" || {
        echo "Failed to download ${dir} from all sources"
        return 1
      }
    fi
  done
}

function fix_dnsmasq_conflict() {
  if opkg list-installed | grep -q '^dnsmasq-full '; then
    sed -i '/^dnsmasq$/d' requirements.txt
  elif opkg list-installed | grep -q '^dnsmasq '; then
    sed -i '/^dnsmasq-full$/d' requirements.txt
  fi
}

function install_requirements() {
  echo "===== Installing Requirements ====="
  opkg update
  
  # Fetch requirements files from mod or original repo
  fetch_from_repo "requirements.txt" "requirements.txt"
  fetch_from_repo "binaries.txt" "binaries.txt"
  fetch_from_repo "packages.txt" "packages.txt"
  
  fix_dnsmasq_conflict

  # Install packages
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if ! opkg list-installed | grep -q "^${pkg} "; then
      opkg install "$pkg"
    fi
  done < requirements.txt

  # Install proprietary components
  while IFS= read -r binary; do
    [ -z "$binary" ] && continue
    if ! command -v "$binary" &> /dev/null; then
      echo "Installing proprietary binary: $binary"
      install -m 755 <(curl -sfL "https://github.com/lutfailham96/libernet-proprietary/raw/main/${ARCH}/binaries/${binary}") "/usr/bin/${binary}"
    fi
  done < binaries.txt

  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if ! command -v "${pkg}" &> /dev/null; then
      echo "Installing proprietary package: $pkg"
      tmp_pkg="/tmp/${pkg}.ipk"
      curl -sfL "https://github.com/lutfailham96/libernet-proprietary/raw/main/${ARCH}/packages/${pkg}.ipk" -o "$tmp_pkg"
      opkg install "$tmp_pkg" || true
      rm -f "$tmp_pkg"
    fi
  done < packages.txt
}

function setup_libernet() {
  echo "===== Setting Up Libernet ====="
  # Stop if running
  [ -f "${LIBERNET_DIR}/bin/service.sh" ] && "${LIBERNET_DIR}/bin/service.sh" -ds >/dev/null 2>&1 || true

  # Create directory structure
  mkdir -p "${LIBERNET_DIR}" "${LIBERNET_WWW}"

  # Verify and get missing components
  verify_structure

  # Copy files
  cp -af "${LIBERNET_TMP}/update.sh" "${LIBERNET_DIR}/"
  cp -af "${LIBERNET_TMP}/bin" "${LIBERNET_DIR}/"
  cp -af "${LIBERNET_TMP}/system" "${LIBERNET_DIR}/"
  cp -af "${LIBERNET_TMP}/web"/* "${LIBERNET_WWW}/"
  
  # Configure environment
  grep -q "LIBERNET_DIR" /etc/profile || \
    echo -e "\n# Libernet\nexport LIBERNET_DIR='${LIBERNET_DIR}'" >> /etc/profile

  # Configure PHP
  uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
  uci add_list uhttpd.main.index_page='index.php'
  uci commit uhttpd
  /etc/init.d/uhttpd restart

  # Configure firewall
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

function finalize_install() {
  echo "===== Finalizing Installation ====="
  # Create logs
  mkdir -p "${LIBERNET_DIR}/log"
  touch "${LIBERNET_DIR}/log/"{status,service,connected}.log

  # Disable conflicting services
  for service in stubby shadowsocks-libev openvpn stunnel; do
    if [ -f "/etc/init.d/${service}" ]; then
      /etc/init.d/"${service}" stop
      /etc/init.d/"${service}" disable
    fi
  done

  # Display completion
  router_ip=$(ip -4 addr show br-lan | awk '/inet/ {print $2}' | cut -d/ -f1)
  cat <<-EOF

	========================================
	 Libernet Installation Complete!
	 Web Interface: http://${router_ip}/libernet
	 Username: admin
	 Password: libernet
	 Installed at: $(date +'%Y-%m-%d %H:%M:%S')
	========================================
	EOF
}

function main() {
  mkdir -p "${DOWNLOADS_DIR}"
  cd "${DOWNLOADS_DIR}"
  
  if [ ! -d "libernet" ]; then
    git clone --depth 1 "${MOD_REPO}" libernet || {
      echo "Failed to clone mod repo, trying original..."
      git clone --depth 1 "${ORIGINAL_REPO}" libernet
    }
  fi

  cd libernet
  install_requirements
  setup_libernet
  finalize_install
}

main
