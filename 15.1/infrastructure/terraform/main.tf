terraform {
  required_providers {
    yandex = { source = "yandex-cloud/yandex" }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
    token               = "var.yc_token"
    cloud_id            = "var.yc_cloud_id"
    folder_id           = "var.yc_folder_id"
    zone                = "var.yc_region"
}

resource "yandex_vpc_network" "diploma" {
    name                = "diploma-net"
}



// Create SA
resource "yandex_iam_service_account" "sa" {
  folder_id = "${var.yc_folder_id}"
  name      = "tf-test-sa"
}

// Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = "${var.yc_folder_id}"
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

// Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

// Use keys to create bucket
resource "yandex_storage_bucket" "stage732-1235gwosn" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = "bigbucket"
}
