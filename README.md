# Дипломный практикум в Yandex.Cloud
# Автор: Александр Бызгаев

## Цели:
1) Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.  
2) Запустить и сконфигурировать Kubernetes кластер.  
3) Установить и настроить систему мониторинга.  
4) Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.  
5) Настроить CI для автоматической сборки и тестирования.  
6) Настроить CD для автоматического развёртывания приложения.  

## Этапы выполнения:

## 1) Создание облачной инфраструктуры

**В этом разделе я подготовил облачную инфраструктуру в Яндекс.Облаке при помощи Terraform.**

### 1.1 Создание сервисного аккаунта

Первым шагом я создал сервисный аккаунт с необходимыми правами для работы Terraform:

**- Создание директории для Terraform**
```bash
mkdir -p terraform/service-account
cd terraform/service-account
```
**- Создание файла provider.tf**
```bash
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.140.0"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = "y0__xCBgaYFGMHdEyDQ8vS1EqvdVwf5otUuJ2oUOCbCIUhZN822"
  cloud_id  = "b1g31ab21b32dog1ps4c"
  folder_id = "b1gam4o6rj97es4peaq4"
  zone      = "ru-central1-a"
} 
```
**- Создание файла service-account.tf**
```bash
# Создание сервисного аккаунта для Terraform
resource "yandex_iam_service_account" "terraform" {
  name        = "terraform-sa"
  description = "Service account for Terraform"
}

# Назначение роли editor сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "terraform-editor" {
  folder_id = "b1gam4o6rj97es4peaq4"
  role      = "editor"
  member    = "serviceAccount:\${yandex_iam_service_account.terraform.id}"
}

# Назначение роли storage.admin для работы с S3
resource "yandex_resourcemanager_folder_iam_member" "terraform-storage-admin" {
  folder_id = "b1gam4o6rj97es4peaq4"
  role      = "storage.admin"
  member    = "serviceAccount:\${yandex_iam_service_account.terraform.id}"
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
```
**- Инициализация и применение Terraform**
```bash
mkdir -p terraform/service-account
cd terraform/service-account
```
### После успешного выполнения я получил:

- Сервисный аккаунт terraform-sa с необходимыми правами
- S3-бакет для хранения состояния Terraform
- Статический ключ доступа для работы с API Яндекс.Облака

### 1.2 Создание основной инфраструктуры

Далее я создал основную инфраструктуру, включая VPC с подсетями в разных зонах доступности:














































































