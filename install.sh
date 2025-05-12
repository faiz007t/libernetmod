#!/bin/bash

# Libernet Hybrid Installer (with config.json fix)
# Installs from faiz007t/libernetmod, auto-fixes missing dirs/files from lutfailham96/libernet
# Ensures system/config.json exists and LIBERNET_DIR is set for PHP

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
ORIG_REPO="https://github.com/lutfailham96/libernet"
REQUIRED_DIRS=("bin" "web" "system" "log")
REQUIRED_FILES=("update.sh" "requirements.txt" "binaries.txt" "packages.txt" "system/config.json")

fetch_from_repo() {
  local repo="$1"
  local path="$2"
  local target="$3"
  curl -sfL "${repo}/raw/main/${path}" -o "${target}"
}

fetch_dir_from_orig() {
  local dir="$1"
  echo "Fetching missing ${dir} from original repo..."
  local tmp_dir="/tmp/libernet_fetch_${RANDOM}"
  mkdir -p "${tmp_dir}"
  curl -sL "${ORIG_REPO}/archive/main.tar.gz" | tar -xz -C "${tmp_dir}" "libernet-main/${dir}"
  if [ -d "${tmp_dir}/libernet-main/${dir}" ]; then
    mv "${tmp_dir}/libernet-main/${dir}" "${LIBERNET_TMP}/"
  fi
  rm -rf "${tmp_dir}"
}

fetch_file_from_orig() {
  local file="$1"
  local dir
  dir=$(dirname "$file")
  [ "$dir" = "." ] && dir=""
  if [ -n "$dir" ] && [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
  echo "Fetching missing ${file} from original repo..."
  fetch_from_repo "$ORIG_REPO" "$file" "$file"
}

verify_and_fetch() {
  cd "${LIBERNET_TMP}"
  for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "${dir}" ]; then
      fetch_dir_from_orig "${dir}"
    fi
  done
  for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${file}" ]; then
      fetch_file_from_orig "${file}"
    fi
  done
  # If config.json is still missing, create a default one
  if [ ! -f "system/config.json" ]; then
    echo '{}' > system/config.json
  fi
}

install_packages() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! opkg list-installed | grep -q "^${line} "; then
      opkg install "$line"
    fi
  done < requirements.txt
}

install_proprietary_binaries() {
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

install_proprietary_packages() {
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

set_libernet_env() {
  if ! grep -q LIBERNET_DIR /etc/profile; then
    echo -e "\n# Libernet\nexport LIBERNET_DIR=${LIBERNET_DIR}" >> /etc/profile
  fi
  export LIBERNET_DIR="${LIBERNET_DIR}"
}

fix_permissions() {
  # Make sure www-data (or httpd user) can read config.json and system dir
  chown -R root:root "${LIBERNET_DIR}/system"
  chmod 755 "${LIBERNET_DIR}/system"
  chmod 644 "${LIBERNET_DIR}/system/config.json"
}

finish_install() {
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

main_installer() {
  opkg update
  install_packages
  install_proprietary_binaries
  install_proprietary_packages

  echo "Installing Libernet..."
  verify_and_fetch
  mkdir -p "${LIBERNET_DIR}" "${LIBERNET_WWW}"
  
  cp -af update.sh "${LIBERNET_DIR}/"
  cp -af bin system log "${LIBERNET_DIR}/"
  cp -af web/* "${LIBERNET_WWW}/"

  set_libernet_env
  fix_permissions

  # PHP configuration
  uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
  uci add_list uhttpd.main.index_page='index.php'
  uci commit uhttpd
  /etc/init.d/uhttpd restart

  configure_libernet_firewall
  finish_install
}

main() {
  if ! command -v git >/dev/null; then
    opkg update
    opkg install git git-http
  fi

  mkdir -p "${DOWNLOADS_DIR}"
  cd "${DOWNLOADS_DIR}"

  if [ ! -d "libernet" ]; then
    git clone --depth 1 "${MOD_REPO}" libernet || {
      echo "Falling back to original repository"
      git clone --depth 1 "${ORIG_REPO}" libernet
    }
  fi

  cd libernet
  main_installer
}

main
