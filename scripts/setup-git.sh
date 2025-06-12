#!/bin/bash

# Exit if any command fails
set -e

echo "🔧 Updating and installing build tools + Git..."
sudo apt update
sudo apt install -y build-essential git

echo "✅ Installed build-essential and git"

# Ask for Git user info
read -p "Enter your GitHub name: " git_name
read -p "Enter your GitHub email: " git_email

echo "🔧 Setting Git global config..."
git config --global user.name "$git_name"
git config --global user.email "$git_email"

# Ask for key name
read -p "Enter SSH key filename (e.g. id_ed25519): " key_name
key_path="$HOME/.ssh/$key_name"

echo "🔐 Generating SSH key at $key_path..."
ssh-keygen -t ed25519 -C "$git_email" -f "$key_path" -N ""

echo "🔐 Adding key to SSH agent..."
eval "$(ssh-agent -s)"
ssh-add "$key_path"

echo "✅ SSH key generated and added to agent."

echo "📋 Your public key (copy this to GitHub SSH settings):"
echo "------------------------------------------------------"
cat "${key_path}.pub"
echo "------------------------------------------------------"

echo "🧪 Testing SSH connection (you'll see a success message if it works)..."
echo "❗ Make sure you've added your public key to https://github.com/settings/keys"
read -p "Press ENTER when you're ready to test..."

ssh -T git@github.com

echo "✅ Setup complete!"
