# Сервисный аккаунт для Kubernetes кластера
resource "yandex_iam_service_account" "k8s-sa" {
  name        = "k8s-service-account"
  description = "Service account for Kubernetes cluster"
}

# Назначение необходимых ролей
resource "yandex_resourcemanager_folder_iam_member" "k8s-admin" {
  folder_id = "b1gam4o6rj97es4peaq4"
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s-images-puller" {
  folder_id = "b1gam4o6rj97es4peaq4"
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
}

# Создание Kubernetes кластера
resource "yandex_kubernetes_cluster" "diploma-cluster" {
  name        = "diploma-cluster"
  description = "Kubernetes cluster for diploma project"
  network_id  = yandex_vpc_network.diploma-network.id

  master {
    version = "1.30"
    regional {
      region = "ru-central1"
      location {
        zone      = yandex_vpc_subnet.subnet-a.zone
        subnet_id = yandex_vpc_subnet.subnet-a.id
      }
      location {
        zone      = yandex_vpc_subnet.subnet-b.zone
        subnet_id = yandex_vpc_subnet.subnet-b.id
      }
      location {
        zone      = yandex_vpc_subnet.subnet-d.zone
        subnet_id = yandex_vpc_subnet.subnet-d.id
      }
    }

    public_ip = true
    
    maintenance_policy {
      auto_upgrade = true
      
      maintenance_window {
        start_time = "03:00"
        duration   = "3h"
      }
    }
  }

  service_account_id      = yandex_iam_service_account.k8s-sa.id
  node_service_account_id = yandex_iam_service_account.k8s-sa.id
  
  release_channel = "STABLE"
  
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s-admin,
    yandex_resourcemanager_folder_iam_member.k8s-images-puller
  ]
}

# Создание группы узлов
resource "yandex_kubernetes_node_group" "diploma-node-group" {
  cluster_id  = yandex_kubernetes_cluster.diploma-cluster.id
  name        = "diploma-node-group"
  description = "Node group for diploma Kubernetes cluster"
  version     = "1.30"

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = ["${yandex_vpc_subnet.subnet-a.id}"]
    }

    resources {
      memory = 4
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    scheduling_policy {
      preemptible = true
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.subnet-a.zone
    }
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true

    maintenance_window {
      start_time = "03:00"
      duration   = "3h"
    }
  }
}

# Создание Container Registry
resource "yandex_container_registry" "diploma-registry" {
  name      = "diploma-registry"
  folder_id = "b1gam4o6rj97es4peaq4"
}

# Outputs
output "cluster_id" {
  value = yandex_kubernetes_cluster.diploma-cluster.id
}

output "cluster_external_v4_endpoint" {
  value = yandex_kubernetes_cluster.diploma-cluster.master[0].external_v4_endpoint
}

output "registry_id" {
  value = yandex_container_registry.diploma-registry.id
}

