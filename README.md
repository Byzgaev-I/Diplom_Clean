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

- Создание директории для Terraform
```bash
mkdir -p terraform/service-account
cd terraform/service-account
```
- Создание файла provider.tf
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
EOF  
```



















































































