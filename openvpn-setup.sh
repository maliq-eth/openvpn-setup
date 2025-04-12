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
  apt update && apt install -y openvpn easy-rsa iptables curl git

  mkdir -p ~/openvpn-ca
  git clone https://github.com/OpenVPN/easy-rsa.git ~/openvpn-ca/easy-rsa
  cd ~/openvpn-ca/easy-rsa/easyrsa3 || exit

  ./easyrsa init-pki
  ./easyrsa build-ca nopass
  ./easyrsa gen-dh
  ./easyrsa build-server-full server nopass
  ./easyrsa build-client-full client1 nopass
  ./easyrsa gen-crl

  cp pki/ca.crt pki/private/ca.key pki/issued/server.crt \
     pki/private/server.key pki/dh.pem pki/crl.pem /etc/openvpn

  cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp4
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

  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  sysctl -p

  iface=$(ip route get 1 | awk '{print $5; exit}')
  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$iface" -j MASQUERADE

  iptables-save > /etc/iptables.rules
  echo -e '#!/bin/sh\niptables-restore < /etc/iptables.rules' > /etc/network/if-pre-up.d/iptables
  chmod +x /etc/network/if-pre-up.d/iptables

  systemctl enable openvpn@server
  systemctl start openvpn@server

  echo -e "${green}OpenVPN berhasil diinstal dan dijalankan.${nc}"
  pause
}

function get_ipv4_options() {
  mapfile -t ip_list < <(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1)

  if [[ ${#ip_list[@]} -eq 0 ]]; then
    ip_list[0]=$(curl -4 -s ifconfig.me)
  fi

  echo "${ip_list[@]}"
}

function select_ip() {
  local ips=($(get_ipv4_options))

  if [[ ${#ips[@]} -eq 1 ]]; then
    echo "${ips[0]}"
  else
    echo -e "${green}Pilih IP publik yang akan digunakan untuk klien:${nc}"
    for i in "${!ips[@]}"; do
      echo "$((i+1)). ${ips[$i]}"
    done
    read -rp "Pilih [1-${#ips[@]}]: " ip_choice
    echo "${ips[$((ip_choice-1))]}"
  fi
}

function create_client() {
  echo -n "Masukkan nama client: "
  read -r client
  cd ~/openvpn-ca/easy-rsa/easyrsa3 || exit
  ./easyrsa build-client-full "$client" nopass

  mkdir -p ~/client-configs/files

  selected_ip=$(select_ip)

  cat > ~/client-configs/files/"$client".ovpn <<EOF
client
dev tun
proto udp4
remote $selected_ip 1194
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
  ls ~/openvpn-ca/easy-rsa/easyrsa3/pki/issued/
  pause
}

function remove_client() {
  echo -n "Masukkan nama client yang akan dihapus: "
  read -r client
  cd ~/openvpn-ca/easy-rsa/easyrsa3 || exit
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
    rm -rf /etc/openvpn ~/openvpn-ca ~/client-configs
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
