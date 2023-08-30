variable "project_id" {
  type= string
  description = "GCS project ID"
}

variable "bucket_name" {
    type =string
    description= "Name of Google Storage Bucket to create"
}

variable "region" {
  type = string
  description = "Region for GCP resources"
  default = "europe-west6"
}

variable "storage_class" {
  type = string
  description = "Storage class type for bucket."
  default = "STANDARD"
}


variable "registry_id" {
  type = string
  description = "Name of artifact registry repository."
}