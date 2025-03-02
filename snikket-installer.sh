#!/bin/bash

# Function to check and install whiptail if not present
install_whiptail() {
  if ! command -v whiptail &> /dev/null; then
    echo "whiptail is not installed. Installing whiptail..."
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y whiptail > /dev/null 2>&1
    if ! command -v whiptail &> /dev/null; then
      echo "Failed to install whiptail. Please install it manually and run the script again."
      exit 1
    fi
    echo "whiptail has been installed successfully."
  fi
}

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root or with sudo privileges."
  echo "Please run the script again as a user with administrative rights."
  exit 1
fi

# Install whiptail if not already installed
install_whiptail

# Function to display a spinner while a command is running
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Function to check DNS records
check_dns() {
  local domain=$1
  local required_records=("A:$domain" "CNAME:groups.$domain" "CNAME:share.$domain")

  for record in "${required_records[@]}"; do
    type=$(echo "$record" | cut -d: -f1)
    name=$(echo "$record" | cut -d: -f2)

    if ! dig +short "$name" "$type" | grep -q '^[^;]'; then
      whiptail --title "DNS Error" --msgbox "The $type record for $name is not configured correctly.\n\nPlease configure the following DNS records before proceeding:\n1. An A record for $domain pointing to your server's IP address.\n2. CNAME records for groups.$domain and share.$domain pointing to $domain." 15 80
      return 1
    fi
  done
  return 0
}

# Function to install Docker using the official convenience script
install_docker() {
  (
    echo 10
    echo "Downloading Docker installation script..."
    curl -fsSL https://get.docker.com -o get-docker.sh > /dev/null 2>&1
    echo 30
    echo "Installing Docker..."
    sh get-docker.sh > /dev/null 2>&1
    echo 70
    echo "Cleaning up..."
    rm get-docker.sh
    echo 100
    echo "Docker has been installed successfully!"
  ) | whiptail --title "Installing Docker" --gauge "Please wait while Docker is being installed..." 10 60 0
}

# Function to install Docker Compose
install_docker_compose() {
  if ! command -v docker-compose &> /dev/null; then
    echo "docker-compose is not installed. Installing docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')" -o /usr/local/bin/docker-compose > /dev/null 2>&1
    sudo chmod +x /usr/local/bin/docker-compose
    if ! command -v docker-compose &> /dev/null; then
      echo "Failed to install docker-compose. Please install it manually and run the script again."
      exit 1
    fi
    echo "docker-compose has been installed successfully."
  fi
}

# Function to install Snikket
install_snikket() {
  local domain=$1
  local admin_email=$2

  # Create the Snikket directory
  mkdir -p /etc/snikket
  cd /etc/snikket || { echo "Failed to change directory to /etc/snikket"; exit 1; }

  # Download the docker-compose.yml file
  curl -o docker-compose.yml https://snikket.org/service/resources/docker-compose.yml > /dev/null 2>&1

  # Create the snikket.conf file
  cat <<EOF > snikket.conf
# The primary domain of your Snikket instance
SNIKKET_DOMAIN=$domain

# An email address where the admin can be contacted
# (also used to register your Let's Encrypt account to obtain certificates)
SNIKKET_ADMIN_EMAIL=$admin_email
EOF

  # Start the Snikket server
  docker compose up -d > /dev/null 2>&1

  # Wait for the service to start
  echo "Waiting for Snikket to start..."
  for i in {1..30}; do
    if nc -z localhost 80 && nc -z localhost 443 && nc -z localhost 5222; then
      break
    fi
    sleep 1
  done

  # Check if the service is running
  if nc -z localhost 80 && nc -z localhost 443 && nc -z localhost 5222; then
    # Generate the admin registration link
    ADMIN_REGISTRATION_LINK=$(docker exec snikket create-invite --admin --group default 2>/dev/null)
    if [ -z "$ADMIN_REGISTRATION_LINK" ]; then
      whiptail --title "Error" --msgbox "Failed to generate the admin registration link. Please check the Snikket logs for more details." 10 60
    else
      whiptail --title "Admin Registration Link" --msgbox "Snikket has been installed successfully!\n\nUse the following link to register your admin account:\n$ADMIN_REGISTRATION_LINK" 15 80
    fi
  else
    echo "Snikket is still starting. Waiting for another 30 seconds..."
    sleep 30
    if nc -z localhost 80 && nc -z localhost 443 && nc -z localhost 5222; then
      # Generate the admin registration link
      ADMIN_REGISTRATION_LINK=$(docker exec snikket create-invite --admin --group default 2>/dev/null)
      if [ -z "$ADMIN_REGISTRATION_LINK" ]; then
        whiptail --title "Error" --msgbox "Failed to generate the admin registration link. Please check the Snikket logs for more details." 10 60
      else
        whiptail --title "Admin Registration Link" --msgbox "Snikket has been installed successfully!\n\nUse the following link to register your admin account:\n$ADMIN_REGISTRATION_LINK" 15 80
      fi
    else
      whiptail --title "Error" --msgbox "Something went wrong. Snikket did not start properly." 10 60
    fi
  fi
}

# Function to generate a registration link
generate_registration_link() {
  if [ ! -d "/etc/snikket" ]; then
    whiptail --title "Error" --msgbox "Snikket is not installed. Please install Snikket first." 10 60
    return
  fi

  cd /etc/snikket || { echo "Failed to change directory to /etc/snikket"; exit 1; }

  REGISTRATION_LINK=$(docker exec snikket create-invite --group default 2>/dev/null)
  if [ -z "$REGISTRATION_LINK" ]; then
    whiptail --title "Error" --msgbox "Failed to generate the registration link. Please check the Snikket logs for more details." 10 60
  else
    whiptail --title "Registration Link" --msgbox "Use the following link to register a new account:\n$REGISTRATION_LINK" 15 80
  fi
}

# Function to uninstall Snikket
uninstall_snikket() {
  # Display a warning message in red
  echo -e "\e[91mWARNING: This action is irreversible! All Snikket data and configuration will be permanently deleted.\e[0m"
  if whiptail --title "Warning" --yesno "Are you sure you want to uninstall Snikket? This will permanently delete all data and configuration!" 10 60; then
    (
      echo 20
      echo "Stopping and removing Snikket container..."
      docker compose down > /dev/null 2>&1
      echo 50
      echo "Removing Snikket Docker image..."
      docker rmi snikket/snikket:latest > /dev/null 2>&1
      echo 80
      echo "Removing Snikket data volume..."
      docker volume rm snikket-data > /dev/null 2>&1
      echo 90
      echo "Deleting Snikket configuration directory..."
      rm -rf /etc/snikket
      echo 100
      echo "Snikket has been uninstalled successfully!"
    ) | whiptail --title "Uninstalling Snikket" --gauge "Please wait while Snikket is being uninstalled..." 10 60 0

    # Remove firewall rules
    configure_firewall "remove"
  else
    whiptail --title "Cancelled" --msgbox "Uninstallation has been cancelled." 10 60
  fi
}

# Function to configure or remove firewall rules
configure_firewall() {
  local action=${1:-"add"}  # Default action is "add"

  if command -v ufw &> /dev/null; then
    # Using UFW
    if [ "$action" = "remove" ]; then
      whiptail --title "Firewall Configuration" --msgbox "Removing Snikket firewall rules using UFW..." 10 60
      ufw delete allow 80/tcp
      ufw delete allow 443/tcp
      ufw delete allow 5222/tcp
      ufw delete allow 5269/tcp
      ufw delete allow 5000/tcp  # Remove port 5000
      ufw delete allow 3478/tcp
      ufw delete allow 3479/tcp
      ufw delete allow 3478/udp
      ufw delete allow 3479/udp
      ufw delete allow 5349/tcp
      ufw delete allow 5350/tcp
      ufw delete allow 5349/udp
      ufw delete allow 5350/udp
      ufw delete allow 49152:65535/udp
    else
      whiptail --title "Firewall Configuration" --msgbox "Configuring firewall using UFW..." 10 60

      # Allow SSH (port 22)
      if whiptail --title "SSH Access" --yesno "Should SSH (port 22) be accessible from anywhere?" 10 60; then
        ufw allow 22/tcp
      else
        SSH_IP=$(whiptail --title "SSH Access" --inputbox "Enter the IP address to allow SSH access:" 10 60 3>&1 1>&2 2>&3)
        if [ -n "$SSH_IP" ]; then
          ufw allow from "$SSH_IP" to any port 22 proto tcp
        else
          whiptail --title "Error" --msgbox "No IP address provided. SSH access will remain unchanged." 10 60
        fi
      fi

      # Allow Snikket ports
      ufw allow 80/tcp
      ufw allow 443/tcp
      ufw allow 5222/tcp
      ufw allow 5269/tcp
      ufw allow 5000/tcp
      ufw allow 3478/tcp
      ufw allow 3479/tcp
      ufw allow 3478/udp
      ufw allow 3479/udp
      ufw allow 5349/tcp
      ufw allow 5350/tcp
      ufw allow 5349/udp
      ufw allow 5350/udp
      ufw allow 49152:65535/udp

      # Enable UFW
      ufw --force enable
    fi

    whiptail --title "Firewall Configuration" --msgbox "Firewall configuration completed successfully!" 10 60

  elif command -v iptables &> /dev/null; then
    # Using iptables
    if [ "$action" = "remove" ]; then
      whiptail --title "Firewall Configuration" --msgbox "Removing Snikket firewall rules using iptables..." 10 60
      iptables -D INPUT -p tcp --dport 80 -j ACCEPT
      iptables -D INPUT -p tcp --dport 443 -j ACCEPT
      iptables -D INPUT -p tcp --dport 5222 -j ACCEPT
      iptables -D INPUT -p tcp --dport 5269 -j ACCEPT
      iptables -D INPUT -p tcp --dport 5000 -j ACCEPT  # Remove port 5000
      iptables -D INPUT -p tcp --dport 3478 -j ACCEPT
      iptables -D INPUT -p tcp --dport 3479 -j ACCEPT
      iptables -D INPUT -p udp --dport 3478 -j ACCEPT
      iptables -D INPUT -p udp --dport 3479 -j ACCEPT
      iptables -D INPUT -p tcp --dport 5349 -j ACCEPT
      iptables -D INPUT -p tcp --dport 5350 -j ACCEPT
      iptables -D INPUT -p udp --dport 5349 -j ACCEPT
      iptables -D INPUT -p udp --dport 5350 -j ACCEPT
      iptables -D INPUT -p udp --dport 49152:65535 -j ACCEPT
    else
      whiptail --title "Firewall Configuration" --msgbox "Configuring firewall using iptables..." 10 60

      # Allow SSH (port 22)
      if whiptail --title "SSH Access" --yesno "Should SSH (port 22) be accessible from anywhere?" 10 60; then
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
      else
        SSH_IP=$(whiptail --title "SSH Access" --inputbox "Enter the IP address to allow SSH access:" 10 60 3>&1 1>&2 2>&3)
        if [ -n "$SSH_IP" ]; then
          iptables -A INPUT -p tcp -s "$SSH_IP" --dport 22 -j ACCEPT
        else
          whiptail --title "Error" --msgbox "No IP address provided. SSH access will remain unchanged." 10 60
        fi
      fi

      # Allow Snikket ports
      iptables -A INPUT -p tcp --dport 80 -j ACCEPT
      iptables -A INPUT -p tcp --dport 443 -j ACCEPT
      iptables -A INPUT -p tcp --dport 5222 -j ACCEPT
      iptables -A INPUT -p tcp --dport 5269 -j ACCEPT
      iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
      iptables -A INPUT -p tcp --dport 3478 -j ACCEPT
      iptables -A INPUT -p tcp --dport 3479 -j ACCEPT
      iptables -A INPUT -p udp --dport 3478 -j ACCEPT
      iptables -A INPUT -p udp --dport 3479 -j ACCEPT
      iptables -A INPUT -p tcp --dport 5349 -j ACCEPT
      iptables -A INPUT -p tcp --dport 5350 -j ACCEPT
      iptables -A INPUT -p udp --dport 5349 -j ACCEPT
      iptables -A INPUT -p udp --dport 5350 -j ACCEPT
      iptables -A INPUT -p udp --dport 49152:65535 -j ACCEPT

      # Save iptables rules
      if command -v iptables-save &> /dev/null; then
        apt install iptables-persistent
      fi
    fi

    whiptail --title "Firewall Configuration" --msgbox "Firewall configuration completed successfully!" 10 60

  else
    whiptail --title "Error" --msgbox "No supported firewall tool (UFW or iptables) found. Firewall configuration skipped." 10 60
  fi
}

# Main menu
main_menu() {
  while true; do
    CHOICE=$(whiptail --title "Main Menu" --menu "Choose an option:" 15 60 5 \
      "1" "Install Snikket XMPP Server" \
      "2" "Generate Registration Link" \
      "3" "Uninstall Snikket" \
      "4" "Configure Firewall" \
      "5" "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
      1)
        # Ask for the domain
        DOMAIN=$(whiptail --title "Snikket Setup" --inputbox "Please enter the domain you will use for Snikket (e.g., example.com):" 10 60 3>&1 1>&2 2>&3)

        if [ -z "$DOMAIN" ]; then
          whiptail --title "Error" --msgbox "You must provide a valid domain." 10 60
          continue
        fi

        # Check DNS records
        if ! check_dns "$DOMAIN"; then
          continue
        fi

        # Ask for the admin email
        ADMIN_EMAIL=$(whiptail --title "Admin Email" --inputbox "Please enter the admin email address (required for Let's Encrypt TLS certificates):" 10 60 3>&1 1>&2 2>&3)

        if [ -z "$ADMIN_EMAIL" ]; then
          whiptail --title "Error" --msgbox "You must provide a valid admin email address." 10 60
          continue
        fi

        # Install Docker
        install_docker

        # Install Docker Compose
        install_docker_compose

        # Install Snikket
        install_snikket "$DOMAIN" "$ADMIN_EMAIL"
        ;;

      2)
        generate_registration_link
        ;;

      3)
        uninstall_snikket
        ;;

      4)
        configure_firewall
        ;;

      5)
        exit 0
        ;;

      *)
        exit 0
        ;;
    esac
  done
}

# Start the main menu
main_menu
