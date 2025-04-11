#!/bin/bash

# ================================================
# OpenVPN Setup Script - Interaktif
# Tested on Ubuntu/Debian (Contabo VPS)
# ================================================

# Warna
green='\e[32m'
red='\e[31m'
nc='\e[0m'

function pause(){
  read -rp "Tekan [Enter] untuk melanjutkan..."
}

function install_openvpn() {
  echo -e "${green}Mulai instalasi OpenVPN...${nc}"
  apt update && apt install -y openvpn easy-rsa iptables curl

  make-cadir ~/openvpn-ca
  cd ~/openvpn-ca || exit

  # EasyRSA 3 setup
  git clone https://github.com/OpenVPN/easy-rsa.git ~/easy-rsa
  cd ~/easy-rsa/easyrsa3 || exit

  ./easyrsa init-pki
  ./easyrsa build-ca nopass
  ./easyrsa gen-dh
  ./easyrsa build-server-full server nopass
  ./easyrsa build-client-full client1 nopass
  ./easyrsa gen-crl

  # Copy file penting ke /etc/openvpn
  cp pki/ca.crt pki/private/ca.key pki/issued/server.crt \
     pki/private/server.key pki/dh.pem pki/crl.pem /etc/openvpn

  # Buat konfigurasi server
  cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
crl-verify crl.pem
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

  # Enable IP Forwarding
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  sysctl -p

  # Atur firewall
  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $(ip route get 1 | awk '{print $5}') -j MASQUERADE
  iptables-save > /etc/iptables.rules

  # Enable dan mulai OpenVPN
  systemctl enable openvpn@server
  systemctl start openvpn@server

  echo -e "${green}OpenVPN berhasil diinstal dan dijalankan.${nc}"
  pause
}

function create_client() {
  echo -n "Masukkan nama client: "
  read -r client
  cd ~/easy-rsa/easyrsa3 || exit
  ./easyrsa build-client-full "$client" nopass

  # Buat file .ovpn
  mkdir -p ~/client-configs/files
  cat > ~/client-configs/files/"$client".ovpn <<EOF
client
dev tun
proto udp
remote $(curl -s ifconfig.me) 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3

<ca>
$(cat pki/ca.crt)
</ca>
<cert>
$(cat pki/issued/"$client".crt)
</cert>
<key>
$(cat pki/private/"$client".key)
</key>
EOF

  echo -e "${green}Client config $client.ovpn berhasil dibuat di ~/client-configs/files/${nc}"
  pause
}

function list_clients() {
  echo -e "${green}Daftar Client:${nc}"
  ls ~/easy-rsa/easyrsa3/pki/issued/
  pause
}

function remove_client() {
  echo -n "Masukkan nama client yang akan dihapus: "
  read -r client
  cd ~/easy-rsa/easyrsa3 || exit
  ./easyrsa revoke "$client"
  ./easyrsa gen-crl
  cp pki/crl.pem /etc/openvpn/crl.pem
  rm -f ~/client-configs/files/"$client".ovpn
  echo -e "${green}Client $client telah dihapus.${nc}"
  pause
}

function uninstall_openvpn() {
  echo -e "${red}WARNING: Ini akan menghapus OpenVPN dan semua konfigurasinya.${nc}"
  read -rp "Ketik 'ya' untuk melanjutkan: " confirm
  if [[ "$confirm" == "ya" ]]; then
    systemctl stop openvpn@server
    apt remove --purge -y openvpn easy-rsa
    rm -rf /etc/openvpn ~/easy-rsa ~/client-configs ~/openvpn-ca
    echo -e "${red}OpenVPN telah dihapus.${nc}"
  fi
  pause
}

function main_menu() {
  while true; do
    clear
    echo -e "${green}========= OpenVPN Menu =========${nc}"
    echo "1. Install OpenVPN"
    echo "2. Tambah Client"
    echo "3. Hapus Client"
    echo "4. Lihat Daftar Client"
    echo "5. Uninstall OpenVPN"
    echo "6. Keluar"
    echo "================================="
    read -rp "Pilih menu [1-6]: " menu
    case $menu in
      1) install_openvpn ;;
      2) create_client ;;
      3) remove_client ;;
      4) list_clients ;;
      5) uninstall_openvpn ;;
      6) exit 0 ;;
      *) echo "Pilihan tidak valid!" ; pause ;;
    esac
  done
}

main_menu
