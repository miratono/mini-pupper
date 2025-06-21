#!/bin/bash

# Exit on any error
set -e

# Get current username
CURRENT_USER=$(whoami)

echo "Starting Mini Pupper setup..."

# 1. Update netplan configuration for wlan0
echo "Updating netplan configuration..."
sudo sed -i '/wlan0:/,/^[^ ]/ s/optional: true/optional: false/' /etc/netplan/50-cloud-init.yaml

# 2. Install required packages
echo "Installing required packages..."
sudo apt update
sudo apt install -y python3-pip default-jre zip acl ca-certificates curl

# 3. Install Jupyter
echo "Installing Jupyter..."
pip install jupyterlab notebook

# 4-5. Configure UFW
echo "Configuring UFW..."
sudo ufw default ALLOW
echo "y" | sudo ufw enable

# 8. Generate and configure Jupyter
echo "Configuring Jupyter..."
jupyter notebook --generate-config

cat > ~/.jupyter/jupyter_notebook_config.py << EOF
c = get_config()
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.token = ''
c.NotebookApp.allow_origin = '*'
c.NotebookApp.disable_check_xsrf = True
c.NotebookApp.open_browser = False
EOF

# 10. Create Jupyter service
echo "Creating Jupyter service..."
sudo bash -c "cat > /etc/systemd/system/jupyter.service << EOF
[Unit]
Description=Jupyter

[Service]
ExecStart=/home/${CURRENT_USER}/.local/bin/jupyter notebook
User=${CURRENT_USER}

[Install]
WantedBy=default.target
EOF"

# 11-12. Enable Jupyter service (will start after reboot)
sudo systemctl enable jupyter.service

# 14. Update sudoers
echo "Updating sudoers..."
echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo

# 15. Remove old Docker versions
echo "Removing old Docker versions..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg 2>/dev/null || true
done

# 16. Install Docker prerequisites and add GPG key
echo "Installing Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

# 17-18. Install Docker packages
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

# 19-20. Setup Docker group and permissions
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker ${CURRENT_USER}

# Install BSP
echo "Installing Mini Pupper BSP..."
cd ~
git clone https://github.com/mangdangroboticsclub/mini_pupper_bsp.git
cd mini_pupper_bsp
./install.sh

echo "Setup complete. System will reboot in 5 seconds..."
sleep 5
sudo reboot
