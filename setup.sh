#!/bin/bash

# Exit on any error
set -e

# Get current username
CURRENT_USER=$(whoami)

# 1. Update netplan configuration for wlan0
sudo sed -i '/wlan0:/,/^[^ ]/ s/optional: true/optional: false/' /etc/netplan/50-cloud-init.yaml
