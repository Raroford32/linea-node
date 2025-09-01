#!/bin/bash
set -e

echo "Starting Linea Besu (Basic Profile) installation..."

# Install dependencies
echo "Installing required packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq > /dev/null
sudo apt-get install -y -qq curl > /dev/null

# Install Docker
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh > /dev/null
    rm get-docker.sh
fi

# Configure Docker permissions
echo "Configuring Docker permissions..."
sudo usermod -aG docker $USER

# Download and configure Linea node
echo "Downloading and configuring Linea node..."
mkdir -p ~/linea-node
cd ~/linea-node
wget -q https://raw.githubusercontent.com/Consensys/linea-monorepo/main/linea-besu-package/docker/docker-compose-basic-mainnet.yaml -O docker-compose.yaml

PUBLIC_IP=$(curl -s ifconfig.me)
sed -i "s/--p2p-host=.*/--p2p-host=${PUBLIC_IP}/" docker-compose.yaml

# Start the node
echo "Starting the Linea node..."
sudo docker compose -f docker-compose.yaml up -d

# Final message
echo ""
echo "Linea (Basic) node installation complete."
echo "Important: To use Docker without 'sudo', you must log out and log back in."
echo ""
echo "To check the logs, run: cd ~/linea-node && sudo docker compose logs -f"
