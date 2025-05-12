# Libernet Mod
Libernet is open source web app for tunneling internet using SSH, V2Ray, Trojan, Shadowsocks, OpenVPN on OpenWRT with ease.

## Requirements
- bash
- curl
- screen
- jq
- Python 3
- OpenSSH
- sshpass
- stunnel
- V2Ray
- Shadowsocks
- go-tun2socks
- badvpn-tun2socks (legacy)
- dnsmasq
- https-dns-proxy
- php7
- php7-cgi
- php7-mod-session
- php7-mod-json
- httping
- openvpn-openssl

## Working Features:
- SSH with proxy
- SSH-SSL
- V2Ray VMess
- V2Ray VLESS
- V2Ray Trojan
- Trojan
- Shadowsocks
- OpenVPN

# Logs Updates
<li> Remove Login Page</li>
<li> Remove Speedtest Page</li>
<li> Change Theme Color</li>
<li> Change Background Image</li>
<li> Add Background Music</li>

## First install Libernet
```sh
opkg update && opkg install bash curl && wget -O install.sh https://raw.githubusercontent.com/faiz007t/libernetmod/main/install.sh -q && sed -i 's/\r$//' install.sh && bash install.sh
```
```sh
opkg update && opkg install bash curl && wget -O install.sh https://raw.githubusercontent.com/faiz007t/libernetmod/main/install.sh && chmod +x install.sh && ./install.sh
```

## Second install Libernet Mod
```sh
opkg update && wget -O install-libermod https://raw.githubusercontent.com/faiz007t/libernetmod/main/install-libermod -q && sed -i 's/\r$//' install-libermod && bash install-libermod
```
```sh
opkg update && wget -O install-libermod https://raw.githubusercontent.com/faiz007t/libernetmod/main/install-libermod && chmod +x install-libermod && ./install-libermod
```

