## VPC Access connector								***** 10 *****
#resource "google_vpc_access_connector" "vpc_connector" {
##data "google_vpc_access_connector" "vpc_connector" {
  #name = "cr-vpc-ctr-d-1"
  #network = data.google_compute_network.vpc_network.name
  ##network = "default"
  #min_instances = 2
  #max_instances = 3
  #region = "us-central1"
  #ip_cidr_range = "10.8.0.0/28"
#}

#import {
#  id = "projects/{gcp-ivn-project}/locations/{us-central1}/connectors/{cloud-run-vpc-connector-demo}"
#  #to = google_vpc_access_connector.default
#  to = google_vpc_access_connector.vpc_connector
#}
#terraform import google_vpc_access_connector.default {cloud-run-vpc-connector-demo}

## Subnetwork
#resource "google_compute_subnetwork" "subnet" {
#  name = "default" #subnet-internal
#  #network = google_compute_network.vpc_network.name
#  network = "default"
#  ip_cidr_range = "10.128.0.0/20"
#  region = "us-central1"
#}

# VPC Network
data "google_compute_network" "vpc_network" {
  name = "default"
  #auto_create_subnetworks = false
}
#resource "google_compute_network" "vpc_network" {
  #name = "default"
  ##auto_create_subnetworks = false
#}





#DNS Zone Configuration								***** 11 *****
resource "google_dns_managed_zone" "env_dns_zone" {
  name = "bml-backend-zone-service-demo"
  dns_name = "bml-backend-demo-123456789999.us-central1.run.app."
  visibility = "private"
  private_visibility_config {
    networks {
      network_url = data.google_compute_network.vpc_network.self_link
    }
  }
  #dnssec_config {
  #  state = "off"
  #}
}

# DNS record									***** 12 *****
resource "google_dns_record_set" "dns" {
  managed_zone = google_dns_managed_zone.env_dns_zone.name
  name = "dns.${google_dns_managed_zone.env_dns_zone.dns_name}"
  type = "A"
  ttl  = 60

  #rrdatas = [google_cloud_run_service.backend.status[0].url]
  rrdatas = ["10.128.0.64"]
}







resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  #name = "bml-backend-service-demo"
  name = "bml-backend-endpoint-group-demo"
  network_endpoint_type = "SERVERLESS"
  region = "us-central1"

  cloud_run {
    service = google_cloud_run_service.backend.name
  }
}

##1 Manged Instance Group
#resource "google_compute_instance_template" "instance_template"{
  ##name = "bml-instance-template-demo"
  #name = "benchmarklens-computeengine-vm-instance-demo"
  #machine_type = "e2-micro"

  #disk {
    #source_image = ""
    #auto_delete = true
    #boot  = true
  #}

  #network_interface {
    #network = "default"
    #access_config{}
  #}
#}


##Instance GM
#resource "google_compute_instance_group_manager" "default" {
  #name = "instance-group-demo"
  #base_instance_name = "my-instance-demo"
  #version {
    #instance_template = 
    #  google_compute_instance_template.instance_template.self_link
  #}

#}
  
  #zone = "us-central1-a"
#}

# 2 Backend Service
resource "google_compute_backend_service" "backend_service" {
  name = "bml-backend-service-demo"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  
  protocol = "HTTPS"
  port_name = "http"
  #timeout_sec = 610
  enable_cdn = true
  
  cdn_policy {
    serve_while_stale = 0
    negative_caching = false
    #security_policy = ""
    #compression_mode = "DISABLED"
    signed_url_cache_max_age_sec = "0"
  }

  backend {
    ##group = google_compute_region_network_endpoint_group.cloud_run_neg.id
    group = google_compute_region_network_endpoint_group.cloud_run_neg.self_link
  }

  ##health_checks = [google_compute_health_check.health_check.self_link]
}

resource "google_compute_health_check" "health_check" {
  name = "health-check-demo"
  check_interval_sec = 5
  timeout_sec = 5
  healthy_threshold = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
  }
}

# 3 MAP URL
resource "google_compute_url_map" "default" {
  name = "bml-loadbalancer-demo"
  default_service = google_compute_backend_service.backend_service.self_link
  #default_route_action {
    #timeout {
      #seconds =610
    #}
  #}

  #weighted_backend_services {
    #backend_service = google_compute_backend_service.backend_service.self_link
    #weight = 100
  #}
}

# 4 Target HTTP Proxy
resource "google_compute_target_http_proxy" "target_proxy" {
  name = "bml-loadbalancer-target-proxy-demo"
  url_map = google_compute_url_map.default.self_link
}

# 5 Global Forwarding rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name = "bml-lb-demo"
  target = google_compute_target_http_proxy.target_proxy.self_link
  port_range = "80"
  ip_address = google_compute_global_address.global_address.address
}

resource "google_compute_global_address" "global_address" {
  #name = "bml-global-address-demo"
  name = "bml-lb-demo"
}
