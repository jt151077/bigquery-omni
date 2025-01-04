/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


resource "google_bigquery_connection" "aws_connection" {
  depends_on = [
    google_project_service.gcp_services
  ]

  project       = local.project_id
  connection_id = "${local.project_id}-aws-s3-connection"
  location      = local.aws_s3_region
  friendly_name = "${local.project_id}-aws-s3-connection"

  aws {
    access_role {
      iam_role_id = local.aws_role_id
    }
  }
}


resource "google_bigquery_dataset" "gcp_data" {
  depends_on = [
    google_project_service.gcp_services
  ]
  project       = local.project_id
  dataset_id    = "gcp_data"
  location      = local.gcp_data_region
}

resource "google_bigquery_dataset" "aws_s3_data" {
  depends_on = [
    google_project_service.gcp_services
  ]
  project       = local.project_id
  dataset_id    = "aws_s3_data"
  friendly_name = "aws_s3_data"
  location      = local.aws_s3_region
}

resource "google_bigquery_routine" "aws_external_table_create" {
  depends_on = [
    google_project_service.gcp_services,
    google_bigquery_dataset.aws_s3_data
  ]

  project         = local.project_id
  dataset_id      = google_bigquery_dataset.aws_s3_data.dataset_id
  routine_id      = "aws_external_table_create"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = <<EOF
CREATE OR REPLACE EXTERNAL TABLE ${google_bigquery_dataset.aws_s3_data.dataset_id}.aws_data_ext
  WITH CONNECTION `${local.project_id}.${local.aws_s3_region}.${google_bigquery_connection.aws_connection.connection_id}`
  OPTIONS (
    format = "CSV",
    uris = ["s3://${local.aws_s3_bucket_name}/*"]);
EOF
}


resource "google_bigquery_routine" "aws_local_table_create" {
  depends_on = [
    google_project_service.gcp_services,
    google_bigquery_dataset.gcp_data
  ]

  project         = local.project_id
  dataset_id      = google_bigquery_dataset.aws_s3_data.dataset_id
  routine_id      = "aws_local_table_create"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = <<EOF
LOAD DATA OVERWRITE `${local.project_id}.${google_bigquery_dataset.gcp_data.dataset_id}.aws_data_local`
  FROM FILES (
    uris = ['s3://${local.aws_s3_bucket_name}/*'],
    format = 'CSV'
  )
WITH CONNECTION `${local.project_id}.${local.aws_s3_region}.${google_bigquery_connection.aws_connection.connection_id}`
EOF
}

output "bigquery_google_identity" {
  value = google_bigquery_connection.aws_connection.aws[0].access_role[0].identity
}
