output "master_ips" {
  value = openstack_networking_port_v2.control_plane[*].all_fixed_ips[0]
}

output "worker_ips" {
  value = openstack_networking_port_v2.worker[*].all_fixed_ips[0]
}

