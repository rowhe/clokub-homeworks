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
resource "yandex_storage_bucket" "diploma-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = "bigbucket"
}

resource "yandex_storage_object" "cat-yes" {
  bucket = "bigbucket"
  key    = "cat-yes"
  source = "C:\Users\dpopov\Documents\GitHub\clokub-homeworks\15.2\infrastructure\files\cat-yes.jpg"
}
