#!/bin/sh

# Libernet Installer (faiz007t/libernetmod)
# Robust installation with architecture validation and duplicate checking

REPO_URL="https://github.com/faiz007t/libernetmod"
PROP_URL="https://github.com/faiz007t/libernet-proprietary/raw/main"
BRANCH="main"
TMP_DIR=$(mktemp -d)
INSTALL_DIR="/root/libernet"
WWW_DIR="/www/libernet"

# Cleanup handler
cleanup() {
  rm -rf "$TMP_DIR"
  exit
}
trap cleanup EXIT INT TERM

# Root verification
[ "$(id -u)" != "0" ] && { echo "ERROR: Run as root" >&2; exit 1; }

# Architecture detection
ARCH=$(grep -o "DISTRIB_ARCH='[^']*'" /etc/openwrt_release | cut -d"'" -f2)
[ -z "$ARCH" ] && { echo "ERROR: Architecture detection failed"; exit 1; }

# File downloader with validation
download_file() {
  echo "Downloading $1..."
  if ! curl -fsSL -o "$TMP_DIR/$1" "$REPO_URL/raw/$BRANCH/$1"; then
    echo "ERROR: Failed to download $1" >&2
    exit 1
  fi
}

# Directory downloader
download_dir() {
  mkdir -p "$TMP_DIR/$1"
  curl -sSL "$REPO_URL/tree/$BRANCH/$1" | 
    grep -Eo 'href="[^"]+"' | 
    awk -F'"' '{print $2}' |
    while read -r item; do
      case $item in
        */$1/*) 
          fname="${item##*/}"
          [ -n "$fname" ] && download_file "$1/$fname"
          ;;
      esac
    done
}

# Main installation process
{
  echo "=== Initializing Installation ==="
  
  # Download core components
  echo "- Downloading base files..."
  for file in requirements.txt binaries.txt packages.txt update.sh; do
    download_file "$file"
  done

  echo "- Downloading directories..."
  for dir in bin system log web; do
    download_dir "$dir"
  done

  # Dependency installation
  echo "=== Installing Dependencies ==="
  opkg update || { echo "ERROR: Package update failed"; exit 1; }
  while IFS= read -r pkg; do
    [ -n "$pkg" ] && opkg list-installed | grep -q "^$pkg " || opkg install "$pkg"
  done < "$TMP_DIR/requirements.txt"

  # Proprietary binaries
  echo "=== Installing Proprietary Binaries ==="
  while IFS= read -r bin; do
    [ -z "$bin" ] && continue
    if command -v "$bin" >/dev/null 2>&1; then
      echo "  $bin already installed, skipping."
      continue
    fi
    echo "Installing $bin..."
    curl -fsSL -o "/usr/bin/$bin" "$PROP_URL/$ARCH/binaries/$bin" || {
      echo "ERROR: Failed to download $bin for $ARCH"
      exit 1
    }
    chmod 755 "/usr/bin/$bin"
  done < "$TMP_DIR/binaries.txt"

  # Proprietary packages
  echo "=== Installing Proprietary Packages ==="
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if opkg list-installed | grep -q "^$pkg "; then
      echo "  $pkg already installed, skipping."
      continue
    fi
    tmp_pkg="/tmp/${pkg}.ipk"
    echo "Installing $pkg..."
    curl -fsSL -o "$tmp_pkg" "$PROP_URL/$ARCH/packages/$pkg.ipk" || {
      echo "ERROR: Failed to download $pkg.ipk"
      exit 1
    }
    opkg install "$tmp_pkg" || {
      rm -f "$tmp_pkg"
      echo "ERROR: Failed to install $pkg"
      exit 1
    }
    rm -f "$tmp_pkg"
  done < "$TMP_DIR/packages.txt"

  # Core installation
  echo "=== Installing Libernet Core ==="
  mkdir -p "$INSTALL_DIR" "$WWW_DIR"
  cp -a "$TMP_DIR"/{update.sh,bin,system,log} "$INSTALL_DIR"
  cp -a "$TMP_DIR"/web/* "$WWW_DIR"
  sed -i "s|LIBERNET_DIR|$INSTALL_DIR|g" "$WWW_DIR/config.inc.php"

  # Environment configuration
  grep -q "LIBERNET_DIR" /etc/profile || echo "export LIBERNET_DIR='$INSTALL_DIR'" >> /etc/profile

  # PHP configuration
  uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
  uci add_list uhttpd.main.index_page='index.php'
  uci commit uhttpd
  /etc/init.d/uhttpd restart

  # Firewall configuration
  if ! uci get network.libernet >/dev/null; then
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

  # Final output
  ip=$(ubus call network.interface.lan status 2>/dev/null | 
       sed -n 's/.*"address":"\([^"]*\)".*/\1/p')
  [ -z "$ip" ] && ip="192.168.1.1"
  echo "========================================"
  echo " Libernet Installation Complete!"
  echo " Dashboard: http://$ip/libernet"
  echo " Credentials: admin / libernet"
  echo " Install Date: $(date +'%Y-%m-%d %H:%M:%S')"
  echo "========================================"
} 2>&1 | tee "/tmp/libernet_install.log"
