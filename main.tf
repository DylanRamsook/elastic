variable "project_id" {
    default=""
}
variable "gke_name" {
    default="gs-corp-collections"
}
variable "region" {
    default=""
}
variable "service_account" {
    default=""
}
variable "zone" {
    default="us-east4-c"
}
variable "operator_url" {
  default="https://download.elastic.co/downloads/eck/1.4.1/all-in-one.yaml"
}
provider "google" {
  project = var.project_id
  region  = var.region
}


#This needs to exist in GCP already!!!
terraform {
  backend "gcs" {
    bucket  = "tf-state-collections-gke"
    prefix  = "terraform/state"
  }
}

# google_client_config and kubernetes provider must be explicitly specified like the following.
data "google_client_config" "default" {}

provider "kubernetes" {
  load_config_file       = false
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google"
  project_id                 = var.project_id
  name                       = var.gke_name
  region                     = var.region
  zones                      = ["${var.region}-c"]
  network_project_id         = "p-is-us-xpn-de67"
  network                    = "gs-resource-vpc"
  subnetwork                 = "d-us-east4-gs-gke-172-28-11-128-26"
  ip_range_pods              = "d-us-east4-gs-gke-pods-10-64-72-0-24"
  ip_range_services          = "d-us-east4-gke-services-100-68-17-0-24"
  http_load_balancing        = true
  horizontal_pod_autoscaling = true
  network_policy             = false
  cluster_ipv4_cidr          = "172.28.4.96/28"

  node_pools = [
    {
      name               = "gsei-eck-warm-pool"
      machine_type       = "e2-highmem-4"
      node_locations     = "us-east4-c"
      min_count          = 1
      max_count          = 3
      local_ssd_count    = 0
      disk_size_gb       = 100
      disk_type          = "pd-ssd"
      image_type         = "UBUNTU"
      auto_repair        = true
      auto_upgrade       = true
      service_account    = var.service_account
      preemptible        = false
      initial_node_count = 1
    },

    {
      name               = "gsei-eck-hot-pool"
      machine_type       = "e2-highmem-4"
      node_locations     = "us-east4-c"
      min_count          = 1
      max_count          = 3
      local_ssd_count    = 0
      disk_size_gb       = 100
      disk_type          = "pd-ssd"
      image_type         = "UBUNTU"
      auto_repair        = true
      auto_upgrade       = true
      service_account    = var.service_account
      preemptible        = false
      initial_node_count = 1
    },

    {
      name               = "gsei-eck-misc-pool"
      machine_type       = "e2-highmem-8"
      node_locations     = "us-east4-c"
      min_count          = 1
      max_count          = 3
      local_ssd_count    = 0
      disk_size_gb       = 100
      disk_type          = "pd-ssd"
      image_type         = "UBUNTU"
      auto_repair        = true
      auto_upgrade       = true
      service_account    = var.service_account
      preemptible        = false
      initial_node_count = 1
    },
  ]

  node_pools_oauth_scopes = {
    all = ["https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/cloud-platform"]

    default-node-pool = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_pools_labels = {
    all = {}

    default-node-pool = {
      default-node-pool = true
    }
    gsei-eck-warm-pool = {
      node_type = "warm",
      role  = "elasticsearch",
      team  = "gsei"
    }
    gsei-eck-hot-pool = {
      node_type = "hot",
      role  = "elasticsearch",
      team  = "gsei"
    }
    gsei-eck-warm-pool = {
      node_type = "misc",
      role  = "elasticsearch",
      team  = "gsei"
    }
  }

  node_pools_metadata = {
    all = {}

    default-node-pool = {
      node-pool-metadata-custom-value = "my-node-pool"
    }
  }

  node_pools_taints = {
    all = []

    default-node-pool = [
      {
        key    = "default-node-pool"
        value  = true
        effect = "PREFER_NO_SCHEDULE"
      },
    ]
  }

  node_pools_tags = {
    all = []

    default-node-pool = [
      "default-node-pool",
    ]
  }
}

resource "null_resource" "installer" {

    provisioner "local-exec" {

        command = "kubectl --insecure-skip-tls-verify=true --server=\"${module.gke.endpoint}\" --token=\"${data.google_client_config.default.access_token}\"  apply -f ${ var.operator_url }"
    }
}
