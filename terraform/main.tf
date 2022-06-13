
variable project_id {
  default = "<your-project-id>"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.51.0"
    }
  }

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "hatena"

    workspaces {
      name = "pull-request-analysis-sample"
    }
  }
}

provider "google" {
  project = var.project_id
  region      = "asia-northeast1"
}

resource "google_service_account" "github_importer" {
  account_id   = "github-importer"
  description  = "GitHubの情報をBigQueryに流し込むためのサービスアカウント"
  display_name = "github-importer"
  project = var.project_id
}

resource "google_project_iam_member" "github_importer_bigquery_jobuser_bindings" {
  role   = "roles/bigquery.jobUser"
  member = "serviceAccount:${google_service_account.github_importer.email}"
}

resource "google_bigquery_dataset_access" "github_importer_bigquery_dataset_access_bindings" {
  dataset_id    = "source__github"
  role          = "WRITER"
  user_by_email = google_service_account.github_importer.email
}

resource "google_service_account" "dataform_executor" {
  account_id  = "dataform-executor"
  description = "Datafrom (dataform.co) に付与する用のサービスアカウント"
  project = var.project_id
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

  dataset_id                 = "source__github"
  delete_contents_on_destroy = false
  location                   = "asia-northeast1"
  project = var.project_id
}

resource "google_bigquery_table" "pull_requests" {
  dataset_id = google_bigquery_dataset.source__github.dataset_id
  project = var.project_id
  schema     = "[{\"mode\":\"REPEATED\",\"name\":\"labelNames\",\"type\":\"STRING\"},{\"mode\":\"NULLABLE\",\"name\":\"headRefName\",\"type\":\"STRING\"},{\"mode\":\"NULLABLE\",\"name\":\"baseRefName\",\"type\":\"STRING\"},{\"mode\":\"NULLABLE\",\"name\":\"deletions\",\"type\":\"INTEGER\"},{\"fields\":[{\"mode\":\"NULLABLE\",\"name\":\"typename\",\"type\":\"STRING\"},{\"mode\":\"NULLABLE\",\"name\":\"login\",\"type\":\"STRING\"}],\"mode\":\"NULLABLE\",\"name\":\"author\",\"type\":\"RECORD\"},{\"description\":\"bq-datetime\",\"mode\":\"NULLABLE\",\"name\":\"firstCommittedAt\",\"type\":\"TIMESTAMP\"},{\"mode\":\"NULLABLE\",\"name\":\"id\",\"type\":\"STRING\"},{\"mode\":\"NULLABLE\",\"name\":\"additions\",\"type\":\"INTEGER\"},{\"fields\":[{\"mode\":\"NULLABLE\",\"name\":\"totalCount\",\"type\":\"INTEGER\"}],\"mode\":\"NULLABLE\",\"name\":\"reviews\",\"type\":\"RECORD\"},{\"description\":\"bq-datetime\",\"mode\":\"NULLABLE\",\"name\":\"mergedAt\",\"type\":\"TIMESTAMP\"},{\"fields\":[{\"mode\":\"NULLABLE\",\"name\":\"nameWithOwner\",\"type\":\"STRING\"}],\"mode\":\"NULLABLE\",\"name\":\"repository\",\"type\":\"RECORD\"},{\"mode\":\"NULLABLE\",\"name\":\"number\",\"type\":\"INTEGER\"},{\"mode\":\"NULLABLE\",\"name\":\"title\",\"type\":\"STRING\"},{\"description\":\"bq-datetime\",\"mode\":\"NULLABLE\",\"name\":\"createdAt\",\"type\":\"TIMESTAMP\"},{\"mode\":\"NULLABLE\",\"name\":\"url\",\"type\":\"STRING\"}]"
  table_id   = "pull_requests"
}

