#!/bin/bash
# update package cache and install Ansible
sudo apt-get update -y
sudo apt-get install -y ansible openssh-client

# Optional: create ssh folder and set permissions
mkdir -p /home/ubuntu/.ssh
chown ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
