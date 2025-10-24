# GPU VM Outputs
output "gpu_vm_ips" {
  description = "Internal IP addresses of GPU VMs"
  value       = openstack_networking_port_v2.gpu_vm_port[*].all_fixed_ips[0]
}

output "gpu_vm_names" {
  description = "Names of GPU VMs"
  value       = openstack_compute_instance_v2.gpu_vm[*].name
}

# Stress Group 1 Outputs
output "stress_group1_ips" {
  description = "Internal IP addresses of stress test group 1 VMs"
  value       = openstack_networking_port_v2.stress_group1_port[*].all_fixed_ips[0]
}

output "stress_group1_names" {
  description = "Names of stress test group 1 VMs"
  value       = openstack_compute_instance_v2.stress_group1[*].name
}

# Stress Group 2 Outputs
output "stress_group2_ips" {
  description = "Internal IP addresses of stress test group 2 VMs"
  value       = openstack_networking_port_v2.stress_group2_port[*].all_fixed_ips[0]
}

output "stress_group2_names" {
  description = "Names of stress test group 2 VMs"
  value       = openstack_compute_instance_v2.stress_group2[*].name
}

# Stress Group 3 Outputs
output "stress_group3_ips" {
  description = "Internal IP addresses of stress test group 3 VMs"
  value       = openstack_networking_port_v2.stress_group3_port[*].all_fixed_ips[0]
}

output "stress_group3_names" {
  description = "Names of stress test group 3 VMs"
  value       = openstack_compute_instance_v2.stress_group3[*].name
}

# Bastion Outputs
output "bastion_internal_ip" {
  description = "Internal IP address of bastion host"
  value       = var.create_bastion ? openstack_networking_port_v2.bastion_internal_port[0].all_fixed_ips[0] : null
}

output "bastion_external_ip" {
  description = "External IP address of bastion host"
  value       = var.create_bastion ? openstack_networking_port_v2.bastion_external_port[0].all_fixed_ips[0] : null
}

# Network Outputs
output "cluster_network_id" {
  description = "ID of the cluster network"
  value       = openstack_networking_network_v2.cluster_network.id
}

output "cluster_subnet_id" {
  description = "ID of the cluster subnet"
  value       = openstack_networking_subnet_v2.cluster_subnet.id
}

# Summary Output
output "cluster_summary" {
  description = "Summary of all cluster resources"
  value = {
    cluster_name    = var.cluster_name
    gpu_vm_count    = var.gpu_vm_count
    stress_group1   = var.stress_group1_count
    stress_group2   = var.stress_group2_count
    stress_group3   = var.stress_group3_count
    total_vms       = var.gpu_vm_count + var.stress_group1_count + var.stress_group2_count + var.stress_group3_count + (var.create_bastion ? 1 : 0)
    bastion_enabled = var.create_bastion
  }
}
