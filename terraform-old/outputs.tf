output "master_ips" {
  value = openstack_networking_port_v2.control_plane[*].all_fixed_ips[0]
}

output "worker_ips" {
  value = openstack_networking_port_v2.worker[*].all_fixed_ips[0]
}

output "proxy_internal_ip" {
  value = openstack_networking_port_v2.proxy_internal.all_fixed_ips[0]
}

output "proxy_external_ip" {
  value = openstack_networking_port_v2.proxy_external.all_fixed_ips[0]
}

