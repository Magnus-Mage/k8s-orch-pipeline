import json
import os

# Load Terraform output
with open("inventory.json") as f:
    data = json.load(f)

# Safely extract values
master_ips = data.get("master_ips", {}).get("value", [])
worker_ips = data.get("worker_ips", {}).get("value", [])

if not master_ips and not worker_ips:
    print("❌ No IPs found in inventory.json. Exiting.")
    exit(1)

# Set output path
output_dir = "../ansible"
output_file = os.path.join(output_dir, "inventory.ini")

# Make sure the directory exists
os.makedirs(output_dir, exist_ok=True)

# Backup existing file if it exists
if os.path.exists(output_file):
    backup_file = output_file + ".bak"
    os.rename(output_file, backup_file)
    print(f"⚠️ Existing inventory.ini backed up as: {backup_file}")

# Write inventory.ini
with open(output_file, "w") as f:
    f.write("[master_ips]\n")
    for i, ip in enumerate(master_ips, 1):
        f.write(f"master{i} ansible_host={ip}\n")

    f.write("\n[worker_ips]\n")
    for i, ip in enumerate(worker_ips, 1):
        f.write(f"worker{i} ansible_host={ip}\n")

    f.write("\n[all:children]\n")
    f.write("master_ips\n")
    f.write("worker_ips\n")

    f.write("\n[all:vars]\n")
    f.write("ansible_user=ubuntu\n")
    f.write("ansible_ssh_private_key_file=/home/ubuntu/user-key\n")

print(f"✅ inventory.ini generated at: {output_file}")

