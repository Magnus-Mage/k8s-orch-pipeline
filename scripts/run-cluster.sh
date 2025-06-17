#!/bin/bash
set -e
cd /home/ubuntu/ansible || exit 1

ansible-playbook -i inventory.ini playbooks/install.yml --private-key /home/ubuntu/.ssh/user-key -u ubuntu -vvv
ansible-playbook -i inventory.ini playbooks/init-control-plane.yml --private-key /home/ubuntu/.ssh/user-key -u ubuntu -vvv
ansible-playbook -i inventory.ini playbooks/join-workers.yml --private-key /home/ubuntu/.ssh/user-key -u ubuntu -vvv
ansible-playbook -i inventory.ini playbooks/post-install.yml --private-key /home/ubuntu/.ssh/user-key -u ubuntu -vvv

