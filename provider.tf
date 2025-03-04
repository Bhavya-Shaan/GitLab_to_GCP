provider "google" {
  project = "gcp-project"
  #token = var.do_token
  #credentials = file("gcp-ivn-project-12345678aa12.json")
  region = "us-central1"
  #zone = "us-central1-a"
}

#previous one
#provider "google" {
#  project      = "gcp-ivn-project"
#  #credentials = file("gcp-project-12345678aa12.json")
#  region       = "us-central1"
#  #zone        = "us-central1-a"
#}
