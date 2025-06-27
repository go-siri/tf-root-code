
################################### Section 1 ##############################
## Goal:
## Create a VPC, Subnet, 2 firewall rules & a compute instance
## Observe how implicit dependencies are created
## Observe that the writing order of the code doesnt matter
## Observe how you declare a variable and use it, we will explore this more in lab2
## Try to refer to google_compute_instance Terraform resource page and understand madatory & optional attributes

 variable project_id {
    type = string
    default = "qwiklabs-gcp-03-4098875a0c98"
}


## Creates "my-vpc" in the specified project
resource "google_compute_network" "my_vpc" {
  project                 = var.project_id
  name                    = "my-vpc"
  auto_create_subnetworks = false
}

## Creates "my-subnet" in "my-vpc" VPC
resource "google_compute_subnetwork" "my_subnet" {
  name          = "my-subnet"
  project       = google_compute_network.my_vpc.project
  ip_cidr_range = "192.168.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.my_vpc.id
}

## Create Firewall rule to allow http traffic
resource "google_compute_firewall" "allow_http" {
  name          = "allow-http"
  project       = google_compute_network.my_vpc.project
  network       = google_compute_network.my_vpc.id
  source_ranges = ["192.168.0.0/24"]
  target_tags   = ["www"]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

## Create Firewall rule to allow iap
resource "google_compute_firewall" "allow_iap" {
  name          = "allow-iap"
  project       = google_compute_network.my_vpc.project
  network       = google_compute_network.my_vpc.id
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

## create compute instance with the name instance-1
resource "google_compute_instance" "vm_instance1" {
  project      = google_compute_network.my_vpc.project
  name         = "instance1"
  machine_type = "e2-micro"
  zone         = "us-central1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.my_vpc.id
    subnetwork = google_compute_subnetwork.my_subnet.id
  }
}


###################################### Section 2 #######################################
## Goal for this section is:
## Create another Compute instance using global and local variables & define machine type based on a boolean variable
## To learn how to use both global and local variables
## Learn how to use ternary or conditional operator ("?")
## Capture output from terraform execution
## Use for_each loop

## Observe below  3 global variables that are defined in variables.tf
      ### vm_name (string), 
      ### vm_isamd (bool) 
      ### region (string) 
## Observe the local variable gce_zone that is defined and how it is used below


## Define a local variable 
locals {
  gce_zone = "${var.region}-b"
}

## Create a compute instance based on value of the variable is_amd
## Update terraform.tfvars with the variable is_amd 
## set the value of is_amd variable to true or false and observe the value populated for machine_type
resource "google_compute_instance" "vm_instance2" {
  project      = google_compute_network.my_vpc.project
  name         = "${var.vm_name}"
  machine_type = var.is_amd ? "n2d-standard-2" : "n2-standard-2"
  zone         = local.gce_zone
  
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.my_vpc.id
    subnetwork = google_compute_subnetwork.my_subnet.id
  }
}

## Lets use count to create multiple disks
## Observe the loop feature and usage of count.index
resource "google_compute_disk" "standard_disks" {
  count    = var.disk_count
  project  = var.project_id
  name     = "disk-${count.index}"
  type     = "pd-standard"
  zone     = local.gce_zone
  size     = 10 ## size is in GB
}

## Observe web_instances variable in variables.tf & the value in terraform.tfvars
## Observe how we for_each and how we loop through different VM sets & use key & value for name & machine_type attributes
resource "google_compute_instance" "web_instances" {
  for_each     = var.web_instances 
  project      = google_compute_network.my_vpc.project
  name         = each.key
  machine_type = each.value.machine_type
  zone         = local.gce_zone
  
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

 network_interface {
    network    = google_compute_network.my_vpc.id
    subnetwork = google_compute_subnetwork.my_subnet.id
  }
  tags = ["www"]
}

## This creates Unmanaged instance group resource and add all the web servers created in the above step
## Observe how the input from google_compute_instance.web_instances is parsed and referred to in this block
resource "google_compute_instance_group" "my_webserver_ig" {
  name        = "my-webservers"
  description = "The instance group for the web servers"
  project     = google_compute_network.my_vpc.project
  instances   = [for _,vm in google_compute_instance.web_instances : vm.self_link]

  named_port {
    name = "http"
    port = "80"
  }

  zone = local.gce_zone
}

########################################### Section 3 #############################
##Goal:
## Reference & consume external modules
## Create Load balancer & point to unmanaged instance group created above

module "my_ilb" {
  source        = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-lb-int"
  project_id    = google_compute_network.my_vpc.project
  region        = var.region
  name          = "lb-test"
  vpc_config    = {
    network       = google_compute_network.my_vpc.self_link
    subnetwork    = google_compute_subnetwork.my_subnet.self_link
  }
  backends = [{
    group          = google_compute_instance_group.my_webserver_ig.self_link
    }
  ]
  health_check_config = {
    tcp = {
      port = 80
    }
  }
}

module "my_nat" {
  source         = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-cloudnat"
  name           = "my-nat"
  project_id     = google_compute_network.my_vpc.project
  region         = var.region
  router_network = google_compute_network.my_vpc.self_link
}

########## Note: ##############
## Please run terraform init after updating the above modules as it has to initialize modules reffered above else it might error out stating modules doesnt exist

## To ensure Google cloud health checks to reach instances in Managed instance group, you need to create 
## firewall rule that permits traffic from the health check IP ranges which are 35.191.0.0/16 & 130.211.0.0/22
resource "google_compute_firewall" "allow_hc" {
  name          = "allow-hc"
  project       = google_compute_network.my_vpc.project
  network       = google_compute_network.my_vpc.id
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["www"]
  allow {
    protocol = "tcp"
    ports     = ["80"]
  }
}

## Use this block of code to define the client machine thats created using the gcloud command
## Un-comment this when you are 4.2 step in the instructions (Readme.md)
/* resource "google_compute_instance" "my_client" {
  name         = "my-client"
  project      = google_compute_network.my_vpc.project
  machine_type = "e2-micro"
  zone         = "us-central1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.my_vpc.id
    subnetwork = google_compute_subnetwork.my_subnet.id
  }
} 
*/

## Create a GCS bucket to store Terraform state file
resource "google_storage_bucket" "default" {
  name                        = "${google_compute_network.my_vpc.project}-bucket-tfstate"
  project                     = google_compute_network.my_vpc.project
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = true
  }
}
