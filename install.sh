#!/bin/sh

# Libernet Installer (for faiz007t/libernetmod)
# by Lutfa Ilham, modified for direct download and robust output

REPO_URL="https://github.com/faiz007t/libernetmod"
PROP_URL="https://github.com/faiz007t/libernet-proprietary/raw/main"
BRANCH="main"
TMP_DIR=$(mktemp -d)
INSTALL_DIR="/root/libernet"
WWW_DIR="/www/libernet"

# Cleanup on exit
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

# Root check
[ "$(id -u)" != "0" ] && { echo "ERROR: Run as root" >&2; exit 1; }

# Detect architecture
ARCH="$(grep -o "DISTRIB_ARCH='[^']*'" /etc/openwrt_release | cut -d"'" -f2)"
[ -z "$ARCH" ] && { echo "ERROR: Architecture detection failed"; exit 1; }

download_file() {
  # $1 = remote path, $2 = local path
  curl -fsSL "$REPO_URL/raw/$BRANCH/$1" -o "$2" || {
    echo "ERROR: Failed to download $1" >&2
    exit 1
  }
}

# Download essential files
for f in requirements.txt binaries.txt packages.txt update.sh; do
  download_file "$f" "$TMP_DIR/$f"
done

# Download directories (bin, system, log, web)
for d in bin system log web; do
  mkdir -p "$TMP_DIR/$d"
  # Get file list via GitHub API (raw HTML parsing fallback)
  curl -fsSL "$REPO_URL/tree/$BRANCH/$d" | grep -Eo 'href="[^"]+' | grep "/$d/" | grep -v '/tree/' | sed 's/^href="//' | while read -r path; do
    fname="$(basename "$path")"
    [ -n "$fname" ] && download_file "$d/$fname" "$TMP_DIR/$d/$fname"
  done
done

# Dependency install
opkg update
while IFS= read -r pkg; do
  [ -n "$pkg" ] && opkg list-installed | grep -q "^$pkg " || opkg install "$pkg"
done < "$TMP_DIR/requirements.txt"

# Proprietary binaries
echo "Installing proprietary binaries"
while IFS= read -r bin; do
  [ -z "$bin" ] && continue
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Installing $bin..."
    curl -fsSL "$PROP_URL/$ARCH/binaries/$bin" -o "/usr/bin/$bin"
    chmod 755 "/usr/bin/$bin"
  fi
done < "$TMP_DIR/binaries.txt"

# Proprietary packages
echo "Installing proprietary packages"
while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  if ! command -v "$pkg" >/dev/null 2>&1; then
    tmp_pkg="/tmp/${pkg}.ipk"
    echo "Installing $pkg..."
    curl -fsSL "$PROP_URL/$ARCH/packages/$pkg.ipk" -o "$tmp_pkg"
    opkg install "$tmp_pkg"
    rm -f "$tmp_pkg"
  fi
done < "$TMP_DIR/packages.txt"

# Install core files
mkdir -p "$INSTALL_DIR" "$WWW_DIR"
cp -a "$TMP_DIR"/{update.sh,bin,system,log} "$INSTALL_DIR"
cp -a "$TMP_DIR"/web/* "$WWW_DIR"
sed -i "s|LIBERNET_DIR|$INSTALL_DIR|g" "$WWW_DIR/config.inc.php"

# Environment variable
grep -q "LIBERNET_DIR" /etc/profile || echo "export LIBERNET_DIR='$INSTALL_DIR'" >> /etc/profile

# uHTTPd PHP config
uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
uci add_list uhttpd.main.index_page='index.php'
uci commit uhttpd
/etc/init.d/uhttpd restart

# Firewall config
if ! uci get network.libernet >/dev/null 2>&1; then
  uci set network.libernet=interface
  uci set network.libernet.proto='none'
  uci set network.libernet.ifname='tun1'
  uci commit network
  uci add firewall zone
  uci set firewall.@zone[-1].name='libernet'
  uci set firewall.@zone[-1].network='libernet'
  uci set firewall.@zone[-1].input='REJECT'
  uci set firewall.@zone[-1].forward='REJECT'
  uci set firewall.@zone[-1].output='ACCEPT'
  uci commit firewall
  uci add firewall forwarding
  uci set firewall.@forwarding[-1].src='lan'
  uci set firewall.@forwarding[-1].dest='libernet'
  uci commit firewall
  /etc/init.d/network reload
fi

# Output summary
LAN_IP="$(ubus call network.interface.lan status 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address')"
[ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"
echo "========================================"
echo " Libernet Installation Complete!"
echo " Access URL: http://$LAN_IP/libernet"
echo " Credentials: admin / libernet"
echo " Install Date: $(date +'%Y-%m-%d %H:%M:%S')"
echo "========================================"
