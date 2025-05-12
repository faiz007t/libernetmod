#!/bin/sh

# Libernet Installer - Modified POSIX-compliant version
# Fixes shell compatibility, network detection, and permission issues

HOME="/root"
ARCH="$(grep 'DISTRIB_ARCH' /etc/openwrt_release | awk -F '=' '{print $2}' | sed "s/'//g")"
LIBERNET_DIR="${HOME}/libernet"
LIBERNET_WWW="/www/libernet"
STATUS_LOG="${LIBERNET_DIR}/log/status.log"
DOWNLOADS_DIR="${HOME}/downloads"
LIBERNET_TMP="${DOWNLOADS_DIR}/libernet"
REPOSITORY_URL="https://github.com/faiz007t/libernetmod"

install_packages() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "$(opkg list-installed "$line" | grep -c "$line")" = "0" ]; then
      opkg install "$line" || {
        echo "Failed to install $line"
        exit 1
      }
    fi
  done < requirements.txt
}

install_proprietary_binaries() {
  echo "Installing proprietary binaries"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! command -v "$line" >/dev/null 2>&1; then
      bin="/usr/bin/$line"
      echo "Installing $line..."
      curl -sLko "$bin" "https://github.com/faiz007t/libernet-proprietary/raw/main/${ARCH}/binaries/$line" || {
        echo "Failed to download $line"
        exit 1
      }
      chmod 755 "$bin"
    fi
  done < binaries.txt
}

install_proprietary_packages() {
  echo "Installing proprietary packages"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! command -v "$line" >/dev/null 2>&1; then
      pkg="/tmp/${line}.ipk"
      echo "Installing $line..."
      curl -sLko "$pkg" "https://github.com/faiz007t/libernet-proprietary/raw/main/${ARCH}/packages/${line}.ipk" || {
        echo "Failed to download $line.ipk"
        exit 1
      }
      opkg install "$pkg" || {
        rm -f "$pkg"
        exit 1
      }
      rm -f "$pkg"
    fi
  done < packages.txt
}

enable_uhttp_php() {
  if ! grep -q ".php=/usr/bin/php-cgi" /etc/config/uhttpd; then
    echo "Enabling uhttp php execution"
    uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci add_list uhttpd.main.index_page='index.php'
    uci commit uhttpd
    echo "Restarting uhttp service"
    /etc/init.d/uhttpd restart || {
      echo "Failed to restart uhttpd"
      exit 1
    }
  fi
}

configure_libernet_firewall() {
  if ! uci get network.libernet >/dev/null 2>&1; then
    echo "Configuring Libernet firewall"
    uci set network.libernet=interface
    uci set network.libernet.proto='none'
    uci set network.libernet.ifname='tun1'
    uci commit network
    sleep 2  # Allow interface registration
    
    uci add firewall zone
    uci set firewall.@zone[-1].network='libernet'
    uci set firewall.@zone[-1].name='libernet'
    uci set firewall.@zone[-1].masq='1'
    uci set firewall.@zone[-1].mtu_fix='1'
    uci set firewall.@zone[-1].input='REJECT'
    uci set firewall.@zone[-1].forward='REJECT'
    uci set firewall.@zone[-1].output='ACCEPT'
    uci commit firewall
    
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='lan'
    uci set firewall.@forwarding[-1].dest='libernet'
    uci commit firewall
    
    /etc/init.d/network reload || {
      echo "Failed to reload network"
      exit 1
    }
  fi
}

get_router_ip() {
  # Try multiple methods to get IP address
  ip=$(ubus call network.interface.lan status 2>/dev/null | \
       jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null)
  
  [ -z "$ip" ] && ip=$(ifconfig br-lan 2>/dev/null | awk '/inet addr/{print substr($2,6)}')
  [ -z "$ip" ] && ip=$(ifconfig eth0 2>/dev/null | awk '/inet addr/{print substr($2,6)}')
  
  echo "$ip"
}

main_installer() {
  # Install dependencies
  opkg update || {
    echo "Failed to update package lists"
    exit 1
  }
  
  install_packages
  install_proprietary_binaries
  install_proprietary_packages

  # Stop Libernet if running
  if [ -f "${LIBERNET_DIR}/bin/service.sh" ] && \
     [ "$(cat "${STATUS_LOG}" 2>/dev/null)" != "0" ]; then
    echo "Stopping Libernet"
    "${LIBERNET_DIR}/bin/service.sh" -ds >/dev/null 2>&1
  fi

  # Install core files
  echo "Installing Libernet"
  mkdir -p "${LIBERNET_DIR}" "${LIBERNET_WWW}"
  cp -af update.sh "${LIBERNET_DIR}/"
  cp -arf bin system log "${LIBERNET_DIR}/"
  cp -arf web/* "${LIBERNET_WWW}/"
  
  # Set permissions
  chmod 755 "${LIBERNET_DIR}/bin"/*
  chmod 755 /sbin/wifi 2>/dev/null

  # Configure environment
  echo "Configuring environment"
  sed -i "s|LIBERNET_DIR|${LIBERNET_DIR}|g" "${LIBERNET_WWW}/config.inc.php"
  grep -q "LIBERNET_DIR" /etc/profile || \
    echo "\n# Libernet\nexport LIBERNET_DIR=${LIBERNET_DIR}" >> /etc/profile

  # System configuration
  enable_uhttp_php
  configure_libernet_firewall
  
  # Service setup
  echo "Configuring services"
  for service in stubby shadowsocks-libev openvpn stunnel; do
    if [ -f "/etc/init.d/${service}" ]; then
      /etc/init.d/"$service" disable
      /etc/init.d/"$service" stop
    fi
  done

  # Log setup
  echo "Setting up logs"
  for log in status.log service.log connected.log; do
    [ -f "${LIBERNET_DIR}/log/${log}" ] || touch "${LIBERNET_DIR}/log/${log}"
  done

  # Final output
  router_ip=$(get_router_ip)
  echo "Libernet successfully installed!"
  echo "Access URL: http://${router_ip:-192.168.1.1}/libernet"
}

# Main execution
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
main_installer 2>&1 | tee /tmp/libernet_install.log
exit 0
