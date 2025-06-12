import json
import os

# Load Terraform output
with open("inventory.json") as f:
    data = json.load(f)

master_ips = data["master_ips"]["value"]
worker_ips = data["worker_ips"]["value"]

# Set output path
output_dir = "../ansible"
output_file = os.path.join(output_dir, "inventory.ini")

# Make sure the directory exists
os.makedirs(output_dir, exist_ok=True)

# Write inventory.ini
with open(output_file, "w") as f:
    f.write("[masters]\n")
    for ip in master_ips:
        f.write(f"{ip}\n")

    f.write("\n[workers]\n")
    for ip in worker_ips:
        f.write(f"{ip}\n")

print(f"✅ inventory.ini generated at: {output_file}")

