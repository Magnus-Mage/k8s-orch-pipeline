#!/bin/bash

cd terraform
terraform init
terraform apply -auto-approve

cd ../ansible
ansible-playbook playbooks/install.yml
ansible-playbook playbooks/init-control-plane.yml
ansible-playbook playbooks/join-workers.yml
ansible-playbook playbooks/post-install.yml
