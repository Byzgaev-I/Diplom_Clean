# Создание сервисного аккаунта для Terraform
resource "yandex_iam_service_account" "terraform" {
  name        = "terraform-sa"
  description = "Service account for Terraform"
}

# Назначение роли editor сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "terraform-editor" {
  folder_id = "b1gam4o6rj97es4peaq4"
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

# Назначение роли storage.admin для работы с S3
resource "yandex_resourcemanager_folder_iam_member" "terraform-storage-admin" {
  folder_id = "b1gam4o6rj97es4peaq4"
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

# Создание статического ключа доступа для сервисного аккаунта
resource "yandex_iam_service_account_static_access_key" "terraform-static-key" {
  service_account_id = yandex_iam_service_account.terraform.id
  description        = "Static access key for Terraform"
}

# Создание S3 бакета для хранения состояния Terraform
resource "yandex_storage_bucket" "terraform-state" {
  bucket     = "terraform-state-bucket-diploma-byzgaev"
  access_key = yandex_iam_service_account_static_access_key.terraform-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform-static-key.secret_key
  force_destroy = true
}

# Вывод информации о созданных ресурсах
output "terraform_service_account_id" {
  value = yandex_iam_service_account.terraform.id
}

output "terraform_access_key" {
  value = yandex_iam_service_account_static_access_key.terraform-static-key.access_key
}

output "terraform_secret_key" {
  value     = yandex_iam_service_account_static_access_key.terraform-static-key.secret_key
  sensitive = true
}

output "terraform_bucket_name" {
  value = yandex_storage_bucket.terraform-state.bucket
}
