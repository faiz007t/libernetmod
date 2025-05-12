#!/bin/sh

# Libernet Installer
# POSIX-compliant version with enhanced regex and error handling

# Check root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Configuration
HOME="/root"
ARCH=$(sed -n 's/^DISTRIB_ARCH='\''\(.*\)'\''/\1/p' /etc/openwrt_release)
LIBERNET_DIR="${HOME}/libernet"
LIBERNET_WWW="/www/libernet"
DOWNLOADS_DIR="${HOME}/Downloads"
LIBERNET_TMP="${DOWNLOADS_DIR}/libernet"
REPOSITORY_URL="https://github.com/faiz007t/libernetmod"
STATUS_LOG="${LIBERNET_DIR}/log/status.log"

install_packages() {
  opkg update
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    opkg list-installed | grep -q "^${pkg} " || opkg install "$pkg"
  done < requirements.txt
}

install_proprietary() {
  # Binaries
  while IFS= read -r bin; do
    [ -z "$bin" ] && continue
    command -v "$bin" >/dev/null || {
      echo "Installing $bin..."
      curl -sLko "/usr/bin/$bin" "https://github.com/faiz007t/libernet-proprietary/raw/main/${ARCH}/binaries/$bin"
      chmod 755 "/usr/bin/$bin"
    }
  done < binaries.txt

  # Packages
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    command -v "$pkg" >/dev/null || {
      tmp_pkg="/tmp/${pkg}.ipk"
      echo "Installing $pkg..."
      curl -sLko "$tmp_pkg" "https://github.com/faiz007t/libernet-proprietary/raw/main/${ARCH}/packages/${pkg}.ipk"
      opkg install "$tmp_pkg"
      rm -f "$tmp_pkg"
    }
  done < packages.txt
}

configure_firewall() {
  if ! uci get network.libernet >/dev/null 2>&1; then
    uci batch <<EOF
      set network.libernet=interface
      set network.libernet.proto='none'
      set network.libernet.ifname='tun1'
      
      add firewall zone
      set firewall.@zone[-1].name='libernet'
      set firewall.@zone[-1].network='libernet'
      set firewall.@zone[-1].input='REJECT'
      set firewall.@zone[-1].forward='REJECT'
      set firewall.@zone[-1].output='ACCEPT'
      
      add firewall forwarding
      set firewall.@forwarding[-1].src='lan'
      set firewall.@forwarding[-1].dest='libernet'
EOF
    uci commit
    /etc/init.d/network reload
  fi
}

get_router_ip() {
  ip=$(ubus call network.interface.lan status 2>/dev/null | \
       sed -n 's/.*"address":"\([^"]*\)".*/\1/p')
  [ -z "$ip" ] && ip=$(ifconfig br-lan 2>/dev/null | sed -n 's/.*inet addr:\([^ ]*\).*/\1/p')
  echo "${ip:-192.168.1.1}"
}

main_install() {
  # Install dependencies
  opkg update && opkg install git git-http

  # Clone repository
  mkdir -p "${DOWNLOADS_DIR}"
  [ -d "${LIBERNET_TMP}" ] || git clone --depth 1 "${REPOSITORY_URL}" "${LIBERNET_TMP}"
  cd "${LIBERNET_TMP}"

  # Install components
  install_packages
  install_proprietary

  # Stop existing service
  if [ -f "${LIBERNET_DIR}/bin/service.sh" ] && \
     [ "$(cat "${STATUS_LOG}" 2>/dev/null)" != "0" ]; then
    "${LIBERNET_DIR}/bin/service.sh" -ds >/dev/null 2>&1
  fi

  # Install files
  mkdir -p "${LIBERNET_DIR}" "${LIBERNET_WWW}"
  cp -af update.sh bin system log "${LIBERNET_DIR}"
  cp -af web/* "${LIBERNET_WWW}"
  sed -i "s|LIBERNET_DIR|${LIBERNET_DIR}|g" "${LIBERNET_WWW}/config.inc.php"

  # Configure environment
  if ! grep -q "LIBERNET_DIR" /etc/profile; then
    echo "export LIBERNET_DIR='${LIBERNET_DIR}'" >> /etc/profile
  fi

  # Enable PHP
  if ! grep -q ".php=/usr/bin/php-cgi" /etc/config/uhttpd; then
    uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci add_list uhttpd.main.index_page='index.php'
    uci commit uhttpd
    /etc/init.d/uhttpd restart
  fi

  # Configure firewall
  configure_firewall

  # Disable services
  for service in stubby shadowsocks-libev openvpn stunnel; do
    [ -x "/etc/init.d/${service}" ] && \
      /etc/init.d/"${service}" disable >/dev/null 2>&1
  done

  # Final output
  ip=$(get_router_ip)
  echo "========================================"
  echo "Libernet Installed Successfully!"
  echo "Dashboard: http://${ip}/libernet"
  echo "Credentials: admin / libernet"
  echo "Install Date: $(date +'%Y-%m-%d %H:%M:%S')"
  echo "========================================"
}

# Execute with error logging
main_install 2>&1 | tee "/root/libernet_install.log"
