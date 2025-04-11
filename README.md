Here is an example `README.md` file for your OpenVPN setup repository. You can create this file in your repository to document the purpose and usage of the script.

markdown
# OpenVPN Setup Script for Ubuntu on Contabo VPS

This repository contains a shell script to automate the installation and configuration of an OpenVPN server on a Contabo VPS running Ubuntu.

## Features
- Installs OpenVPN and EasyRSA
- Sets up Public Key Infrastructure (PKI)
- Configures OpenVPN server settings
- Enables IP forwarding
- Configures UFW to allow OpenVPN traffic

## Prerequisites
- A Contabo VPS running Ubuntu (20.04 or later recommended)
- Root or sudo access to the server
- Basic knowledge of working with the Linux terminal

## How to Use
1. Clone this repository to your VPS:
   ```bash
   git clone https://github.com/maliq-eth/openvpn-setup.git
   cd openvpn-setup
   ```

2. Make the script executable:
   ```bash
   chmod +x install_openvpn.sh
   ```

3. Run the script:
   ```bash
   sudo ./install_openvpn.sh
   ```

4. Follow the on-screen instructions to complete the setup.

## Notes
- The script enables IP forwarding and configures UFW automatically.
- Edit the `vars` section in the script if you need to customize the EasyRSA configuration.
- Ensure that port `1194` is open in your VPS firewall and any external firewalls.

## Troubleshooting
If you encounter any issues:
- Check the OpenVPN server logs:
  ```bash
  sudo journalctl -u openvpn@server
  ```
- Verify that the UFW rules are correctly applied:
  ```bash
  sudo ufw status
  ```

## Contributing
Contributions are welcome! Feel free to open an issue or submit a pull request if you have any improvements or suggestions.

## License
This project is licensed under the MIT License. See the `LICENSE` file for details.
```

### Steps to Add the README to Your Repository
1. Save the above content in a file named `README.md`.
2. Add, commit, and push it to your repository:
   ```bash
   git add README.md
   git commit -m "Add README documentation"
   git push origin main
   ```

Let me know if you need help with further customization!
