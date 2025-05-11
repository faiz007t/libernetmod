# Libernet Mod 
<li> Remove Login Page</li>
<li> Remove Speedtest Page</li>
<li> Change Theme Color</li>
<li> Change Background Image</li>
<li> Add Background Music</li>

## Libernet install first
```sh
opkg update && opkg install bash curl;bash -c "$(curl -sko - 'https://raw.githubusercontent.com/faiz007t/libernetmod/main/install.sh')"
```

## First install Libernet
```sh
opkg update && wget -O install.sh https://raw.githubusercontent.com/faiz007t/libernetmod/main/install.sh -q && sed -i 's/\r$//' install.sh && bash install.sh
```

## Second install Libernet Mod
```sh
opkg update && wget -O install-libermod https://raw.githubusercontent.com/faiz007t/libernet/main/install-libermod -q && sed -i 's/\r$//' install-libermod && bash install-libermod
```
