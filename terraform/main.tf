provider "openstack" {
  auth_url    = var.auth_url
  user_name   = var.user_name
  password    = var.password
  region      = var.region
  user_domain_name = "Default"
}

// data "openstack_images_image_v2" "ubuntu_image" {
//  name        = var.image
//  most_recent = true
// }

resource "openstack_compute_keypair_v2" "user_key" {
  name       = "user-key-new"
  public_key = file("/home/ubuntu/.ssh/user-key.pub")
}

resource "openstack_compute_instance_v2" "control_plane" {
  count       = 3
  name        = "k8s-master-${count.index + 1}"
  image_name  = var.image
  flavor_name = var.flavor_http
  key_pair    = openstack_compute_keypair_v2.user_key.name
  user_data   = file("../scripts/setup-k8s.sh")

  network {
    port = openstack_networking_port_v2.control_plane[count.index].id
  }

  block_device {
    volume_size           = var.volume_http
    destination_type      = "volume"
    delete_on_termination = true
    source_type           = "image"
    boot_index            = 0
    //   uuid                  = data.openstack_images_image_v2.ubuntu_image.id
    uuid = "cfe32483-65b9-4532-9459-ee6904c02e09"
  }
}

resource "openstack_networking_port_v2" "control_plane" {
  count          = 3
  name           = "port-k8s-master-${count.index + 1}"
  network_id     = openstack_networking_network_v2.generic.id
  admin_state_up = true
  security_group_ids = [
    openstack_compute_secgroup_v2.ssh.id,
  ]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.http.id
  }
}

resource "openstack_compute_instance_v2" "worker" {
  count       = var.worker_count
  name        = "k8s-worker-${count.index + 1}"
  image_name  = var.image
  flavor_name = var.flavor_http
  key_pair    = openstack_compute_keypair_v2.user_key.name
  user_data   = file("../scripts/setup-k8s.sh")

  network {
    port = openstack_networking_port_v2.worker[count.index].id
  }

  block_device {
    volume_size           = var.volume_http
    destination_type      = "volume"
    delete_on_termination = true
    source_type           = "image"
    boot_index            = 0
    //  uuid                  = data.openstack_images_image_v2.ubuntu_image.id
    uuid = "cfe32483-65b9-4532-9459-ee6904c02e09"
  }
}

resource "openstack_networking_port_v2" "worker" {
  count          = var.worker_count
  name           = "port-k8s-worker-${count.index + 1}"
  network_id     = openstack_networking_network_v2.generic.id
  admin_state_up = true
  security_group_ids = [
    openstack_compute_secgroup_v2.ssh.id,
  ]
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.http.id
  }
}
resource "openstack_networking_network_v2" "generic" {
  name = "network-generic"
}

resource "openstack_networking_subnet_v2" "http" {
  name            = "subnet-http"
  network_id      = openstack_networking_network_v2.generic.id
  cidr            = "192.168.1.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "openstack_compute_secgroup_v2" "ssh" {
  name        = "ssh"
  description = "Allow SSH"
  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

