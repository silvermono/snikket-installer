# Snikket XMPP Service Installer for Ubuntu Server

This script automates the installation of Snikket XMPP (Extensible Messaging and Presence Protocol) service on an Ubuntu Server. [Snikket](https://snikket.org/) is a simple, private, and secure instant messaging server powered by XMPP.

## Features

- Fully automated installation of Snikket XMPP service on Ubuntu Server.
- Configures necessary components such as Prosody, Let's Encrypt for SSL certificates, and more.
- Option to config iptables or UFW Firewall
- Easy-to-use ineractive script that reduces manual installation steps.
- Designed for Ubuntu 20.04 and newer versions.

## Prerequisites

Before running the installation script, ensure your server meets the following requirements:

- A fresh Ubuntu Server installation (Ubuntu 20.04 or newer).
- A domain name pointing to your server's IP address (e.g., A record for `chat.yourdomain.com`).
- CNAME records for `share.chat.yourdomain.com`, `groups.chat.yourdomain.com` pointing to `chat.yourdomain.com`.
- Sudo or root access to your Ubuntu server.
- A working internet connection.
  
## How to run

- Download the script: `wget https://raw.githubusercontent.com/silvermono/snikket-installer/refs/heads/main/snikket-installer.sh`
- Inspect the script and make sure that You understand what it does to your system.
- Run as root: `sudo bash snikket-installer.sh`

## Install With BASH One-liner

> *Be sure that You understand the risks of piping directly into BASH as root!*

`curl https://raw.githubusercontent.com/silvermono/snikket-installer/refs/heads/main/snikket-installer.sh | sudo bash`

> Somethimes up and down arrown may not work with this method

## What's Next

Fine tune Your server. For detailed information, please visit the official [Advanced configuration](https://snikket.org/service/help/advanced/config/) section on Snikket's web site.

* * *

“Snikket” and the parrot logo are trademarks of Snikket Community Interest Company.
