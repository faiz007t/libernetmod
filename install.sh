#!/bin/bash

# Libernet Installer (BusyBox Compatible)
# v1.1.1-busybox

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
REPOSITORY_URL="https://github.com/lutfailham96/libernet"
MOD_REPO="https://github.com/faiz007t/libernetmod"

function fetch_from_repo() {
  local path=$1
  local target=$2
  # Try mod repo first, then original
  curl -sfL "${MOD_REPO}/raw/main/${path}" -o "$target" || \
  curl -sfL "${REPOSITORY_URL}/raw/main/${path}" -o "$target"
}

function fetch_directory() {
  local dir=$1
  tmp_dir="/tmp/libernet_fetch_${RANDOM}"
  mkdir -p "$tmp_dir"
  
  # Try mod repo first
  curl -sL "${MOD_REPO}/archive/main.tar.gz" | tar -xz -C "$tmp_dir" "libernet-main/${dir}" || \
  curl -sL "${REPOSITORY_URL}/archive/main.tar.gz" | tar -xz -C "$tmp_dir" "libernet-main/${dir}"
  
  mv "${tmp_dir}/libernet-main/${dir}" "${LIBERNET_TMP}/"
  rm -rf "$tmp_dir"
}

function install_packages() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! opkg list-installed | grep -q "^${line} "; then
      opkg install "$line"
    fi
  done < requirements.txt
}

function install_proprietary_binaries() {
  echo "Installing proprietary binaries"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! command -v "$line" >/dev/null 2>&1; then
      echo "Installing $line..."
      curl -sLko "/usr/bin/$line" "https://github.com/lutfailham96/libernet-proprietary/raw/main/${ARCH}/binaries/$line"
      chmod +x "/usr/bin/$line"
    fi
  done < binaries.txt
}

function install_proprietary_packages() {
  echo "Installing proprietary packages"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! opkg list-installed | grep -q "^${line} "; then
      echo "Installing $line..."
      tmp_pkg="/tmp/${line}.ipk"
      curl -sLko "$tmp_pkg" "https://github.com/lutfailham96/libernet-proprietary/raw/main/${ARCH}/packages/${line}.ipk"
      opkg install "$tmp_pkg"
      rm -f "$tmp_pkg"
    fi
  done < packages.txt
}

function verify_files() {
  # Check for required files
  for file in requirements.txt binaries.txt packages.txt update.sh; do
    if [ ! -f "$file" ]; then
      echo "Fetching missing $file"
      fetch_from_repo "$file" "$file"
    fi
  done

  # Check for required directories
  for dir in bin web system log; do
    if [ ! -d "$dir" ]; then
      echo "Fetching missing $dir directory"
      fetch_directory "$dir"
    fi
  done
}

function configure_libernet_firewall() {
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

function finish_install() {
  # Get IP using modern 'ip' or fallback to 'ifconfig'
  if command -v ip >/dev/null; then
    router_ip=$(ip -4 addr show br-lan | awk '/inet/ {print $2}' | cut -d/ -f1)
  else
    router_ip=$(ifconfig br-lan | awk '/inet addr/ {print $2}' | cut -d: -f2)
  fi

  cat <<-EOF

	========================================
	 Libernet Installation Complete!
	 Access: http://${router_ip}/libernet
	 Username: admin
	 Password: libernet
	 Installed: $(date +'%Y-%m-%d %H:%M:%S')
	========================================
	EOF
}

function main_installer() {
  # Check for dnsmasq conflicts
  if opkg list-installed | grep -q '^dnsmasq '; then
    sed -i '/^dnsmasq-full/d' requirements.txt
  elif opkg list-installed | grep -q '^dnsmasq-full '; then
    sed -i '/^dnsmasq/d' requirements.txt
  fi

  opkg update
  install_packages
  install_proprietary_binaries
  install_proprietary_packages

  echo "Installing Libernet..."
  verify_files
  mkdir -p "${LIBERNET_DIR}" "${LIBERNET_WWW}"
  
  cp -af update.sh "${LIBERNET_DIR}/"
  cp -af bin system log "${LIBERNET_DIR}/"
  cp -af web/* "${LIBERNET_WWW}/"

  # PHP configuration
  uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
  uci add_list uhttpd.main.index_page='index.php'
  uci commit uhttpd
  /etc/init.d/uhttpd restart

  configure_libernet_firewall
  finish_install
}

function main() {
  # Install git if missing
  if ! command -v git >/dev/null; then
    opkg update
    opkg install git git-http
  fi

  mkdir -p "${DOWNLOADS_DIR}"
  cd "${DOWNLOADS_DIR}"

  if [ ! -d "libernet" ]; then
    git clone --depth 1 "${REPOSITORY_URL}" libernet || {
      echo "Falling back to mod repository"
      git clone --depth 1 "${MOD_REPO}" libernet
    }
  fi

  cd libernet
  main_installer
}

main
