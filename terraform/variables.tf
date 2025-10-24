# OpenStack Authentication
variable "auth_url" {
  description = "OpenStack Authentication URL"
  type        = string
}

variable "user_name" {
  description = "OpenStack Username"
  type        = string
}

variable "password" {
  description = "OpenStack Password"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OpenStack Region"
  type        = string
  default     = "RegionOne"
}

# General Configuration
variable "cluster_name" {
  description = "Name prefix for all cluster resources"
  type        = string
  default     = "stress-test-cluster"
}

variable "image" {
  description = "OS Image name"
  type        = string
  default     = "Ubuntu-20.04"
}

variable "image_uuid" {
  description = "OS Image UUID"
  type        = string
  default     = "cfe32483-65b9-4532-9459-ee6904c02e09"
}

# SSH Configuration
variable "keypair_name" {
  description = "Name of the SSH keypair"
  type        = string
  default     = "stress-test-key"
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "/home/ubuntu/.ssh/user-key.pub"
}

# Network Configuration
variable "external_network_name" {
  description = "Name of the external network"
  type        = string
  default     = "External_Net"
}

variable "subnet_cidr" {
  description = "CIDR block for the cluster subnet"
  type        = string
  default     = "192.168.100.0/24"
}

variable "dns_nameservers" {
  description = "DNS nameservers for the subnet"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# GPU VM Group Configuration
variable "gpu_vm_count" {
  description = "Number of GPU VMs to create"
  type        = number
  default     = 2
}

variable "gpu_flavor" {
  description = "Flavor for GPU VMs (e.g., GPU-enabled flavor)"
  type        = string
  default     = "G.8"  # Adjust to your GPU flavor
}

variable "gpu_volume_size" {
  description = "Volume size in GB for GPU VMs"
  type        = number
  default     = 50
}

variable "gpu_script_path" {
  description = "Path to initialization script for GPU VMs"
  type        = string
  default     = "../scripts/script-gpu.sh"
}

# Stress Test Group 1 Configuration
variable "stress_group1_count" {
  description = "Number of VMs in stress test group 1"
  type        = number
  default     = 3
}

variable "stress_group1_flavor" {
  description = "Flavor for stress test group 1"
  type        = string
  default     = "S.4"
}

variable "stress_group1_volume_size" {
  description = "Volume size in GB for stress group 1"
  type        = number
  default     = 20
}

variable "stress_group1_script_path" {
  description = "Path to initialization script for stress group 1"
  type        = string
  default     = "../scripts/script-1.sh"
}

# Stress Test Group 2 Configuration
variable "stress_group2_count" {
  description = "Number of VMs in stress test group 2"
  type        = number
  default     = 3
}

variable "stress_group2_flavor" {
  description = "Flavor for stress test group 2"
  type        = string
  default     = "S.4"
}

variable "stress_group2_volume_size" {
  description = "Volume size in GB for stress group 2"
  type        = number
  default     = 20
}

variable "stress_group2_script_path" {
  description = "Path to initialization script for stress group 2"
  type        = string
  default     = "../scripts/script-2.sh"
}

# Stress Test Group 3 Configuration
variable "stress_group3_count" {
  description = "Number of VMs in stress test group 3"
  type        = number
  default     = 3
}

variable "stress_group3_flavor" {
  description = "Flavor for stress test group 3"
  type        = string
  default     = "S.4"
}

variable "stress_group3_volume_size" {
  description = "Volume size in GB for stress group 3"
  type        = number
  default     = 20
}

variable "stress_group3_script_path" {
  description = "Path to initialization script for stress group 3"
  type        = string
  default     = "../scripts/script-3.sh"
}

# Bastion/Proxy Configuration
variable "create_bastion" {
  description = "Whether to create a bastion host for external access"
  type        = bool
  default     = true
}

variable "bastion_flavor" {
  description = "Flavor for bastion host"
  type        = string
  default     = "S.2"
}

variable "bastion_volume_size" {
  description = "Volume size in GB for bastion host"
  type        = number
  default     = 20
}

variable "bastion_script_path" {
  description = "Path to initialization script for bastion host"
  type        = string
  default     = "../scripts/setup-proxy.sh"
}
