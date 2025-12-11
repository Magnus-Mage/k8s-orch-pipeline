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

# Use existing network
data "openstack_networking_network_v2" "existing_network" {
  network_id = var.network_id
}

# Use existing security groups
data "openstack_networking_secgroup_v2" "default_sg" {
  secgroup_id = var.default_security_group_id
}

data "openstack_networking_secgroup_v2" "office_ssh_sg" {
  secgroup_id = var.office_ssh_security_group_id
}

# GPU VMs Group
resource "openstack_networking_port_v2" "gpu_vm_port" {
  count          = var.gpu_vm_count
  name           = "${var.cluster_name}-gpu-vm-${count.index + 1}-port"
  network_id     = data.openstack_networking_network_v2.existing_network.id
  admin_state_up = true
  security_group_ids = [
    data.openstack_networking_secgroup_v2.default_sg.id,
    data.openstack_networking_secgroup_v2.office_ssh_sg.id,
  ]
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
  network_id     = data.openstack_networking_network_v2.existing_network.id
  admin_state_up = true
  security_group_ids = [
    data.openstack_networking_secgroup_v2.default_sg.id,
    data.openstack_networking_secgroup_v2.office_ssh_sg.id,
  ]
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
  network_id     = data.openstack_networking_network_v2.existing_network.id
  admin_state_up = true
  security_group_ids = [
    data.openstack_networking_secgroup_v2.default_sg.id,
    data.openstack_networking_secgroup_v2.office_ssh_sg.id,
  ]
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
  network_id     = data.openstack_networking_network_v2.existing_network.id
  admin_state_up = true
  security_group_ids = [
    data.openstack_networking_secgroup_v2.default_sg.id,
    data.openstack_networking_secgroup_v2.office_ssh_sg.id,
  ]
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
resource "openstack_networking_port_v2" "bastion_port" {
  count          = var.create_bastion ? 1 : 0
  name           = "${var.cluster_name}-bastion-port"
  network_id     = data.openstack_networking_network_v2.existing_network.id
  admin_state_up = true
  security_group_ids = [
    data.openstack_networking_secgroup_v2.default_sg.id,
    data.openstack_networking_secgroup_v2.office_ssh_sg.id,
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
    port = openstack_networking_port_v2.bastion_port[0].id
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
