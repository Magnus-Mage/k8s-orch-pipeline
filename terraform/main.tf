provider "openstack" {
  auth_url         = var.auth_url
  user_name        = var.user_name
  password         = var.password
  region           = var.region
  user_domain_name = "Default"
}

# SSH Key Pair
resource "openstack_compute_keypair_v2" "user_key" {
  name       = var.keypair_name
  public_key = file(var.public_key_path)
}

# Network Resources
data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

resource "openstack_networking_router_v2" "router" {
  name                = "${var.cluster_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_network_v2" "cluster_network" {
  name = "${var.cluster_name}-network"
}

resource "openstack_networking_subnet_v2" "cluster_subnet" {
  name            = "${var.cluster_name}-subnet"
  network_id      = openstack_networking_network_v2.cluster_network.id
  cidr            = var.subnet_cidr
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.cluster_subnet.id
}

# Security Group
resource "openstack_compute_secgroup_v2" "cluster_sg" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for cluster VMs"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }

  # Allow all internal traffic
  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "tcp"
    cidr        = var.subnet_cidr
  }

  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "udp"
    cidr        = var.subnet_cidr
  }
}

# GPU VMs Group
resource "openstack_networking_port_v2" "gpu_vm_port" {
  count          = var.gpu_vm_count
  name           = "${var.cluster_name}-gpu-vm-${count.index + 1}-port"
  network_id     = openstack_networking_network_v2.cluster_network.id
  admin_state_up = true
  security_group_ids = [
    openstack_compute_secgroup_v2.cluster_sg.id,
  ]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.cluster_subnet.id
  }
}

resource "openstack_compute_instance_v2" "gpu_vm" {
  count       = var.gpu_vm_count
  name        = "${var.cluster_name}-gpu-vm-${count.index + 1}"
  image_name  = var.image
  flavor_name = var.gpu_flavor
  key_pair    = openstack_compute_keypair_v2.user_key.name
  user_data   = var.gpu_script_path != "" ? file(var.gpu_script_path) : null

  network {
    port = openstack_networking_port_v2.gpu_vm_port[count.index].id
  }

  block_device {
    volume_size           = var.gpu_volume_size
    destination_type      = "volume"
    delete_on_termination = true
    source_type           = "image"
    boot_index            = 0
    uuid                  = var.image_uuid
  }

  metadata = {
    group = "gpu"
    index = count.index + 1
  }
}

# Stress Test Group 1
resource "openstack_networking_port_v2" "stress_group1_port" {
  count          = var.stress_group1_count
  name           = "${var.cluster_name}-stress-g1-${count.index + 1}-port"
  network_id     = openstack_networking_network_v2.cluster_network.id
  admin_state_up = true
  security_group_ids = [
    openstack_compute_secgroup_v2.cluster_sg.id,
  ]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.cluster_subnet.id
  }
}

resource "openstack_compute_instance_v2" "stress_group1" {
  count       = var.stress_group1_count
  name        = "${var.cluster_name}-stress-g1-${count.index + 1}"
  image_name  = var.image
  flavor_name = var.stress_group1_flavor
  key_pair    = openstack_compute_keypair_v2.user_key.name
  user_data   = var.stress_group1_script_path != "" ? file(var.stress_group1_script_path) : null

  network {
    port = openstack_networking_port_v2.stress_group1_port[count.index].id
  }

  block_device {
    volume_size           = var.stress_group1_volume_size
    destination_type      = "volume"
    delete_on_termination = true
    source_type           = "image"
    boot_index            = 0
    uuid                  = var.image_uuid
  }

  metadata = {
    group = "stress-group1"
    index = count.index + 1
  }
}

# Stress Test Group 2
resource "openstack_networking_port_v2" "stress_group2_port" {
  count          = var.stress_group2_count
  name           = "${var.cluster_name}-stress-g2-${count.index + 1}-port"
  network_id     = openstack_networking_network_v2.cluster_network.id
  admin_state_up = true
  security_group_ids = [
    openstack_compute_secgroup_v2.cluster_sg.id,
  ]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.cluster_subnet.id
  }
}

resource "openstack_compute_instance_v2" "stress_group2" {
  count       = var.stress_group2_count
  name        = "${var.cluster_name}-stress-g2-${count.index + 1}"
  image_name  = var.image
  flavor_name = var.stress_group2_flavor
  key_pair    = openstack_compute_keypair_v2.user_key.name
  user_data   = var.stress_group2_script_path != "" ? file(var.stress_group2_script_path) : null

  network {
    port = openstack_networking_port_v2.stress_group2_port[count.index].id
  }

  block_device {
    volume_size           = var.stress_group2_volume_size
    destination_type      = "volume"
    delete_on_termination = true
    source_type           = "image"
    boot_index            = 0
    uuid                  = var.image_uuid
  }

  metadata = {
    group = "stress-group2"
    index = count.index + 1
  }
}

# Stress Test Group 3
resource "openstack_networking_port_v2" "stress_group3_port" {
  count          = var.stress_group3_count
  name           = "${var.cluster_name}-stress-g3-${count.index + 1}-port"
  network_id     = openstack_networking_network_v2.cluster_network.id
  admin_state_up = true
  security_group_ids = [
    openstack_compute_secgroup_v2.cluster_sg.id,
  ]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.cluster_subnet.id
  }
}

resource "openstack_compute_instance_v2" "stress_group3" {
  count       = var.stress_group3_count
  name        = "${var.cluster_name}-stress-g3-${count.index + 1}"
  image_name  = var.image
  flavor_name = var.stress_group3_flavor
  key_pair    = openstack_compute_keypair_v2.user_key.name
  user_data   = var.stress_group3_script_path != "" ? file(var.stress_group3_script_path) : null

  network {
    port = openstack_networking_port_v2.stress_group3_port[count.index].id
  }

  block_device {
    volume_size           = var.stress_group3_volume_size
    destination_type      = "volume"
    delete_on_termination = true
    source_type           = "image"
    boot_index            = 0
    uuid                  = var.image_uuid
  }

  metadata = {
    group = "stress-group3"
    index = count.index + 1
  }
}

# Optional Bastion/Proxy VM for external access
resource "openstack_networking_port_v2" "bastion_internal_port" {
  count          = var.create_bastion ? 1 : 0
  name           = "${var.cluster_name}-bastion-internal-port"
  network_id     = openstack_networking_network_v2.cluster_network.id
  admin_state_up = true
  security_group_ids = [
    openstack_compute_secgroup_v2.cluster_sg.id,
  ]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.cluster_subnet.id
  }
}

resource "openstack_networking_port_v2" "bastion_external_port" {
  count          = var.create_bastion ? 1 : 0
  name           = "${var.cluster_name}-bastion-external-port"
  network_id     = data.openstack_networking_network_v2.external.id
  admin_state_up = true
  security_group_ids = [
    openstack_compute_secgroup_v2.cluster_sg.id,
  ]
}

resource "openstack_compute_instance_v2" "bastion" {
  count       = var.create_bastion ? 1 : 0
  name        = "${var.cluster_name}-bastion"
  image_name  = var.image
  flavor_name = var.bastion_flavor
  key_pair    = openstack_compute_keypair_v2.user_key.name
  user_data   = var.bastion_script_path != "" ? file(var.bastion_script_path) : null

  network {
    port = openstack_networking_port_v2.bastion_internal_port[0].id
  }

  network {
    port = openstack_networking_port_v2.bastion_external_port[0].id
  }

  block_device {
    volume_size           = var.bastion_volume_size
    destination_type      = "volume"
    delete_on_termination = true
    source_type           = "image"
    boot_index            = 0
    uuid                  = var.image_uuid
  }

  metadata = {
    group = "bastion"
  }
}
