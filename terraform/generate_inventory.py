import json
import os

# Load Terraform output from JSON
with open("inventory.json") as f:
    data = json.load(f)

# Extract values safely
master_ips = data.get("master_ips", {}).get("value", [])
worker_ips = data.get("worker_ips", {}).get("value", [])
proxy_ip = data.get("proxy_external_ip", {}).get("value")

if not master_ips and not worker_ips:
    print("❌ No master or worker IPs found. Exiting.")
    exit(1)

if not proxy_ip:
    print("❌ Proxy external IP not found. Exiting.")
    exit(1)

# Set output path
output_dir = "../ansible"
output_file = os.path.join(output_dir, "inventory.ini")

# Ensure the directory exists
os.makedirs(output_dir, exist_ok=True)

# Backup existing file
if os.path.exists(output_file):
    backup_file = output_file + ".bak"
    os.rename(output_file, backup_file)
    print(f"🔁 Existing inventory.ini backed up as: {backup_file}")

# Write the inventory.ini file
with open(output_file, "w") as f:
    f.write("[masters]\n")
    for i, ip in enumerate(master_ips, 1):
        f.write(f"master{i} ansible_host={ip}\n")

    f.write("\n[workers]\n")
    for i, ip in enumerate(worker_ips, 1):
        f.write(f"worker{i} ansible_host={ip}\n")

    f.write("\n[proxy]\n")
    f.write(f"proxy1 ansible_host={proxy_ip}\n")

    f.write("\n[all:vars]\n")
    f.write("ansible_user=ubuntu\n")
    f.write("ansible_ssh_private_key_file=/home/ubuntu/.ssh/user-key\n")

print(f"✅ inventory.ini generated at: {output_file}")

