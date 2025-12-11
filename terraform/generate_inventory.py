#!/usr/bin/env python3
"""
Generate Ansible inventory from Terraform outputs
"""
import json
import os
import sys

def load_terraform_output():
    """Load Terraform output from JSON file"""
    try:
        with open("inventory.json") as f:
            return json.load(f)
    except FileNotFoundError:
        print("❌ Error: inventory.json not found. Run 'terraform output -json > inventory.json' first.")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Error: Invalid JSON in inventory.json: {e}")
        sys.exit(1)

def get_value(data, key):
    """Safely extract value from Terraform output"""
    return data.get(key, {}).get("value")

def backup_file(filepath):
    """Backup existing file if it exists"""
    if os.path.exists(filepath):
        backup = filepath + ".bak"
        os.rename(filepath, backup)
        print(f"🔁 Backed up existing file to: {backup}")

def main():
    # Load Terraform outputs
    data = load_terraform_output()
    
    # Extract all outputs
    gpu_vm_ips = get_value(data, "gpu_vm_ips") or []
    gpu_vm_names = get_value(data, "gpu_vm_names") or []
    
    stress_group1_ips = get_value(data, "stress_group1_ips") or []
    stress_group1_names = get_value(data, "stress_group1_names") or []
    
    stress_group2_ips = get_value(data, "stress_group2_ips") or []
    stress_group2_names = get_value(data, "stress_group2_names") or []
    
    stress_group3_ips = get_value(data, "stress_group3_ips") or []
    stress_group3_names = get_value(data, "stress_group3_names") or []
    
    bastion_internal_ip = get_value(data, "bastion_internal_ip")
    bastion_external_ip = get_value(data, "bastion_external_ip")
    bastion_ip = get_value(data, "bastion_ip")
    
    cluster_summary = get_value(data, "cluster_summary") or {}
    
    # Validation
    if not any([gpu_vm_ips, stress_group1_ips, stress_group2_ips, stress_group3_ips]):
        print("❌ No VMs found in Terraform output. Exiting.")
        sys.exit(1)
    
    # Setup output
    output_dir = "../ansible"
    output_file = os.path.join(output_dir, "inventory.ini")
    
    os.makedirs(output_dir, exist_ok=True)
    backup_file(output_file)
    
    # Generate inventory
    with open(output_file, "w") as f:
        # GPU VMs
        if gpu_vm_ips:
            f.write("[gpu_vms]\n")
            for i, ip in enumerate(gpu_vm_ips):
                name = gpu_vm_names[i] if i < len(gpu_vm_names) else f"gpu-vm-{i+1}"
                f.write(f"{name} ansible_host={ip}\n")
            f.write("\n")
        
        # Stress Test Group 1
        if stress_group1_ips:
            f.write("[stress_group1]\n")
            for i, ip in enumerate(stress_group1_ips):
                name = stress_group1_names[i] if i < len(stress_group1_names) else f"stress-g1-{i+1}"
                f.write(f"{name} ansible_host={ip}\n")
            f.write("\n")
        
        # Stress Test Group 2
        if stress_group2_ips:
            f.write("[stress_group2]\n")
            for i, ip in enumerate(stress_group2_ips):
                name = stress_group2_names[i] if i < len(stress_group2_names) else f"stress-g2-{i+1}"
                f.write(f"{name} ansible_host={ip}\n")
            f.write("\n")
        
        # Stress Test Group 3
        if stress_group3_ips:
            f.write("[stress_group3]\n")
            for i, ip in enumerate(stress_group3_ips):
                name = stress_group3_names[i] if i < len(stress_group3_names) else f"stress-g3-{i+1}"
                f.write(f"{name} ansible_host={ip}\n")
            f.write("\n")
        
        # Bastion host
        if bastion_ip:
            f.write("[bastion]\n")
            f.write(f"bastion ansible_host={bastion_ip}\n")
            f.write("\n")
        
        # Group combinations
        f.write("[stress_vms:children]\n")
        if stress_group1_ips:
            f.write("stress_group1\n")
        if stress_group2_ips:
            f.write("stress_group2\n")
        if stress_group3_ips:
            f.write("stress_group3\n")
        f.write("\n")
        
        f.write("[all_cluster:children]\n")
        if gpu_vm_ips:
            f.write("gpu_vms\n")
        f.write("stress_vms\n")
        if bastion_ip:
            f.write("bastion\n")
        f.write("\n")
        
        # Global variables
        f.write("[all:vars]\n")
        f.write("ansible_user=ubuntu\n")
        f.write("ansible_ssh_private_key_file=/home/ubuntu/.ssh/user-key\n")
        f.write("ansible_ssh_common_args='-o StrictHostKeyChecking=no'\n")
    
    # Print summary
    print(f"✅ Inventory generated at: {output_file}")
    print(f"\n📊 Cluster Summary:")
    if cluster_summary:
        print(f"  Cluster Name: {cluster_summary.get('cluster_name', 'N/A')}")
        print(f"  GPU VMs: {cluster_summary.get('gpu_vm_count', 0)}")
        print(f"  Stress Group 1: {cluster_summary.get('stress_group1', 0)}")
        print(f"  Stress Group 2: {cluster_summary.get('stress_group2', 0)}")
        print(f"  Stress Group 3: {cluster_summary.get('stress_group3', 0)}")
        print(f"  Total VMs: {cluster_summary.get('total_vms', 0)}")
        print(f"  Bastion: {'Enabled' if cluster_summary.get('bastion_enabled') else 'Disabled'}")
    
    print(f"\n📋 Groups:")
    if gpu_vm_ips:
        print(f"  [gpu_vms]: {len(gpu_vm_ips)} VMs")
    if stress_group1_ips:
        print(f"  [stress_group1]: {len(stress_group1_ips)} VMs")
    if stress_group2_ips:
        print(f"  [stress_group2]: {len(stress_group2_ips)} VMs")
    if stress_group3_ips:
        print(f"  [stress_group3]: {len(stress_group3_ips)} VMs")
    if bastion_ip:
        print(f"  [bastion]: {bastion_ip}")

if __name__ == "__main__":
    main()
