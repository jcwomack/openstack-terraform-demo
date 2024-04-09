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

data "openstack_images_image_v2" "rocky_8" {
  name = "Rocky-8.8"
  most_recent = true
}

data "openstack_compute_flavor_v2" "m1_medium" {
  name = "m1.medium"
}

resource "openstack_compute_instance_v2" "mgmt_tf_test" {
  name = "mgmt_tf_test"
  flavor_id = data.openstack_compute_flavor_v2.m1_medium.id
  security_groups = [
    "external-${var.cluster_id}",
    "cluster-${var.cluster_id}",
  ]
  key_pair = "citc-admin-${var.cluster_id}"

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
