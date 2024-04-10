terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "~> 1.48"
    }
  }
}

provider openstack {
}

variable "cluster_id" {
  type = string
  description = "Pet name for previously created CitC instance to use resources from"
  nullable = false
}

variable "public_key" {
  type = string
  description = "SSH public key to be injected into instance by cloud-init"
  nullable = false
  sensitive = false
}

variable "mgmt_flavor" {
  default = "m1.medium"
  type = string
  nullable = false
  sensitive = false
}

data "template_file" "user_data" {
  template = file("bootstrap.sh.tpl")
}

data "openstack_images_image_v2" "rocky_8" {
  name = "Rocky-8.8"
  most_recent = true
}

resource "openstack_compute_keypair_v2" "citc_admin" {
  name       = "citc-admin-${var.cluster_id}_tf_test"
  public_key = var.public_key
}

resource "openstack_compute_instance_v2" "mgmt_tf_test" {
  name = "mgmt_tf_test"
  flavor_name = var.mgmt_flavor
  security_groups = [
    "external-${var.cluster_id}",
    "cluster-${var.cluster_id}",
  ]
  key_pair = openstack_compute_keypair_v2.citc_admin.name

  user_data = base64encode(data.template_file.user_data.rendered)

  metadata = {
    "cluster" = var.cluster_id
  }
  tags = ["mgmt"]

  block_device {
    uuid = data.openstack_images_image_v2.rocky_8.id
    source_type = "image"
    volume_size = 40
    boot_index = 0
    destination_type = "volume"
    delete_on_termination = true
  }

  network {
    name = "network-${var.cluster_id}"
  }

  network {
    name = "external-ceph"
  }
}

resource "openstack_compute_floatingip_v2" "mgmt_tf_test" {
  pool = "external"
}

resource "openstack_compute_floatingip_associate_v2" "mgmt_tf_test" {
  floating_ip = openstack_compute_floatingip_v2.mgmt_tf_test.address
  instance_id = openstack_compute_instance_v2.mgmt_tf_test.id
}

output "ip" {
 value = openstack_compute_floatingip_v2.mgmt_tf_test.address
}
