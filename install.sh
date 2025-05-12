#!/bin/bash

# Libernet Installer (MOD)
# by Lutfa Ilham, modified for faiz007t/libernetmod
# v1.0.0-mod

set -e

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
REPOSITORY_URL="https://github.com/faiz007t/libernetmod"
RAW_REPO_URL="https://raw.githubusercontent.com/faiz007t/libernetmod/main"

# Handle dnsmasq/dnsmasq-full conflict
function fix_dnsmasq_conflict() {
  if opkg list-installed | grep -q '^dnsmasq-full '; then
    if grep -q '^dnsmasq$' requirements.txt 2>/dev/null; then
      echo "Detected dnsmasq-full installed. Removing 'dnsmasq' from requirements.txt to avoid conflict."
      sed -i '/^dnsmasq$/d' requirements.txt
    fi
  fi
  if opkg list-installed | grep -q '^dnsmasq '; then
    if grep -q '^dnsmasq-full$' requirements.txt 2>/dev/null; then
      echo "Detected dnsmasq installed. Removing 'dnsmasq-full' from requirements.txt to avoid conflict."
      sed -i '/^dnsmasq-full$/d' requirements.txt
    fi
  fi
}

function fetch_requirements_files() {
  echo "Fetching requirements.txt, binaries.txt, and packages.txt from ${REPOSITORY_URL}"
  curl -sfL "${RAW_REPO_URL}/requirements.txt" -o requirements.txt || curl -sfL "${RAW_REPO_URL}/requirements.txt" -o requirements.txt
  curl -sfL "${RAW_REPO_URL}/binaries.txt" -o binaries.txt || curl -sfL "${RAW_REPO_URL}/binaries.txt" -o binaries.txt
  curl -sfL "${RAW_REPO_URL}/packages.txt" -o packages.txt || curl -sfL "${RAW_REPO_URL}/packages.txt" -o packages.txt
  fix_dnsmasq_conflict
}

function install_packages() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ $(opkg list-installed "${line}" | grep -c "${line}") != "1" ]]; then
      opkg install "${line}"
    fi
  done < requirements.txt
}

function install_proprietary_binaries() {
  echo -e "Installing proprietary binaries"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! which ${line} > /dev/null 2>&1; then
      bin="/usr/bin/${line}"
      echo "Installing ${line} ..."
      curl -sLko "${bin}" "https://github.com/lutfailham96/libernet-proprietary/raw/main/${ARCH}/binaries/${line}"
      chmod +x "${bin}"
    fi
  done < binaries.txt
}

function install_proprietary_packages() {
  echo -e "Installing proprietary packages"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! which ${line} > /dev/null 2>&1; then
      pkg="/tmp/${line}.ipk"
      echo "Installing ${line} ..."
      curl -sLko "${pkg}" "https://github.com/lutfailham96/libernet-proprietary/raw/main/${ARCH}/packages/${line}.ipk"
      opkg install "${pkg}" || true
      rm -rf "${pkg}"
    fi
  done < packages.txt
}

function install_proprietary() {
  install_proprietary_binaries
  install_proprietary_packages
}

function install_prerequisites() {
  opkg update
}

function install_requirements() {
  echo -e "Fetching and installing packages" \
    && fetch_requirements_files \
    && install_prerequisites \
    && install_packages \
    && install_proprietary
}

function enable_uhttp_php() {
  if ! grep -q ".php=/usr/bin/php-cgi" /etc/config/uhttpd; then
    echo -e "Enabling uhttp php execution" \
      && uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi' \
      && uci add_list uhttpd.main.index_page='index.php' \
      && uci commit uhttpd \
      && echo -e "Restarting uhttp service" \
      && /etc/init.d/uhttpd restart
  else
    echo -e "uhttp php already enabled, skipping ..."
  fi
}

function add_libernet_environment() {
  if ! grep -q LIBERNET_DIR /etc/profile; then
    echo -e "Adding Libernet environment" \
      && echo -e "\n# Libernet\nexport LIBERNET_DIR=${LIBERNET_DIR}" | tee -a '/etc/profile'
  fi
}

function install_libernet() {
  # stop Libernet before install
  if [[ -f "${LIBERNET_DIR}/bin/service.sh" && $(cat "${STATUS_LOG}" 2>/dev/null) != "0" ]]; then
    echo -e "Stopping Libernet"
    "${LIBERNET_DIR}/bin/service.sh" -ds > /dev/null 2>&1
  fi
  rm -rf "${LIBERNET_WWW}"

  # Download update.sh if missing
  if [ ! -f update.sh ]; then
    echo "update.sh not found, downloading from mod repo..."
    curl -sfL "${RAW_REPO_URL}/update.sh" -o update.sh || curl -sfL "${RAW_REPO_URL}/update.sh" -o update.sh
  fi

  echo -e "Installing Libernet" \
    && mkdir -p "${LIBERNET_DIR}" \
    && echo -e "Copying updater script" \
    && cp -avf update.sh "${LIBERNET_DIR}/" \
    && echo -e "Copying binary" \
    && cp -arvf bin "${LIBERNET_DIR}/" \
    && echo -e "Copying system" \
    && cp -arvf system "${LIBERNET_DIR}/" \
    && echo -e "Copying log" \
    && cp -arvf log "${LIBERNET_DIR}/" \
    && echo -e "Copying web files" \
    && mkdir -p "${LIBERNET_WWW}" \
    && cp -arvf web/* "${LIBERNET_WWW}/" \
    && echo -e "Configuring Libernet" \
    && sed -i "s|LIBERNET_DIR|$(echo ${LIBERNET_DIR} | sed 's/\//\\\//g')|g" "${LIBERNET_WWW}/config.inc.php"
}

function configure_libernet_firewall() {
  if ! uci get network.libernet > /dev/null 2>&1; then
    echo "Configuring Libernet firewall" \
      && uci set network.libernet=interface \
      && uci set network.libernet.proto='none' \
      && uci set network.libernet.ifname='tun1' \
      && uci commit \
      && uci add firewall zone \
      && uci set firewall.@zone[-1].network='libernet' \
      && uci set firewall.@zone[-1].name='libernet' \
      && uci set firewall.@zone[-1].masq='1' \
      && uci set firewall.@zone[-1].mtu_fix='1' \
      && uci set firewall.@zone[-1].input='REJECT' \
      && uci set firewall.@zone[-1].forward='REJECT' \
      && uci set firewall.@zone[-1].output='ACCEPT' \
      && uci commit \
      && uci add firewall forwarding \
      && uci set firewall.@forwarding[-1].src='lan' \
      && uci set firewall.@forwarding[-1].dest='libernet' \
      && uci commit \
      && /etc/init.d/network restart
  fi
}

function configure_libernet_service() {
  echo -e "Configuring Libernet service"
  /etc/init.d/stubby disable 2>/dev/null || true
  /etc/init.d/shadowsocks-libev disable 2>/dev/null || true
  /etc/init.d/openvpn disable 2>/dev/null || true
  /etc/init.d/stunnel disable 2>/dev/null || true
}

function setup_system_logs() {
  echo -e "Setup system logs"
  logs=("status.log" "service.log" "connected.log")
  for log in "${logs[@]}"; do
    if [[ ! -f "${LIBERNET_DIR}/log/${log}" ]]; then
      touch "${LIBERNET_DIR}/log/${log}"
    fi
  done
}

function finish_install() {
  # Try to get router IP using ip, fallback to ifconfig
  if command -v ip >/dev/null 2>&1; then
    router_ip="$(ip -4 addr show br-lan | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)"
  else
    router_ip="$(ifconfig br-lan 2>/dev/null | grep 'inet addr:' | awk '{print $2}' | awk -F ':' '{print $2}')"
  fi
  echo "========================================"
  echo " Libernet Installation Complete!"
  echo " Libernet URL: http://${router_ip}/libernet"
  echo " Credentials: admin / libernet"
  echo " Install Date: $(date +'%Y-%m-%d %H:%M:%S')"
  echo "========================================"
}

function main_installer() {
  install_requirements \
    && install_libernet \
    && add_libernet_environment \
    && enable_uhttp_php \
    && configure_libernet_firewall \
    && configure_libernet_service \
    && setup_system_logs \
    && finish_install
}

function main() {
  # install git if it's unavailable
  if [[ $(opkg list-installed git | grep -c git) != "1" ]]; then
    opkg update \
      && opkg install git
  fi
  if [[ $(opkg list-installed git-http | grep -c git-http) != "1" ]]; then
    opkg update \
      && opkg install git-http
  fi
  # create ~/Downloads directory if not exist
  if [[ ! -d "${DOWNLOADS_DIR}" ]]; then
    mkdir -p "${DOWNLOADS_DIR}"
  fi
  # install Libernet
  if [[ ! -d "${LIBERNET_TMP}" ]]; then
    git clone --depth 1 "${REPOSITORY_URL}" "${LIBERNET_TMP}" \
      && cd "${LIBERNET_TMP}" \
      && bash install.sh
  else
    cd "${LIBERNET_TMP}" \
      && main_installer
  fi
}

main
