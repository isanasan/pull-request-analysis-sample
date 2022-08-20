
variable "project_id" {
  default = "four-keys-analyze"
}

terraform {
  required_version = "1.2.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.51.0"
    }
  }

  backend "local" {
    path = "./terraform.tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = "asia-northeast1"
}

resource "google_service_account" "github_importer" {
  account_id   = "github-importer"
  description  = "GitHubの情報をBigQueryに流し込むためのサービスアカウント"
  display_name = "github-importer"
  project      = var.project_id
}

resource "google_project_iam_member" "github_importer_bigquery_jobuser_bindings" {
  role   = "roles/bigquery.jobUser"
  member = "serviceAccount:${google_service_account.github_importer.email}"
}

resource "google_bigquery_dataset_access" "github_importer_bigquery_dataset_access_bindings" {
  dataset_id    = "source__github"
  role          = "WRITER"
  user_by_email = google_service_account.github_importer.email
  depends_on = [
    google_bigquery_dataset.source__github
  ]
}

resource "google_service_account" "dataform_executor" {
  account_id  = "dataform-executor"
  description = "Datafrom (dataform.co) に付与する用のサービスアカウント"
  project     = var.project_id
}

resource "google_project_iam_member" "dataform_executor_bigquery_admin_bindings" {
  role   = "roles/bigquery.admin"
  member = "serviceAccount:${google_service_account.dataform_executor.email}"
}

resource "google_bigquery_dataset" "source__github" {
  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }

  access {
    role          = "WRITER"
    user_by_email = "github-importer@four-keys-analyze.iam.gserviceaccount.com"
  }

  default_partition_expiration_ms = 5184000000
  default_table_expiration_ms     = 5184000000
  dataset_id                      = "source__github"
  delete_contents_on_destroy      = false
  location                        = "asia-northeast1"
  project                         = var.project_id
  depends_on = [
    google_service_account.github_importer
  ]
}

resource "google_bigquery_table" "pull_requests" {
  dataset_id = google_bigquery_dataset.source__github.dataset_id
  project    = var.project_id
  schema     = file("./schema.json")
  table_id   = "pull_requests"
  depends_on = [
    google_bigquery_dataset.source__github
  ]
}

