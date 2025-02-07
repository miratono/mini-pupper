#!/bin/bash

# Exit on any error
set -e

# Get current username
CURRENT_USER=$(whoami)

# 1. Update netplan configuration for wlan0
sudo sed -i '/wlan0:/,/^[^ ]/ s/optional: true/optional: false/' /etc/netplan/50-cloud-init.yaml

# 2. Install required packages
sudo apt update
sudo apt install -y python3-pip default-jre zip
sudo apt-get install -y acl

# 3. Install Jupyter
pip install jupyterlab notebook

# 4-5. Configure UFW
sudo ufw default ALLOW
echo "y" | sudo ufw enable

# Create second phase script
cat > ~/post_setup.sh << 'EOL'
#!/bin/bash

CURRENT_USER=$(whoami)

# 8. Generate Jupyter config
jupyter notebook --generate-config

# 9. Configure Jupyter
cat > ~/.jupyter/jupyter_notebook_config.py << EOF
c = get_config()
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.token = ''
c.NotebookApp.allow_origin = '*'
c.NotebookApp.disable_check_xsrf = True
c.NotebookApp.open_browser = False
EOF

# 10. Create Jupyter service
sudo bash -c "cat > /etc/systemd/system/jupyter.service << EOF
[Unit]
Description=Jupyter

[Service]
ExecStart=/home/${CURRENT_USER}/.local/bin/jupyter notebook
User=${CURRENT_USER}

[Install]
WantedBy=default.target
EOF"

# 11-12. Enable and start Jupyter service
sudo systemctl enable jupyter.service
sudo systemctl start jupyter.service

# Create final phase script
cat > ~/final_setup.sh << 'EOF'
#!/bin/bash

CURRENT_USER=$(whoami)

# 14. Update sudoers
echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo

# 15. Remove old Docker versions
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg
done

# 16. Install Docker prerequisites and add GPG key
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

# 17. Install Docker packages
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 18. Install Docker Compose
sudo apt install -y docker-compose

# 19-20. Setup Docker group and permissions
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker ${CURRENT_USER}

# 21. Apply new group membership
newgrp docker

# Remove startup scripts
crontab -r

# 22. Final reboot
echo "Installation complete. System will reboot in 5 seconds..."
sleep 5
sudo reboot
EOF

chmod +x ~/final_setup.sh

# Schedule the final setup script
echo "@reboot sleep 30 && ~/final_setup.sh" | crontab -

# 13. Reboot system
echo "First phase complete. System will reboot in 5 seconds..."
sleep 5
sudo reboot
EOL

# Make post-setup script executable
chmod +x ~/post_setup.sh

# Schedule the post-setup script
echo "@reboot sleep 30 && ~/post_setup.sh" | crontab -

# 6. Initial reboot
echo "Initial setup complete. System will reboot in 5 seconds..."
sleep 5
sudo reboot
