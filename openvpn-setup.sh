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

  openvpn --genkey secret /etc/openvpn/ta.key

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
tls-crypt ta.key
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
    echo "Tidak ada IP lokal yang ditemukan. Mencoba mendapatkan IP publik..."
    ip_list[0]=$(curl -4 -s ifconfig.me || echo "Tidak ada IP")
  fi

  echo "Hasil daftar IP: ${ip_list[*]}" # Debug Output
  printf "%s\n" "${ip_list[@]}"
}

function select_ip() {
  local ips=()
  local selected_ip
  while IFS= read -r line; do
    ips+=("$line")
  done < <(get_ipv4_options)

  if [[ ${#ips[@]} -eq 0 || ${ips[0]} == "Tidak ada IP" ]]; then
    echo "Gagal mendapatkan IP publik atau lokal. Pastikan server memiliki koneksi internet dan IP yang valid."
    exit 1
  fi

  if [[ ${#ips[@]} -eq 1 ]]; then
    selected_ip="${ips[0]}"
    echo "$selected_ip"
  else
    echo -e "\nPilih IP publik yang akan digunakan untuk klien:"
    for i in "${!ips[@]}"; do
      echo "$((i + 1)). ${ips[$i]}"
    done

    while true; do
      read -rp "Pilih [1-${#ips[@]}]: " ip_choice
      if [[ $ip_choice =~ ^[0-9]+$ ]] && ((ip_choice >= 1 && ip_choice <= ${#ips[@]})); then
        selected_ip="${ips[$((ip_choice - 1))]}"
        echo "$selected_ip"
        return
      else
        echo "Pilihan tidak valid, coba lagi."
      fi
    done
  fi
}

function create_client() {
  echo -n "Masukkan nama client: "
  read -r unsanitized_client
  client=$(sed 's/[^a-zA-Z0-9_-]/_/g' <<< "$unsanitized_client")

  if [[ -z $client ]]; then
    echo "Nama client tidak boleh kosong atau hanya berisi karakter yang difilter."
    return
  fi

  cd ~/openvpn-ca/easy-rsa/easyrsa3 || exit
  ./easyrsa build-client-full "$client" nopass

  mkdir -p ~/client-configs/files
  selected_ip=$(select_ip)

  {
    echo "client"
    echo "dev tun"
    echo "proto udp4"
    echo "remote $selected_ip 1194"
    echo "resolv-retry infinite"
    echo "nobind"
    echo "persist-key"
    echo "persist-tun"
    echo "remote-cert-tls server"
    echo "cipher AES-256-CBC"
    echo "verb 3"
    echo "<ca>"
    cat pki/ca.crt
    echo "</ca>"
    echo "<cert>"
    sed -ne '/BEGIN CERTIFICATE/,$ p' pki/issued/"$client".crt
    echo "</cert>"
    echo "<key>"
    cat pki/private/"$client".key
    echo "</key>"
    echo "<tls-crypt>"
    sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/ta.key
    echo "</tls-crypt>"
  } > ~/client-configs/files/"$client".ovpn

  echo -e "${green}Client config $client.ovpn berhasil dibuat di ~/client-configs/files/${nc}"
  pause
}
