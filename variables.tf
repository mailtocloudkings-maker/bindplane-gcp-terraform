variable "project_id" {}
variable "region" { default = "us-central1" }
variable "zone"   { default = "us-central1-a" }
variable "credentials_file" {
  description = "Path to GCP service account key file"
  type        = string
}

variable "vm_name" {}
variable "db_user" {}
variable "db_pass" {}
variable "bp_admin_user" {}
variable "bp_admin_pass" {}
variable "bucket_name" {}


