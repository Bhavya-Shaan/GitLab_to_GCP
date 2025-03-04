#Artifact Registory
#resource "google_artifact_registry_repository" "my_repo" {
#  location = "us-central1"
#  repository_id = "benchmarklens-deployment"
#  format = "DOCKER"
#}

data "google_artifact_registry_docker_image" "frontend_image" {
  #location      = google_artifact_registry_repository.my_repo.location
  #repository_id = google_artifact_registry_repository.my_repo.repository_id
  location = "us-central1"
  #location = variables.location
  repository_id = "benchmarklens-deployment"
  image_name    = "frontend:latest"
}

data "google_artifact_registry_docker_image" "backend_image" {
  #location      = google_artifact_registry_repository.my_repo.location
  #repository_id = google_artifact_registry_repository.my_repo.repository_id
  location = "us-central1"
  repository_id = "benchmarklens-deployment"
  image_name    = "backend:latest"
}


# Cloud SQL Instance                                ***** 1 *****
resource "google_sql_database_instance" "sql_instance" {
  name = "bml-postgres-instance-demo"
  #database_version = "PostgreSQL 16.4"
  database_version = "POSTGRES_15"
  region = "us-central1"
  #region = var.location
  deletion_protection = "false"

  settings {
    tier = "db-f1-micro" #machinetype
    #ip_configuration {
    #  private_network = google_compute_network.vpc_network.self_link
    #}
  }
}

#Cloud SQL database                             ***** 2 *****
resource "google_sql_database" "database" {
  name = "benchmarkLens_dev_demo"
  instance = google_sql_database_instance.sql_instance.name
}

# BigQuery Dataset                              ***** 3 *****
resource "google_bigquery_dataset" "dataset" {
  dataset_id = "benchmarklens_dataset_demo"
  location = "us-central1"
}

##IAM for Cloud Run
#resource "google_project_iam_member" "cloud_run_permission" {
#  project = "gcp-project"
#  role = "roles/run.invoker"
#  member = "serviceAccount:123456789999-compute@developer.gserviceaccount.com"
#}

#Cloud Run Backend                              ***** 4 *****
resource "google_cloud_run_service" "backend" {
    name = "bml-backend-demo"
    location = "us-central1"
    
    template {
        metadata {
            annotations = {
                "run.googleapis.com/startup-cpu-boost" = "true"
            }
        }
        
        spec {
            containers {
                #image = "us-central1-docker.pkg.dev/gcp-project/benchmarklens-deployment/backend"
                #image = "us-central1-docker.pkg.dev/gcp-project/benchmarklens-deployment/backend:latest"
                image = data.google_artifact_registry_docker_image.backend_image.self_link
                ports {
                    name = "http1"
                    container_port = "8000"
                }

                resources {
                    limits = {
                        cpu = "2"
                        memory = "1024Mi"
                    }
                }
                
                startup_probe {
                    timeout_seconds = 240
                    period_seconds = 240
                    failure_threshold = 1
                    tcp_socket {
                        port = 8000
                    }
                }
            }
        }
    }
    
    traffic {
        percent = 100
        latest_revision = true
    }
    
    #vpc_access {
        #connector = google_vpc_access_connector.connector.name
    #}
}

#Cloud Run Frontend                             ***** 5 *****
resource "google_cloud_run_service" "frontend" {
    name = "bml-frontend-demo"
    location = "us-central1"
    
    template {
        metadata {
            annotations = {
                #"run.googleapis.com/network-interfaces" = "vpc-access-connector"
                #"run.googleapis.com/vpc-access-connector" = jsonencode({
                    #"name" = google_vpc_access_connector.vpc_connector.id})
                
                #"run.googleapis.com/vpc-access-connector" = 
                    #"projects/gcp-project/locations/us-central1/connectors/cr-vpc-ctr-d-1"
                #"run.googleapis.com/vpc-access-egress" = "all"
                
                "run.googleapis.com/network-interfaces" = jsonencode([{
                    "network"    = "default"
                    "subnetwork" = "default" }])
                "run.googleapis.com/vpc-access-egress" = "all-traffic" # Route all traffic to the VPC
                
                "autoscaling.knative.dev/minScale" = "1"  # Minimum number of instances
                "autoscaling.knative.dev/maxScale" = "100" # Maximum number of instances
                
                "run.googleapis.com/startup-cpu-boost" = "true"
                
                #"run.googleapis.com/ingress" = "all" # Allow all traffic
            }
        }
        
        spec {
            containers {
                #image = "us-central1-docker.pkg.dev/gcp-project/benchmarklens-deployment/frontend"
                image = data.google_artifact_registry_docker_image.frontend_image.self_link
                ports {
                    name = "http1"
                    container_port = 3000
                    }
                
                resources {
                    limits = {
                        cpu = "2"
                        memory = "1024Mi"
                    }
                }
                
                env {
                    name = "BACKEND_SERVICE_URL"
                    #value = "http://backend.<YOUR_DNS_NAME>"
                    value = "http://backend.bml-backend-123456789999.us-central1.run.app."
                    
                    #name = "creds"
                    #value_from {
                        #secret_key_ref{
                            #key = "latest"
                            #name = "bml-backend-secret"
                        #}
                    #}
                }
                
                #vpc_access {
                    #connector = google_vpc_access_connector.vpc_connector.name
                    #egress = "ALL_TRAFFIC"
                #}
                
                startup_probe {
                    timeout_seconds = 240
                    period_seconds = 240
                    failure_threshold = 1
                    tcp_socket {
                        port = 3000
                    }
                }
            }
        }
    }
    
    traffic {
        percent = 100
        latest_revision = true
    }
}

# Cloud Task                                ***** 6 *****
#resource "google_cloud_tasks_queue" "my_task" {
    #name = "benchmarklens-task-demo"
    #location = "us-central1"
    #rate_limits {
        #max_dispatches_per_second = 1
    #}
    
    #retry_config {
        #max_attempts = 1
    #}
    
    ##app_engine_http_target {
        ##app_engine_routing {
            ##service = google_cloud_run_service.gke_cluster.name
        ##}
    ##}
#}

##GCS Bucket Terraform State                                ***** 7 *****
#resource "random_id" "default" {
    #byte_length = 8
#}

#GCS Bucket Terraform State                             ***** 8 *****
resource "google_storage_bucket" "gcs_bucket" {
  #name     = "${random_id.default.hex}-terraform-remote-backend"
  name     = "bml-tf-remote-backend-demo"
  location = "us-central1"
  
  force_destroy               = true
  #public_access_prevention    = "enforced"
  #uniform_bucket_level_access = true
  
  #versioning {
    #enabled = true
  #}
}

##File in bucket and local                               ***** 9 *****
#resource "local_file" "default" {
  #file_permission = "0644"
  #filename        = "${path.module}/backend.tf"
  #content = <<-EOT
  #terraform {
    #backend "gcs" {
      ##bucket = "${google_storage_bucket.gcs_bucket.name}"
      #bucket = google_storage_bucket.gcs_bucket.name
    #}
  #}
  #EOT
#}
