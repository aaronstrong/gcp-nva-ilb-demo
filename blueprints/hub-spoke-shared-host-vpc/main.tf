# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Future versions of the script may add modularity if it is needed, though the intent of the script is to be simple and have limited configurability.



provider "google" {
  project = var.project-id
}

data "http" "my_public_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  # The chomp() function removes the trailing newline character from the response body
  cleaned_ip = chomp(data.http.my_public_ip.response_body)
  prj_name   = var.project-id
  shortend   = substr(local.prj_name, 0, length(local.prj_name) - 3)
}

module "project-factory-shared-vpc" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.3"

  name                           = "${local.shortend}-shvpc"
  activate_apis                  = ["compute.googleapis.com", "cloudresourcemanager.googleapis.com"]
  auto_create_network            = false
  random_project_id              = true
  billing_account                = var.billing_account
  enable_shared_vpc_host_project = true
  folder_id                      = var.folder_id

  deletion_policy = "DELETE"
}

module "shared_vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.0"

  project_id                             = module.project-factory-shared-vpc.project_id
  network_name                           = "shared-vpc"
  delete_default_internet_gateway_routes = true
  routing_mode                           = "REGIONAL"

  subnets = [
    {
      subnet_name           = "${var.gcp-region}-sharedvpc-subnet"
      subnet_ip             = "${var.subnet1-sharedvpc-first-three-octets}.0/24"
      subnet_region         = var.gcp-region
      subnet_private_access = true
      description           = "This subnet is shared"
    },

  ]
}


resource "google_compute_network" "vpc-hub1" {
  name                            = "${var.vpc-prefix}hub1"
  auto_create_subnetworks         = false
  mtu                             = 1460
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}


resource "google_compute_subnetwork" "subnet1-vpc-hub1" {
  name          = "${var.subnet1-prefix}${google_compute_network.vpc-hub1.name}"
  ip_cidr_range = "${var.subnet1-vpc-hub1-first-three-octets}${var.last-octet-and-mask}"
  region        = var.gcp-region
  network       = google_compute_network.vpc-hub1.id
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}


resource "google_compute_network" "vpc-hub1-spoke1" {
  name                            = "${google_compute_network.vpc-hub1.name}-spoke1"
  auto_create_subnetworks         = false
  mtu                             = 1460
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}


resource "google_compute_subnetwork" "subnet1-vpc-hub1-spoke1" {
  name          = "${var.subnet1-prefix}${google_compute_network.vpc-hub1-spoke1.name}"
  ip_cidr_range = "${var.spoke-first-octet}${var.spoke-hub1-second-octet}.1${var.last-octet-and-mask}"
  region        = var.gcp-region
  network       = google_compute_network.vpc-hub1-spoke1.id
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}


resource "google_compute_network" "vpc-hub1-spoke2" {
  name                            = "${google_compute_network.vpc-hub1.name}-spoke2"
  auto_create_subnetworks         = false
  mtu                             = 1460
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}


resource "google_compute_subnetwork" "subnet1-vpc-hub1-spoke2" {
  name          = "${var.subnet1-prefix}${google_compute_network.vpc-hub1-spoke2.name}"
  ip_cidr_range = "${var.spoke-first-octet}${var.spoke-hub1-second-octet}.2${var.last-octet-and-mask}"
  region        = var.gcp-region
  network       = google_compute_network.vpc-hub1-spoke2.id
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}


# resource "google_compute_network" "vpc-hub2" {
#   name                            = "${var.vpc-prefix}hub2"
#   auto_create_subnetworks         = false
#   mtu                             = 1460
#   routing_mode                    = "GLOBAL"
#   delete_default_routes_on_create = true
# }


# resource "google_compute_subnetwork" "subnet1-vpc-hub2" {
#   name          = "${var.subnet1-prefix}${google_compute_network.vpc-hub2.name}"
#   ip_cidr_range = "${var.subnet1-vpc-hub2-first-three-octets}${var.last-octet-and-mask}"
#   region        = var.gcp-region
#   network       = google_compute_network.vpc-hub2.id
#   log_config {
#     aggregation_interval = "INTERVAL_5_SEC"
#     flow_sampling        = 1.0
#     metadata             = "INCLUDE_ALL_METADATA"
#   }
# }


# resource "google_compute_network" "vpc-hub2-spoke1" {
#   name                            = "${google_compute_network.vpc-hub2.name}-spoke1"
#   auto_create_subnetworks         = false
#   mtu                             = 1460
#   routing_mode                    = "GLOBAL"
#   delete_default_routes_on_create = true
# }


# resource "google_compute_subnetwork" "subnet1-vpc-hub2-spoke1" {
#   name          = "${var.subnet1-prefix}${google_compute_network.vpc-hub2-spoke1.name}"
#   ip_cidr_range = "${var.spoke-first-octet}${var.spoke-hub2-second-octet}.1${var.last-octet-and-mask}"
#   region        = var.gcp-region
#   network       = google_compute_network.vpc-hub2-spoke1.id
#   log_config {
#     aggregation_interval = "INTERVAL_5_SEC"
#     flow_sampling        = 1.0
#     metadata             = "INCLUDE_ALL_METADATA"
#   }
# }


# resource "google_compute_network" "vpc-hub2-spoke2" {
#   name                            = "${google_compute_network.vpc-hub2.name}-spoke2"
#   auto_create_subnetworks         = false
#   mtu                             = 1460
#   routing_mode                    = "GLOBAL"
#   delete_default_routes_on_create = true
# }


# resource "google_compute_subnetwork" "subnet1-vpc-hub2-spoke2" {
#   name          = "${var.subnet1-prefix}${google_compute_network.vpc-hub2-spoke2.name}"
#   ip_cidr_range = "${var.spoke-first-octet}${var.spoke-hub2-second-octet}.2${var.last-octet-and-mask}"
#   region        = var.gcp-region
#   network       = google_compute_network.vpc-hub2-spoke2.id
#   log_config {
#     aggregation_interval = "INTERVAL_5_SEC"
#     flow_sampling        = 1.0
#     metadata             = "INCLUDE_ALL_METADATA"
#   }
# }


resource "google_compute_network" "vpc-transit" {
  name                            = "${var.vpc-prefix}transit"
  auto_create_subnetworks         = false
  mtu                             = 1460
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}


resource "google_compute_subnetwork" "subnet1-vpc-transit" {
  name          = "${var.subnet1-prefix}${google_compute_network.vpc-transit.name}"
  ip_cidr_range = "${var.subnet1-vpc-transit-first-three-octets}${var.last-octet-and-mask}"
  region        = var.gcp-region
  network       = google_compute_network.vpc-transit.id
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}


resource "google_compute_network" "vpc-untrusted" {
  name                    = "${var.vpc-prefix}untrusted"
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "GLOBAL"
}


resource "google_compute_subnetwork" "subnet1-vpc-untrusted" {
  name          = "${var.subnet1-prefix}${google_compute_network.vpc-untrusted.name}"
  ip_cidr_range = "${var.subnet1-vpc-untrusted-first-three-octets}${var.last-octet-and-mask}"
  region        = var.gcp-region
  network       = google_compute_network.vpc-untrusted.id
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}


resource "google_compute_network" "vpc-management" {
  name                            = "${var.vpc-prefix}management"
  auto_create_subnetworks         = false
  mtu                             = 1460
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}


resource "google_compute_subnetwork" "subnet1-vpc-management" {
  name          = "${var.subnet1-prefix}${google_compute_network.vpc-management.name}"
  ip_cidr_range = "${var.subnet1-vpc-management-first-three-octets}${var.last-octet-and-mask}"
  region        = var.gcp-region
  network       = google_compute_network.vpc-management.id
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}


resource "google_compute_network_peering" "peering-hub1-spoke1" {
  name                 = "peering-hub1-spoke1"
  network              = google_compute_network.vpc-hub1.self_link
  peer_network         = google_compute_network.vpc-hub1-spoke1.self_link
  export_custom_routes = true
  import_custom_routes = true
}


resource "google_compute_network_peering" "peering-spoke1-hub1" {
  name                 = "peering-spoke1-hub1"
  network              = google_compute_network.vpc-hub1-spoke1.self_link
  peer_network         = google_compute_network.vpc-hub1.self_link
  export_custom_routes = true
  import_custom_routes = true
}


resource "google_compute_network_peering" "peering-hub1-spoke2" {
  name                 = "peering-hub1-spoke2"
  network              = google_compute_network.vpc-hub1.self_link
  peer_network         = google_compute_network.vpc-hub1-spoke2.self_link
  export_custom_routes = true
  import_custom_routes = true
}


resource "google_compute_network_peering" "peering-spoke2-hub1" {
  name                 = "peering-spoke2-hub1"
  network              = google_compute_network.vpc-hub1-spoke2.self_link
  peer_network         = google_compute_network.vpc-hub1.self_link
  export_custom_routes = true
  import_custom_routes = true
}


# resource "google_compute_network_peering" "peering-hub2-spoke1" {
#   name                 = "peering-hub2-spoke1"
#   network              = google_compute_network.vpc-hub2.self_link
#   peer_network         = google_compute_network.vpc-hub2-spoke1.self_link
#   export_custom_routes = true
#   import_custom_routes = true
# }


# resource "google_compute_network_peering" "peering-spoke1-hub2" {
#   name                 = "peering-spoke1-hub2"
#   network              = google_compute_network.vpc-hub2-spoke1.self_link
#   peer_network         = google_compute_network.vpc-hub2.self_link
#   export_custom_routes = true
#   import_custom_routes = true
# }


# resource "google_compute_network_peering" "peering-hub2-spoke2" {
#   name                 = "peering-hub2-spoke2"
#   network              = google_compute_network.vpc-hub2.self_link
#   peer_network         = google_compute_network.vpc-hub2-spoke2.self_link
#   export_custom_routes = true
#   import_custom_routes = true
# }


# resource "google_compute_network_peering" "peering-spoke2-hub2" {
#   name                 = "peering-spoke2-hub2"
#   network              = google_compute_network.vpc-hub2-spoke2.self_link
#   peer_network         = google_compute_network.vpc-hub2.self_link
#   export_custom_routes = true
#   import_custom_routes = true
# }


resource "google_compute_network_peering" "peering-transit-management" {
  name                 = "peering-transit-management"
  network              = google_compute_network.vpc-transit.self_link
  peer_network         = google_compute_network.vpc-management.self_link
  export_custom_routes = true
  import_custom_routes = true
}


resource "google_compute_network_peering" "peering-management-transit" {
  name                 = "peering-management-transit"
  network              = google_compute_network.vpc-management.self_link
  peer_network         = google_compute_network.vpc-transit.self_link
  export_custom_routes = true
  import_custom_routes = true
}



resource "google_compute_network_peering" "peering-vpc-hub1-shared-vpc" {
  name                 = "peering-vpc-hub1-shared-vpc"
  network              = google_compute_network.vpc-hub1.self_link
  peer_network         = module.shared_vpc.network_self_link
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "peering-shared-vpc-vpc-hub1" {
  name                 = "peering-shared-vpc-vpc-hub1"
  network              = module.shared_vpc.network_self_link
  peer_network         = google_compute_network.vpc-hub1.self_link
  export_custom_routes = true
  import_custom_routes = true
}


resource "google_compute_instance" "vm-in-hub1-spoke1" {
  name         = "${var.vm-name-prefix}hub1-spoke1"
  machine_type = var.vm-machine-type
  zone         = var.gcp-zone
  tags         = ["test-instance"]
  network_interface {
    network    = google_compute_network.vpc-hub1-spoke1.self_link
    subnetwork = google_compute_subnetwork.subnet1-vpc-hub1-spoke1.self_link
    network_ip = "${var.spoke-first-octet}${var.spoke-hub1-second-octet}.1${var.test-vm-int-address}"
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "label"
      }
    }
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
}


resource "google_compute_instance" "vm-in-hub1-spoke2" {
  name         = "${var.vm-name-prefix}hub1-spoke2"
  machine_type = var.vm-machine-type
  zone         = var.gcp-zone
  tags         = ["test-instance"]
  network_interface {
    network    = google_compute_network.vpc-hub1-spoke2.self_link
    subnetwork = google_compute_subnetwork.subnet1-vpc-hub1-spoke2.self_link
    network_ip = "${var.spoke-first-octet}${var.spoke-hub1-second-octet}.2${var.test-vm-int-address}"
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "label"
      }
    }
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
}


resource "google_compute_instance" "vm-in-hub1" {
  name         = "${var.vm-name-prefix}hub1"
  machine_type = var.vm-machine-type
  zone         = var.gcp-zone
  tags         = ["test-instance"]
  network_interface {
    network    = google_compute_network.vpc-hub1.self_link
    subnetwork = google_compute_subnetwork.subnet1-vpc-hub1.self_link
    network_ip = "${var.subnet1-vpc-hub1-first-three-octets}${var.test-vm-int-address}"
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "label"
      }
    }
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
}

resource "google_compute_instance" "vm-in-shared-vpc" {
  name         = "${var.vm-name-prefix}shared-vpc"
  project      = module.project-factory-shared-vpc.project_id
  machine_type = var.vm-machine-type
  zone         = "us-east1-b"
  tags         = ["test-instance"]
  network_interface {
    network            = module.shared_vpc.network_self_link #google_compute_network.vpc-hub1-spoke1.self_link
    subnetwork         = module.shared_vpc.subnets_ids[0]
    subnetwork_project = module.project-factory-shared-vpc.project_id
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "label"
      }
    }
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
}

# resource "google_compute_instance" "vm-in-hub2-spoke1" {
#   name         = "${var.vm-name-prefix}hub2-spoke1"
#   machine_type = var.vm-machine-type
#   zone         = var.gcp-zone
#   tags         = ["test-instance"]
#   network_interface {
#     network    = google_compute_network.vpc-hub2-spoke1.self_link
#     subnetwork = google_compute_subnetwork.subnet1-vpc-hub2-spoke1.self_link
#     network_ip = "${var.spoke-first-octet}${var.spoke-hub2-second-octet}.1${var.test-vm-int-address}"
#   }
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-11"
#       labels = {
#         my_label = "label"
#       }
#     }
#   }
#   shielded_instance_config {
#     enable_secure_boot = true
#   }
# }


# resource "google_compute_instance" "vm-in-hub2-spoke2" {
#   name         = "${var.vm-name-prefix}hub2-spoke2"
#   machine_type = var.vm-machine-type
#   zone         = var.gcp-zone
#   tags         = ["test-instance"]
#   network_interface {
#     network    = google_compute_network.vpc-hub2-spoke2.self_link
#     subnetwork = google_compute_subnetwork.subnet1-vpc-hub2-spoke2.self_link
#     network_ip = "${var.spoke-first-octet}${var.spoke-hub2-second-octet}.2${var.test-vm-int-address}"
#   }
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-11"
#       labels = {
#         my_label = "label"
#       }
#     }
#   }
#   shielded_instance_config {
#     enable_secure_boot = true
#   }
# }


# resource "google_compute_instance" "vm-in-hub2" {
#   name         = "${var.vm-name-prefix}hub2"
#   machine_type = var.vm-machine-type
#   zone         = var.gcp-zone
#   tags         = ["test-instance"]
#   network_interface {
#     network    = google_compute_network.vpc-hub2.self_link
#     subnetwork = google_compute_subnetwork.subnet1-vpc-hub2.self_link
#     network_ip = "${var.subnet1-vpc-hub2-first-three-octets}${var.test-vm-int-address}"
#   }
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-11"
#       labels = {
#         my_label = "label"
#       }
#     }
#   }
#   shielded_instance_config {
#     enable_secure_boot = true
#   }
# }


resource "google_compute_instance" "vm-in-transit" {
  name         = "${var.vm-name-prefix}transit"
  machine_type = var.vm-machine-type
  zone         = var.gcp-zone
  tags         = ["test-instance"]
  network_interface {
    network    = google_compute_network.vpc-transit.self_link
    subnetwork = google_compute_subnetwork.subnet1-vpc-transit.self_link
    network_ip = "${var.subnet1-vpc-transit-first-three-octets}${var.test-vm-int-address}"
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "label"
      }
    }
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
}


resource "google_compute_instance" "vm-in-untrusted" {
  name         = "${var.vm-name-prefix}untrusted"
  machine_type = var.vm-machine-type
  zone         = var.gcp-zone
  tags         = ["test-instance"]
  network_interface {
    network    = google_compute_network.vpc-untrusted.self_link
    subnetwork = google_compute_subnetwork.subnet1-vpc-untrusted.self_link
    network_ip = "${var.subnet1-vpc-untrusted-first-three-octets}${var.test-vm-int-address}"

    # Add this block to assign a public IP address
    access_config {
      // Leaving this empty assigns a Public Ephemeral IP
    }
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "label"
      }
    }
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
  #metadata_startup_script = file("./installer/install_apache.sh")
}


resource "google_compute_instance" "vm-in-management" {
  name         = "${var.vm-name-prefix}management"
  machine_type = var.vm-machine-type
  zone         = var.gcp-zone
  tags         = ["test-instance"]
  network_interface {
    network    = google_compute_network.vpc-management.self_link
    subnetwork = google_compute_subnetwork.subnet1-vpc-management.self_link
    network_ip = "${var.subnet1-vpc-management-first-three-octets}${var.test-vm-int-address}"
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "label"
      }
    }
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
}


resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub1" {
  name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub1"
  network   = google_compute_network.vpc-hub1.self_link
  direction = "INGRESS"
  priority  = "500"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3389"]
  }
  source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
}


resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub1-spoke1" {
  name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub1-spoke1"
  network   = google_compute_network.vpc-hub1-spoke1.self_link
  direction = "INGRESS"
  priority  = "500"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3389"]
  }
  source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
}


resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub1-spoke2" {
  name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub1-spoke2"
  network   = google_compute_network.vpc-hub1-spoke2.self_link
  direction = "INGRESS"
  priority  = "500"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3389"]
  }
  source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
}


# resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub2" {
#   name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub2"
#   network   = google_compute_network.vpc-hub2.self_link
#   direction = "INGRESS"
#   priority  = "500"
#   allow {
#     protocol = "icmp"
#   }
#   allow {
#     protocol = "tcp"
#     ports    = ["22", "80", "443", "3389"]
#   }
#   source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
# }


# resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub2-spoke1" {
#   name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub2-spoke1"
#   network   = google_compute_network.vpc-hub2-spoke1.self_link
#   direction = "INGRESS"
#   priority  = "500"
#   allow {
#     protocol = "icmp"
#   }
#   allow {
#     protocol = "tcp"
#     ports    = ["22", "80", "443", "3389"]
#   }
#   source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
# }


# resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub2-spoke2" {
#   name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-hub2-spoke2"
#   network   = google_compute_network.vpc-hub2-spoke2.self_link
#   direction = "INGRESS"
#   priority  = "500"
#   allow {
#     protocol = "icmp"
#   }
#   allow {
#     protocol = "tcp"
#     ports    = ["22", "80", "443", "3389"]
#   }
#   source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
# }


resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-transit" {
  name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-transit"
  network   = google_compute_network.vpc-transit.self_link
  direction = "INGRESS"
  priority  = "500"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3389"]
  }
  source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
}


resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-untrusted" {
  name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-untrusted"
  network   = google_compute_network.vpc-untrusted.self_link
  direction = "INGRESS"
  priority  = "500"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3389"]
  }
  source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]), [local.cleaned_ip])
}


resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-private-vpc-management" {
  name      = "allow-ssh-rdp-icmp-http-https-from-private-vpc-management"
  network   = google_compute_network.vpc-management.self_link
  direction = "INGRESS"
  priority  = "500"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3389"]
  }
  source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
}

resource "google_compute_firewall" "allow-ssh-rdp-icmp-http-https-from-shared-vpc" {
  name      = "allow-ssh-rdp-icmp-http-https-from-shared-vpc"
  project   = module.project-factory-shared-vpc.project_id
  network   = module.shared_vpc.network_self_link
  direction = "INGRESS"
  priority  = "500"
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3389"]
  }
  source_ranges = setunion(var.fw-rule-source-ranges, toset([var.health-check-source-ip-range-1, var.health-check-source-ip-range-2]))
}


resource "google_compute_instance" "nva1" {
  name           = "nva1"
  machine_type   = "n1-standard-8"
  zone           = var.gcp-zone
  can_ip_forward = true
  boot_disk {
    initialize_params {
      image = "cisco-public/csr1000v1721r-byol"
      type  = "pd-ssd"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet1-vpc-untrusted.self_link
    network_ip = "${var.subnet1-vpc-untrusted-first-three-octets}${var.nva1-int-address}"
    access_config {
      # ephemeral public IP
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet1-vpc-management.self_link
    network_ip = "${var.subnet1-vpc-management-first-three-octets}${var.nva1-int-address}"
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet1-vpc-transit.self_link
    network_ip = "${var.subnet1-vpc-transit-first-three-octets}${var.nva1-int-address}"
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet1-vpc-hub1.self_link
    network_ip = "${var.subnet1-vpc-hub1-first-three-octets}${var.nva1-int-address}"
  }
  # network_interface {
  #   subnetwork = google_compute_subnetwork.subnet1-vpc-hub2.self_link
  #   network_ip = "${var.subnet1-vpc-hub2-first-three-octets}${var.nva1-int-address}"
  # }
  metadata = {
    # Note: the "1.1.1" in the cidrnetmask function is a placeholder, ie doesn't matter, only the mask matters) 
    startup-script     = <<EOS
Section: IOS configuration
username ${var.admin-name} privilege 15 secret 9 ${var.admin-secret-password}
!
! --- Enable web UI ---
ip http server
ip http secure-server
ip http authentication local
crypto key generate rsa modulus 2048
!
vrf definition ${var.vrf-transit-name}
rd ${var.vrf-transit-route-descriptor}
address-family ipv4
exit-address-family
!
vrf definition ${var.vrf-management-name}
rd ${var.vrf-management-route-descriptor}
address-family ipv4
exit-address-family
!
vrf definition ${var.vrf-hub1-name}
rd ${var.vrf-hub1-route-descriptor}
address-family ipv4
exit-address-family
!
vrf definition ${var.vrf-hub2-name}
rd ${var.vrf-hub2-route-descriptor}
address-family ipv4
exit-address-family
!
interface GigabitEthernet1
description VPC untrusted - no secondary address for LB configured - not needed on GigabitEthernet1 / VM nic0
ip address ${var.subnet1-vpc-untrusted-first-three-octets}${var.nva1-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
ip nat outside
!
interface GigabitEthernet2
description VPC management - no secondary address for ILB and no NAT configured
vrf forwarding ${var.vrf-management-name}
ip address ${var.subnet1-vpc-management-first-three-octets}${var.nva1-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
no shut
!
interface GigabitEthernet3
description transit - no NAT configured
vrf forwarding ${var.vrf-transit-name}
ip address ${var.subnet1-vpc-transit-first-three-octets}${var.nva1-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
ip address ${var.subnet1-vpc-transit-first-three-octets}${var.ilb-forwarding-rule-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")} secondary
no shut
!
interface GigabitEthernet4
description hub 1
vrf forwarding ${var.vrf-hub1-name}
ip address ${var.subnet1-vpc-hub1-first-three-octets}${var.nva1-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
ip address ${var.subnet1-vpc-hub1-first-three-octets}${var.ilb-forwarding-rule-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")} secondary
ip nat inside
no shut
!
interface GigabitEthernet5
description hub 2
vrf forwarding ${var.vrf-hub2-name}
ip address ${var.subnet1-vpc-hub2-first-three-octets}${var.nva1-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
ip address ${var.subnet1-vpc-hub2-first-three-octets}${var.ilb-forwarding-rule-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")} secondary
ip nat inside
no shut
!
### Global Table Routes
ip route 0.0.0.0 0.0.0.0 GigabitEthernet1 ${var.subnet1-vpc-untrusted-first-three-octets}.1
!
# route for all spokes in hub 1 - second octet in address represents the hub where the spokes connect
ip route ${var.spoke-first-octet}${var.spoke-hub1-second-octet}.0.0 255.255.0.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for all spokes in hub 2 - second octet in address represents the hub where the spokes connect
ip route ${var.spoke-first-octet}${var.spoke-hub2-second-octet}.0.0 255.255.0.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# route for transit - needed since transit is in a VRF
ip route ${var.subnet1-vpc-transit-first-three-octets}.0 255.255.255.0 GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# no route added for management since it will only be reachable through management VPC
!
# route for hub 1 - needed since hub 1 is in a VRF
ip route ${var.subnet1-vpc-hub1-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for hub 2 - needed since hub 2 is in a VRF
ip route ${var.subnet1-vpc-hub2-first-three-octets}.0 255.255.255.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
### VRF management routes
# in this script, path to management interfaces is through the transit VPC peering to management VPC, thus no path to management is configured in these Network Virtual Appliances, so routing not added here
!
!
### VRF transit routes
# no default route to global table
!
# route for all spokes in hub 1 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-transit-name} ${var.spoke-first-octet}${var.spoke-hub1-second-octet}.0.0 255.255.0.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for all spokes in hub 2 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-transit-name} ${var.spoke-first-octet}${var.spoke-hub2-second-octet}.0.0 255.255.0.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# no route added for management since it will only be reachable through management VPC
!
# route for hub 1 - needed since hub 1 is in a VRF
ip route vrf ${var.vrf-transit-name} ${var.subnet1-vpc-hub1-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for hub 2 - needed since hub 2 is in a VRF
ip route vrf ${var.vrf-transit-name} ${var.subnet1-vpc-hub2-first-three-octets}.0 255.255.255.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# local VRF route for load balancer health check range 1 return path traffic
ip route vrf ${var.vrf-transit-name} ${cidrhost(var.health-check-source-ip-range-1, 0)} ${cidrnetmask(var.health-check-source-ip-range-1)} GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# local VRF route for load balancer health check range 2 return path traffic
ip route vrf ${var.vrf-transit-name} ${cidrhost(var.health-check-source-ip-range-2, 0)} ${cidrnetmask(var.health-check-source-ip-range-2)} GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# route for shared VPC - needed for on-prem return traffic
ip route vrf ${var.vrf-transit-name} ${var.subnet1-sharedvpc-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
!
### VRF hub 1 routes
# default route to global table
ip route vrf ${var.vrf-hub1-name} 0.0.0.0 0.0.0.0 GigabitEthernet1 ${var.subnet1-vpc-untrusted-first-three-octets}.1 global
!
# route for all spokes in hub 1 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-hub1-name} ${var.spoke-first-octet}${var.spoke-hub1-second-octet}.0.0 255.255.0.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for all spokes in hub 2 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-hub1-name} ${var.spoke-first-octet}${var.spoke-hub2-second-octet}.0.0 255.255.0.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# route for transit - needed since transit is in a VRF
ip route vrf ${var.vrf-hub1-name} ${var.subnet1-vpc-transit-first-three-octets}.0 255.255.255.0 GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# no route added for management since it will only be reachable through management VPC
!
# route for hub 2 - needed since hub 2 is in a VRF
ip route vrf ${var.vrf-hub1-name} ${var.subnet1-vpc-hub2-first-three-octets}.0 255.255.255.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# local VRF route for load balancer health check range 1 return path traffic
ip route vrf ${var.vrf-hub1-name} ${cidrhost(var.health-check-source-ip-range-1, 0)} ${cidrnetmask(var.health-check-source-ip-range-1)} GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# local VRF route for load balancer health check range 2 return path traffic
ip route vrf ${var.vrf-hub1-name} ${cidrhost(var.health-check-source-ip-range-2, 0)} ${cidrnetmask(var.health-check-source-ip-range-2)} GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for Shared VPC (host project) - reachable via hub1 peering
ip route vrf ${var.vrf-hub1-name} ${var.subnet1-sharedvpc-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route to on-prem via HA VPN in transit
ip route vrf ${var.vrf-hub1-name} ${cidrhost(var.remote_subnet[0], 0)} ${cidrnetmask(var.remote_subnet[0])} GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# route to on-prem via Transit
ip route vrf vrf-transit 172.16.6.0 255.255.255.0 GigabitEthernet4 172.16.1.1
!
### VRF hub 2 routes
# default route to global table
ip route vrf ${var.vrf-hub2-name} 0.0.0.0 0.0.0.0 GigabitEthernet1 ${var.subnet1-vpc-untrusted-first-three-octets}.1 global
!
# route for all spokes in hub 1 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-hub2-name} ${var.spoke-first-octet}${var.spoke-hub1-second-octet}.0.0 255.255.0.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for all spokes in hub 2 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-hub2-name} ${var.spoke-first-octet}${var.spoke-hub2-second-octet}.0.0 255.255.0.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# route for transit - needed since transit is in a VRF
ip route vrf ${var.vrf-hub2-name} ${var.subnet1-vpc-transit-first-three-octets}.0 255.255.255.0 GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# no route added for management since it will only be reachable through management VPC
!
# route for hub 1 - needed since hub 1 is in a VRF
ip route vrf ${var.vrf-hub2-name} ${var.subnet1-vpc-hub1-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# local VRF route for load balancer health check range 1 return path traffic
ip route vrf ${var.vrf-hub2-name} ${cidrhost(var.health-check-source-ip-range-1, 0)} ${cidrnetmask(var.health-check-source-ip-range-1)} GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# local VRF route for load balancer health check range 2 return path traffic
ip route vrf ${var.vrf-hub2-name} ${cidrhost(var.health-check-source-ip-range-2, 0)} ${cidrnetmask(var.health-check-source-ip-range-2)} GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
!
ip nat inside source list NAT_ACL interface GigabitEthernet1 vrf ${var.vrf-hub1-name} overload
ip nat inside source list NAT_ACL interface GigabitEthernet1 vrf ${var.vrf-hub2-name} overload
ip access-list standard NAT_ACL
10 permit 10.1.0.0 0.0.255.255
20 permit 10.2.0.0 0.0.255.255
30 permit 172.16.0.0 0.0.255.255
EOS
    serial-port-enable = true
  }
}


resource "google_compute_instance" "nva2" {
  name           = "nva2"
  machine_type   = "n1-standard-8"
  zone           = var.gcp-zone
  can_ip_forward = true
  boot_disk {
    initialize_params {
      image = "cisco-public/csr1000v1721r-byol"
      type  = "pd-ssd"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet1-vpc-untrusted.self_link
    network_ip = "${var.subnet1-vpc-untrusted-first-three-octets}${var.nva2-int-address}"
    access_config {
      # ephemeral public IP
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet1-vpc-management.self_link
    network_ip = "${var.subnet1-vpc-management-first-three-octets}${var.nva2-int-address}"
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet1-vpc-transit.self_link
    network_ip = "${var.subnet1-vpc-transit-first-three-octets}${var.nva2-int-address}"
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet1-vpc-hub1.self_link
    network_ip = "${var.subnet1-vpc-hub1-first-three-octets}${var.nva2-int-address}"
  }
  # network_interface {
  #   subnetwork = google_compute_subnetwork.subnet1-vpc-hub2.self_link
  #   network_ip = "${var.subnet1-vpc-hub2-first-three-octets}${var.nva2-int-address}"
  # }
  metadata = {
    # Note: the "1.1.1" in the cidrnetmask function is a placeholder, ie doesn't matter, only the mask matters) 
    startup-script     = <<EOS
Section: IOS configuration
username ${var.admin-name} privilege 15 secret 9 ${var.admin-secret-password}
!
! --- Enable web UI ---
ip http server
ip http secure-server
ip http authentication local
crypto key generate rsa modulus 2048
!
vrf definition ${var.vrf-transit-name}
rd ${var.vrf-transit-route-descriptor}
address-family ipv4
exit-address-family
!
vrf definition ${var.vrf-management-name}
rd ${var.vrf-management-route-descriptor}
address-family ipv4
exit-address-family
!
vrf definition ${var.vrf-hub1-name}
rd ${var.vrf-hub1-route-descriptor}
address-family ipv4
exit-address-family
!
vrf definition ${var.vrf-hub2-name}
rd ${var.vrf-hub2-route-descriptor}
address-family ipv4
exit-address-family
!
interface GigabitEthernet1
description VPC untrusted - no secondary address for LB configured - not needed on GigabitEthernet1 / VM nic0
ip address ${var.subnet1-vpc-untrusted-first-three-octets}${var.nva2-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
ip nat outside
!
interface GigabitEthernet2
description VPC management - no secondary address for ILB and no NAT configured
vrf forwarding ${var.vrf-management-name}
ip address ${var.subnet1-vpc-management-first-three-octets}${var.nva2-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
no shut
!
interface GigabitEthernet3
description transit - no NAT configured
vrf forwarding ${var.vrf-transit-name}
ip address ${var.subnet1-vpc-transit-first-three-octets}${var.nva2-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
ip address ${var.subnet1-vpc-transit-first-three-octets}${var.ilb-forwarding-rule-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")} secondary
no shut
!
interface GigabitEthernet4
description hub 1
vrf forwarding ${var.vrf-hub1-name}
ip address ${var.subnet1-vpc-hub1-first-three-octets}${var.nva2-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
ip address ${var.subnet1-vpc-hub1-first-three-octets}${var.ilb-forwarding-rule-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")} secondary
ip nat inside
no shut
!
interface GigabitEthernet5
description hub 2
vrf forwarding ${var.vrf-hub2-name}
ip address ${var.subnet1-vpc-hub2-first-three-octets}${var.nva2-int-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")}
ip address ${var.subnet1-vpc-hub2-first-three-octets}${var.ilb-forwarding-rule-address} ${cidrnetmask("1.1.1${var.last-octet-and-mask}")} secondary
ip nat inside
no shut
!
### Global Table Routes
ip route 0.0.0.0 0.0.0.0 GigabitEthernet1 ${var.subnet1-vpc-untrusted-first-three-octets}.1
!
# route for all spokes in hub 1 - second octet in address represents the hub where the spokes connect
ip route ${var.spoke-first-octet}${var.spoke-hub1-second-octet}.0.0 255.255.0.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for all spokes in hub 2 - second octet in address represents the hub where the spokes connect
ip route ${var.spoke-first-octet}${var.spoke-hub2-second-octet}.0.0 255.255.0.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# route for transit - needed since transit is in a VRF
ip route ${var.subnet1-vpc-transit-first-three-octets}.0 255.255.255.0 GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# no route added for management since it will only be reachable through management VPC
!
# route for hub 1 - needed since hub 1 is in a VRF
ip route ${var.subnet1-vpc-hub1-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for hub 2 - needed since hub 2 is in a VRF
ip route ${var.subnet1-vpc-hub2-first-three-octets}.0 255.255.255.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
!
### VRF management routes
# in this script, path to management interfaces is through the transit VPC peering to management VPC, thus no path to management is configured in these Network Virtual Appliances, so routing not added here
!
!
### VRF transit routes
# no default route to global table
!
# route for all spokes in hub 1 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-transit-name} ${var.spoke-first-octet}${var.spoke-hub1-second-octet}.0.0 255.255.0.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for all spokes in hub 2 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-transit-name} ${var.spoke-first-octet}${var.spoke-hub2-second-octet}.0.0 255.255.0.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# no route added for management since it will only be reachable through management VPC
!
# route for hub 1 - needed since hub 1 is in a VRF
ip route vrf ${var.vrf-transit-name} ${var.subnet1-vpc-hub1-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for hub 2 - needed since hub 2 is in a VRF
ip route vrf ${var.vrf-transit-name} ${var.subnet1-vpc-hub2-first-three-octets}.0 255.255.255.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# local VRF route for load balancer health check range 1 return path traffic
ip route vrf ${var.vrf-transit-name} ${cidrhost(var.health-check-source-ip-range-1, 0)} ${cidrnetmask(var.health-check-source-ip-range-1)} GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# local VRF route for load balancer health check range 2 return path traffic
ip route vrf ${var.vrf-transit-name} ${cidrhost(var.health-check-source-ip-range-2, 0)} ${cidrnetmask(var.health-check-source-ip-range-2)} GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# route for shared VPC - needed for on-prem return traffic
ip route vrf ${var.vrf-transit-name} ${var.subnet1-sharedvpc-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
!
### VRF hub 1 routes
# default route to global table
ip route vrf ${var.vrf-hub1-name} 0.0.0.0 0.0.0.0 GigabitEthernet1 ${var.subnet1-vpc-untrusted-first-three-octets}.1 global
!
# route for all spokes in hub 1 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-hub1-name} ${var.spoke-first-octet}${var.spoke-hub1-second-octet}.0.0 255.255.0.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for all spokes in hub 2 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-hub1-name} ${var.spoke-first-octet}${var.spoke-hub2-second-octet}.0.0 255.255.0.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# route for transit - needed since transit is in a VRF
ip route vrf ${var.vrf-hub1-name} ${var.subnet1-vpc-transit-first-three-octets}.0 255.255.255.0 GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# no route added for management since it will only be reachable through management VPC
!
# route for hub 2 - needed since hub 2 is in a VRF
ip route vrf ${var.vrf-hub1-name} ${var.subnet1-vpc-hub2-first-three-octets}.0 255.255.255.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# local VRF route for load balancer health check range 1 return path traffic
ip route vrf ${var.vrf-hub1-name} ${cidrhost(var.health-check-source-ip-range-1, 0)} ${cidrnetmask(var.health-check-source-ip-range-1)} GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# local VRF route for load balancer health check range 2 return path traffic
ip route vrf ${var.vrf-hub1-name} ${cidrhost(var.health-check-source-ip-range-2, 0)} ${cidrnetmask(var.health-check-source-ip-range-2)} GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for Shared VPC (host project) - reachable via hub1 peering
ip route vrf ${var.vrf-hub1-name} ${var.subnet1-sharedvpc-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route to on-prem via HA VPN in transit
ip route vrf ${var.vrf-hub1-name} ${cidrhost(var.remote_subnet[0], 0)} ${cidrnetmask(var.remote_subnet[0])} GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# route to on-prem via Transit
ip route vrf vrf-transit 172.16.6.0 255.255.255.0 GigabitEthernet4 172.16.1.1
!
!
### VRF hub 2 routes
# default route to global table
ip route vrf ${var.vrf-hub2-name} 0.0.0.0 0.0.0.0 GigabitEthernet1 ${var.subnet1-vpc-untrusted-first-three-octets}.1 global
!
# route for all spokes in hub 1 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-hub2-name} ${var.spoke-first-octet}${var.spoke-hub1-second-octet}.0.0 255.255.0.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# route for all spokes in hub 2 - second octet in address represents the hub where the spokes connect
ip route vrf ${var.vrf-hub2-name} ${var.spoke-first-octet}${var.spoke-hub2-second-octet}.0.0 255.255.0.0 GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# route for transit - needed since transit is in a VRF
ip route vrf ${var.vrf-hub2-name} ${var.subnet1-vpc-transit-first-three-octets}.0 255.255.255.0 GigabitEthernet3 ${var.subnet1-vpc-transit-first-three-octets}.1
!
# no route added for management since it will only be reachable through management VPC
!
# route for hub 1 - needed since hub 1 is in a VRF
ip route vrf ${var.vrf-hub2-name} ${var.subnet1-vpc-hub1-first-three-octets}.0 255.255.255.0 GigabitEthernet4 ${var.subnet1-vpc-hub1-first-three-octets}.1
!
# local VRF route for load balancer health check range 1 return path traffic
ip route vrf ${var.vrf-hub2-name} ${cidrhost(var.health-check-source-ip-range-1, 0)} ${cidrnetmask(var.health-check-source-ip-range-1)} GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
# local VRF route for load balancer health check range 2 return path traffic
ip route vrf ${var.vrf-hub2-name} ${cidrhost(var.health-check-source-ip-range-2, 0)} ${cidrnetmask(var.health-check-source-ip-range-2)} GigabitEthernet5 ${var.subnet1-vpc-hub2-first-three-octets}.1
!
!
ip nat inside source list NAT_ACL interface GigabitEthernet1 vrf ${var.vrf-hub1-name} overload
ip nat inside source list NAT_ACL interface GigabitEthernet1 vrf ${var.vrf-hub2-name} overload
ip access-list standard NAT_ACL
10 permit 10.1.0.0 0.0.255.255
20 permit 10.2.0.0 0.0.255.255
30 permit 172.16.0.0 0.0.255.255
EOS
    serial-port-enable = true
  }
}


resource "google_compute_health_check" "hc" {
  name               = var.health-check-name
  check_interval_sec = 1
  timeout_sec        = 1
  tcp_health_check {
    port = "80"
  }
}


resource "google_compute_instance_group" "ig-nvas" {
  name      = var.instance-group-name
  instances = [google_compute_instance.nva1.id, google_compute_instance.nva2.id]
  zone      = var.gcp-zone
}


resource "google_compute_region_backend_service" "ilb-backend-transit" {
  name          = var.ilb-backend-transit-name
  region        = var.gcp-region
  health_checks = [google_compute_health_check.hc.id]
  protocol      = "TCP"
  network       = google_compute_network.vpc-transit.self_link
  backend {
    group          = google_compute_instance_group.ig-nvas.self_link
    balancing_mode = "CONNECTION"
  }
}


resource "google_compute_forwarding_rule" "ilb-forwarding-rule-transit" {
  name                  = var.ilb-forwarding-rule-transit-name
  region                = var.gcp-region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.ilb-backend-transit.id
  all_ports             = true
  ip_address            = "${var.subnet1-vpc-transit-first-three-octets}${var.ilb-forwarding-rule-address}"
  network               = google_compute_network.vpc-transit.name
  subnetwork            = google_compute_subnetwork.subnet1-vpc-transit.name
}


resource "google_compute_route" "default-route-to-ilb-transit" {
  name         = var.default-route-to-ilb-transit-name
  dest_range   = "0.0.0.0/0"
  network      = google_compute_network.vpc-transit.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-transit.ip_address
  priority     = 500
}


resource "google_compute_region_backend_service" "ilb-backend-hub1" {
  name          = var.ilb-backend-hub1-name
  region        = var.gcp-region
  health_checks = [google_compute_health_check.hc.id]
  protocol      = "TCP"
  network       = google_compute_network.vpc-hub1.self_link
  backend {
    group          = google_compute_instance_group.ig-nvas.self_link
    balancing_mode = "CONNECTION"
  }
}


resource "google_compute_forwarding_rule" "ilb-forwarding-rule-hub1" {
  name                  = var.ilb-forwarding-rule-hub1-name
  region                = var.gcp-region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.ilb-backend-hub1.id
  all_ports             = true
  ip_address            = "${var.subnet1-vpc-hub1-first-three-octets}${var.ilb-forwarding-rule-address}"
  network               = google_compute_network.vpc-hub1.name
  subnetwork            = google_compute_subnetwork.subnet1-vpc-hub1.name
}


resource "google_compute_route" "default-route-to-ilb-hub1" {
  name         = var.default-route-to-ilb-hub1-name
  dest_range   = "0.0.0.0/0"
  network      = google_compute_network.vpc-hub1.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub1.ip_address
  priority     = 500
}


resource "google_compute_route" "default-route-from-shared-vpc-to-ilb-hub1" {
  name         = var.default-route-from-shared-vpc-to-ilb-hub1
  dest_range   = "0.0.0.0/0"
  network      = module.shared_vpc.network_name #google_compute_network.vpc-hub1.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub1.ip_address
  priority     = 500
  project      = module.project-factory-shared-vpc.project_id
}

resource "google_compute_route" "default-route-from-hub1-spoke1-to-ilb-hub1" {
  name         = "default-route-from-hub1-spoke1-to-ilb-hub1"
  dest_range   = "0.0.0.0/0"
  network      = google_compute_network.vpc-hub1-spoke1.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub1.ip_address
  priority     = 500
}

resource "google_compute_route" "default-route-from-hub1-spoke2-to-ilb-hub1" {
  name         = "default-route-from-hub1-spoke2-to-ilb-hub1"
  dest_range   = "0.0.0.0/0"
  network      = google_compute_network.vpc-hub1-spoke2.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub1.ip_address
  priority     = 500
}

resource "google_compute_route" "route-sharedvpc-from-hub1-spoke1-to-ilb-hub1" {
  name         = "route-sharedvpc-from-hub1-spoke1-to-ilb-hub1"
  dest_range   = "${var.subnet1-sharedvpc-first-three-octets}.0/24"
  network      = google_compute_network.vpc-hub1-spoke1.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub1.ip_address
  priority     = 500
}

resource "google_compute_route" "route-sharedvpc-from-hub1-spoke2-to-ilb-hub1" {
  name         = "route-sharedvpc-from-hub1-spoke2-to-ilb-hub1"
  dest_range   = "${var.subnet1-sharedvpc-first-three-octets}.0/24"
  network      = google_compute_network.vpc-hub1-spoke2.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub1.ip_address
  priority     = 500
}

resource "google_compute_route" "route-onprem-from-hub1-spoke1-to-ilb-hub1" {
  name         = "route-onprem-from-hub1-spoke1-to-ilb-hub1"
  dest_range   = var.remote_subnet[0]
  network      = google_compute_network.vpc-hub1-spoke1.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub1.ip_address
  priority     = 500
}

resource "google_compute_route" "route-onprem-from-hub1-spoke2-to-ilb-hub1" {
  name         = "route-onprem-from-hub1-spoke2-to-ilb-hub1"
  dest_range   = var.remote_subnet[0]
  network      = google_compute_network.vpc-hub1-spoke2.name
  next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub1.ip_address
  priority     = 500
}

# resource "google_compute_region_backend_service" "ilb-backend-hub2" {
#   name          = var.ilb-backend-hub2-name
#   region        = var.gcp-region
#   health_checks = [google_compute_health_check.hc.id]
#   protocol      = "TCP"
#   network       = google_compute_network.vpc-hub2.self_link
#   backend {
#     group          = google_compute_instance_group.ig-nvas.self_link
#     balancing_mode = "CONNECTION"
#   }
# }


# resource "google_compute_forwarding_rule" "ilb-forwarding-rule-hub2" {
#   name                  = var.ilb-forwarding-rule-hub2-name
#   region                = var.gcp-region
#   load_balancing_scheme = "INTERNAL"
#   backend_service       = google_compute_region_backend_service.ilb-backend-hub2.id
#   all_ports             = true
#   ip_address            = "${var.subnet1-vpc-hub2-first-three-octets}${var.ilb-forwarding-rule-address}"
#   network               = google_compute_network.vpc-hub2.name
#   subnetwork            = google_compute_subnetwork.subnet1-vpc-hub2.name
# }


# resource "google_compute_route" "default-route-to-ilb-hub2" {
#   name         = var.default-route-to-ilb-hub2-name
#   dest_range   = "0.0.0.0/0"
#   network      = google_compute_network.vpc-hub2.name
#   next_hop_ilb = google_compute_forwarding_rule.ilb-forwarding-rule-hub2.ip_address
#   priority     = 500
# }


resource "google_compute_instance_group" "untrusted-group" {
  name        = "untrusted-vm-group"
  zone        = var.gcp-zone
  description = "Static container for our single Debian instance"

  # Wrap your single VM inside the group's array
  instances = [
    google_compute_instance.vm-in-untrusted.self_link
  ]

  named_port {
    name = "http"
    port = 80
  }
}


module "gce-lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "~> 14.0"

  project = var.project-id
  name    = "group-http-untrusted-elb"
  #target_tags       = [module.mig1.target_tags, module.mig2.target_tags]
  backends = {
    default = {
      port        = 80
      protocol    = "HTTP"
      port_name   = "http"
      timeout_sec = 10
      enable_cdn  = false


      health_check = {
        request_path = "/"
        port         = 80
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }


      groups = [
        {
          # Each node pool instance group should be added to the backend.
          group = google_compute_instance_group.untrusted-group.self_link
        },
      ]


    }
  }
}




# Deploy a cloud router that will be attached to the classic VPN
resource "google_compute_router" "cloud_router" {
  count   = var.toggle_cloud_vpn == true ? 1 : 0
  name    = "cr-${var.gcp-region}-to-prod-vpc-tunnels"
  region  = var.gcp-region
  network = google_compute_network.vpc-transit.self_link
  project = var.project-id
}

module "classic_vpn" {
  count = var.toggle_cloud_vpn == true ? 1 : 0
  # Deploy the classic VPN in GCP using the GCP module. Pin the Github
  # module to a specific version
  source  = "terraform-google-modules/vpn/google"
  version = "~> 7.0"

  project_id         = var.project-id
  network            = google_compute_network.vpc-transit.self_link
  region             = var.gcp-region
  gateway_name       = "vpn-managed-internal"
  tunnel_name_prefix = "vpn-tn-manage-internal"
  shared_secret      = var.shared_secret
  tunnel_count       = 1
  peer_ips           = ["${local.cleaned_ip}"]
  route_priority     = 1000
  remote_subnet      = var.remote_subnet
  ike_version        = 2
}