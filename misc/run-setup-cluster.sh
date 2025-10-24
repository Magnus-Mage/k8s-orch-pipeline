#!/bin/bash

set -e  # Exit immediately on error

echo "🚀 Starting cluster setup..."

# Step 1: Go to the terraform directory
cd "$(dirname "$0")/../terraform"

echo "🔧 Running Terraform..."
terraform init -input=false
terraform apply -auto-approve

echo "📦 Extracting Terraform outputs to JSON..."
terraform output -json > inventory.json

echo "📄 Generating Ansible inventory..."
python3 generate_inventory.py

# Step 2: Run the proxy setup playbook using generated inventory
echo "🛠️ Running Ansible playbook to setup proxy..."
cd ../ansible
ansible-playbook -i inventory.ini playbooks/setup_proxy.yml --private-key /home/ubuntu/.ssh/user-key -u ubuntu -vvv
echo "✅ Cluster bootstrap complete!"

