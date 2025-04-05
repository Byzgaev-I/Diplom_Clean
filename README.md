# Дипломный практикум в Yandex.Cloud
### Автор: Александр Бызгаев

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

## 1.2 Создание основной инфраструктуры

Далее я создал основную инфраструктуру, включая VPC с подсетями в разных зонах доступности:

### Создание директории для основной инфраструктуры
```bash
mkdir -p ~/diploma/Diplom_Byzgaev/terraform/infrastructure
cd ~/diploma/Diplom_Byzgaev/terraform/infrastructure
```
### Получение ключей доступа
```bash
ACCESS_KEY=$(cd ../service-account && terraform output terraform_access_key)
SECRET_KEY=$(cd ../service-account && terraform output -raw terraform_secret_key)
BUCKET_NAME=$(cd ../service-account && terraform output terraform_bucket_name)
```
### Создание файла provider.tf с бэкендом S3
```bash
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.140.0"
    }
  }
  
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket     = "${BUCKET_NAME}"
    region     = "ru-central1"
    key        = "terraform/infrastructure.tfstate"
    access_key = "${ACCESS_KEY}"
    secret_key = "${SECRET_KEY}"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
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

### Создание файла network.tf для VPC и подсетей
```bash
# Создание VPC сети
resource "yandex_vpc_network" "diploma-network" {
  name = "diploma-network"
}

# Создание подсетей в разных зонах доступности
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.diploma-network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_subnet" "subnet-b" {
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.diploma-network.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}

resource "yandex_vpc_subnet" "subnet-d" {
  name           = "subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.diploma-network.id
  v4_cidr_blocks = ["10.3.0.0/16"]
}
```

### Инициализация и применение Terraform
```bash
terraform init
terraform apply -auto-approve
```

Машины делал непрерываемые из-за того что я не так быстро делаю и постоянно откатывался назад, переделывая, а плюсом добавлялось еще и сброс ip и прочего каждые сутки, заставляя переписывать, путаться и т.д.   

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/1.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/2.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/3%20.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/4.png) 


## 2) Создание Kubernetes кластера

**На этом этапе я создал управляемый Kubernetes кластер в Яндекс.Облаке.**

### 2.1 Создание Kubernetes кластера

**- Создание файла kubernetes.tf**
```bash
# Сервисный аккаунт для Kubernetes кластера
resource "yandex_iam_service_account" "k8s-sa" {
  name        = "k8s-service-account"
  description = "Service account for Kubernetes cluster"
}

# Назначение необходимых ролей
resource "yandex_resourcemanager_folder_iam_member" "k8s-admin" {
  folder_id = "b1gam4o6rj97es4peaq4"
  role      = "editor"
  member    = "serviceAccount:\${yandex_iam_service_account.k8s-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s-images-puller" {
  folder_id = "b1gam4o6rj97es4peaq4"
  role      = "container-registry.images.puller"
  member    = "serviceAccount:\${yandex_iam_service_account.k8s-sa.id}"
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
      subnet_ids = ["\${yandex_vpc_subnet.subnet-a.id}"]
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
```

### Применение Terraform
```bash
terraform apply -auto-approve
```

### 2.2 Создание Kubernetes кластера
```bash
# Получение конфигурации для доступа к кластеру
CLUSTER_ID=$(terraform output -raw cluster_id)
yc managed-kubernetes cluster get-credentials --id $CLUSTER_ID --external
```
### Проверка доступа к кластеру
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/5%20доступ%20к%20кластеру.png)

## 3) Создание тестового приложения

**На этом этапе я подготовил тестовое приложение на базе Nginx, которое отдает статическую страницу.**

### 3.1 Создание приложения и Dockerfile

###Создание HTML-страницы
```bash
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>Дипломный проект - Byzgaev</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
            color: #333;
            line-height: 1.6;
        }
        .container {
            width: 80%;
            margin: 0 auto;
            overflow: hidden;
            padding: 20px;
        }
        header {
            background: #50b3a2;
            color: white;
            padding: 20px 0;
            text-align: center;
        }
        .content {
            margin-top: 20px;
            background: white;
            padding: 30px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            margin: 0;
        }
        footer {
            background: #333;
            color: white;
            text-align: center;
            padding: 10px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <header>
        <div class="container">
            <h1>Дипломный проект DevOps</h1>
        </div>
    </header>

    <div class="container">
        <div class="content">
            <h2>Тестовое приложение</h2>
            <p>Это тестовое приложение для дипломного проекта по DevOps инженеру.</p>
            <p>Проект включает:</p>
            <ul>
                <li>Облачная инфраструктура в Yandex.Cloud</li>
                <li>Kubernetes кластер</li>
                <li>Система мониторинга (Prometheus + Grafana)</li>
                <li>CI/CD пайплайн с GitHub Actions</li>
            </ul>
            <p>Hostname: <span id="hostname"></span></p>
            <p>Время сервера: <span id="server-time"></span></p>
        </div>
    </div>

    <footer>
        <div class="container">
            <p>&copy; 2025 Byzgaev</p>
        </div>
    </footer>

    <script>
        // Получаем и отображаем имя хоста
        fetch('/hostname')
            .then(response => response.text())
            .then(data => {
                document.getElementById('hostname').textContent = data;
            })
            .catch(error => {
                document.getElementById('hostname').textContent = 'Недоступно';
            });

        // Получаем и отображаем время сервера
        function updateTime() {
            const now = new Date();
            document.getElementById('server-time').textContent = now.toLocaleString();
        }
        updateTime();
        setInterval(updateTime, 1000);
    </script>
</body>
</html>
```

### Создание конфигурации Nginx
```bash
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /hostname {
        return 200 \$hostname;
    }

    location /status {
        stub_status on;
        access_log off;
        allow all;
    }
}
```

### Создание Dockerfile
```bash
FROM nginx:1.25.3-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY html /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### 3.2 Создание Kubernetes манифестов для приложения

### Создание Deployment
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: diploma-app
  labels:
    app: diploma-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: diploma-app
  template:
    metadata:
      labels:
        app: diploma-app
    spec:
      containers:
      - name: diploma-app
        image: cr.yandex/crpcpqg7ocu8m0jpricf/diploma-app:latest
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "0.2"
            memory: "128Mi"
          requests:
            cpu: "0.1"
            memory: "64Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Создание Service
```bash
apiVersion: v1
kind: Service
metadata:
  name: diploma-app
spec:
  selector:
    app: diploma-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### Создание Ingress
```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: diploma-app-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: diploma-app
            port:
              number: 80
```

### 3.3 Сборка и публикация Docker-образа

```bash
### Получение ID реестра
REGISTRY_ID=$(cd ~/diploma/Diplom_Byzgaev/terraform/infrastructure && terraform output -raw registry_id)

### Аутентификация в Container Registry
yc container registry configure-docker

### Сборка образа
docker build -t cr.yandex/${REGISTRY_ID}/diploma-app:latest .

### Отправка образа в реестр
docker push cr.yandex/${REGISTRY_ID}/diploma-app:latest
```

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/6%20Container%20Registri.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/7%20.png)

### Приложение доступно по адресу (http://84.201.170.235)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/8%20приложение%20.png)



## 4) Подготовка системы мониторинга и деплой приложения

**На этом этапе я развернул систему мониторинга (Prometheus, Grafana, Alertmanager) и тестовое приложение в Kubernetes кластере.**

### 4.1 Установка Ingress-контроллера

### Установка Helm 
```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```
```bash
# Установка Nginx Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/9Установка%20Nginx%20Ingress%20Controller.png) 

### 4.2 Установка системы мониторинга

### Добавление репозитория Prometheus
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```
### Установка Prometheus Stack
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```
### Создание LoadBalancer сервисов для доступа к Grafana и Prometheus
```bash
apiVersion: v1
kind: Service
metadata:
  name: grafana-lb
  namespace: monitoring
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
    name: grafana
  selector:
    app.kubernetes.io/name: grafana
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-lb
  namespace: monitoring
spec:
  type: LoadBalancer
  ports:
  - port: 9090
    targetPort: 9090
    name: prometheus
  selector:
    app.kubernetes.io/name: prometheus
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager-lb
  namespace: monitoring
spec:
  type: LoadBalancer
  ports:
  - port: 9093
    targetPort: 9093
    name: alertmanager
  selector:
    app.kubernetes.io/name: alertmanager
```

### - Тестовое приложение по адресу: http://84.201.170.235/
### - Grafana по адресу: http://51.250.44.102:3000 (логин: admin, пароль: admin)
### - Prometheus и Alertmanager доступны через port-forward


![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/10.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/11%20prometeus.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/Снимок%20экрана%202025-04-05%20в%2001.01.16.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/12%20Alertmanager.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/13%20grafana.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/14.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/15%20namespace.png) 

### 4.3 Деплой тестового приложения
```bash
# Деплой приложения в Kubernetes

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Проверка статуса развёртывания
kubectl get pods
kubectl get services
kubectl get ingress
```

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/16%20lДеплой%20приложения%20в%20куб.png) 


## 5) Установка и настройка CI/CD

На этом этапе я настроил CI/CD систему для автоматической сборки Docker-образа и деплоя приложения при изменении кода.

### 5.1 Создание сервисного аккаунта для CI/CD
```bash
# Создание сервисного аккаунта для CI/CD
yc iam service-account create --name ci-cd-sa --description "Service account for CI/CD"

# Получение ID сервисного аккаунта
SA_ID=$(yc iam service-account get ci-cd-sa --format json | jq -r .id)

# Назначение роли container-registry.images.pusher
yc resource-manager folder add-access-binding --id b1gam4o6rj97es4peaq4 \
  --role container-registry.images.pusher \
  --subject serviceAccount:$SA_ID

# Создание ключа для сервисного аккаунта
yc iam key create --service-account-id $SA_ID --output ci-cd-sa-key.json
```

### 5.2 Настройка GitHub Actions


###Создание файла workflow
```bash
name: Build and Deploy

on:
  push:
    branches: [ main ]
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v1

    - name: Login to Yandex Container Registry
      run: |
        echo '\${{ secrets.YC_SA_JSON_KEY }}' > key.json
        cat key.json | docker login --username json_key --password-stdin cr.yandex

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v3
      with:
        images: cr.yandex/crpcpqg7ocu8m0jpricf/diploma-app
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}

    - name: Build and push Docker image
      uses: docker/build-push-action@v2
      with:
        context: ./app
        push: true
        tags: \${{ steps.meta.outputs.tags }}
        labels: \${{ steps.meta.outputs.labels }}

  deploy:
    needs: build
    if: startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Install kubectl
      uses: azure/setup-kubectl@v1
      with:
        version: 'latest'

    - name: Setup Yandex Cloud CLI
      run: |
        curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash -s -- -i /opt/yandex-cloud -n
        echo 'export PATH="/opt/yandex-cloud/bin:\$PATH"' >> ~/.bashrc
        source ~/.bashrc
        yc version
        
    - name: Setup Kubernetes Config with YC CLI
      run: |
        echo '\${{ secrets.YC_SA_JSON_KEY }}' > sa-key.json
        yc config profile create diploma
        yc config set service-account-key sa-key.json
        yc config set cloud-id b1g31ab21b32dog1ps4c
        yc config set folder-id b1gam4o6rj97es4peaq4
        
        CLUSTER_ID="cat1nctjnphlusq7si6k"
        yc managed-kubernetes cluster get-credentials --id \$CLUSTER_ID --external
        
        kubectl cluster-info
        kubectl get nodes

    - name: Deploy to Kubernetes
      run: |
        VERSION=\${GITHUB_REF#refs/tags/v}
        sed -i "s|cr.yandex/crpcpqg7ocu8m0jpricf/diploma-app:latest|cr.yandex/crpcpqg7ocu8m0jpricf/diploma-app:\${VERSION}|g" app/k8s/deployment.yaml
        kubectl apply -f app/k8s/deployment.yaml --validate=false
        kubectl apply -f app/k8s/service.yaml --validate=false
        kubectl apply -f app/k8s/ingress.yaml --validate=false
```


### 5.3 Тестирование CI/CD пайплайна

**Успешное выполнение CI/CD пайплайна**

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/Снимок%20экрана%202025-04-05%20в%2001.26.01.png)

![image](https://github.com/Byzgaev-I/Diplom_Clean/blob/main/17%20test%20CI%20Cd%20.png) 



## 6) Результаты

### В результате выполнения дипломного проекта я успешно создал:

- Облачную инфраструктуру в Яндекс.Облаке с использованием Terraform
- Кластер Kubernetes с группой узлов
- Тестовое приложение на базе Nginx с Dockerfile
- Систему мониторинга с Prometheus, Grafana и Alertmanager
- CI/CD пайплайн с использованием GitHub Actions

### 6.1 Ссылки на рабочие сервисы

### Тестовое приложение: http://84.201.170.235/
### Grafana: http://51.250.44.102:3000 (логин: admin, пароль: admin)
### CI/CD интерфейс: https://github.com/Byzgaev-I/Diplom_Clean/actions
































