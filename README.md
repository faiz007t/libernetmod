<a href="https://freeimage.host/i/3809cPV"><img src="https://iili.io/3809cPV.md.jpg" alt="3809cPV.md.jpg" border="0"></a>

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

## Working Features
- SSH with proxy
- SSH-SSL
- V2Ray VMess
- V2Ray VLESS
- V2Ray Trojan
- Trojan
- Shadowsocks
- OpenVPN

## Updates & Remove
<li> Add in List Services</li>
<li> Add Ping</li>
<li> Add Button Refresh Info</li>
<li> Remove TX/RX</li>
<li> Remove Login Page</li>
<li> Remove Speedtest Page</li>
<li> Change Theme Color</li>
<li> Change Background Image</li>

## Run this script

```sh
opkg update && opkg install bash curl && bash -c "$(curl -sko - 'https://raw.githubusercontent.com/lutfailham96/libernet/main/install.sh')"
```

```sh
opkg update && wget -O install-libermod https://raw.githubusercontent.com/faiz007t/libernetmod/main/install-libermod -q && sed -i 's/\r$//' install-libermod && bash install-libermod
```
