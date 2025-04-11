#!/bin/bash

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Install OpenVPN and EasyRSA
echo "Installing OpenVPN and EasyRSA..."
sudo apt-get install -y openvpn easy-rsa

# Make the EasyRSA directory
echo "Setting up the EasyRSA directory..."
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

# Configure the vars file
echo "Configuring EasyRSA vars..."
cat << EOF > vars
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "California"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "ContaboVPN"
set_var EASYRSA_REQ_EMAIL      "admin@example.com"
set_var EASYRSA_REQ_OU         "CommunityVPN"
EOF

# Build the PKI, CA, and Server Certificate
echo "Building the PKI, CA, and Server Certificate..."
source vars
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server

# Generate Diffie-Hellman parameters
echo "Generating Diffie-Hellman parameters..."
./easyrsa gen-dh

# Generate a CRL (Certificate Revocation List)
echo "Generating a CRL..."
./easyrsa gen-crl

# Move the server certificates and keys
echo "Moving server certificates and keys to /etc/openvpn..."
sudo cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/dh.pem /etc/openvpn/

# Configure the OpenVPN server
echo "Configuring OpenVPN server..."
sudo cat << EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
keepalive 10 120
cipher AES-256-CBC
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Configure UFW to allow OpenVPN traffic
echo "Configuring UFW to allow OpenVPN traffic..."
sudo ufw allow 1194/udp
sudo ufw allow OpenSSH
sudo ufw disable
sudo ufw enable

# Start and enable the OpenVPN service
echo "Starting and enabling OpenVPN service..."
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server

# Notify the user of completion
echo "OpenVPN server installation and configuration complete!"
