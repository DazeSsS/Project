# Создание сетей и подсетей

resource "yandex_vpc_network" "aikido-network" {
  name = "aikido-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  name           = "aikido-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.aikido-network.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

resource "yandex_vpc_subnet" "subnet-b" {
  name           = "aikido-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.aikido-network.id
  v4_cidr_blocks = ["192.168.2.0/24"]
}

resource "yandex_vpc_subnet" "subnet-d" {
  name           = "aikido-subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.aikido-network.id
  v4_cidr_blocks = ["192.168.3.0/24"]
}


# Создание сервисных аккаунтов

resource "yandex_iam_service_account" "storage-sa" {
  name        = "storage-sa"
}

resource "yandex_iam_service_account" "queue-sa" {
  name        = "queue-sa"
}


# Назначение ролей

resource "yandex_resourcemanager_folder_iam_member" "storage-editor" {
  folder_id  = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.storage-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "queue-admin" {
  folder_id  = var.yc_folder_id
  role      = "ymq.admin"
  member    = "serviceAccount:${yandex_iam_service_account.queue-sa.id}"
}


# Создание ключей доступа

resource "yandex_iam_service_account_static_access_key" "storage-sa-key" {
  service_account_id = yandex_iam_service_account.storage-sa.id
}

resource "yandex_iam_service_account_static_access_key" "queue-sa-key" {
  service_account_id = yandex_iam_service_account.queue-sa.id
}


# Создание бакета

resource "yandex_storage_bucket" "aikido-bucket" {
  bucket     = var.bucket_name
  acl        = "public-read"
}


# Загрузка дефолтного изображения в бакет

resource "yandex_storage_object" "profile-img" {
  bucket = var.bucket_name
  key    = "default/profile.png"
  source = "${path.module}/profile.png"

  depends_on = [yandex_storage_bucket.aikido-bucket]
}


# Создание кластера PostgreSQL

resource "yandex_mdb_postgresql_cluster" "aikido-postgres" {
  name        = "aikido-postgres-cluster"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.aikido-network.id

  config {
    version = 15
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 20
    }

    access {
      web_sql = true
    }
  }

  host {
    zone      = "ru-central1-d"
    subnet_id = yandex_vpc_subnet.subnet-d.id
    assign_public_ip = true
  }
}


# Пользователь БД

resource "yandex_mdb_postgresql_user" "aikido-admin" {
  cluster_id = yandex_mdb_postgresql_cluster.aikido-postgres.id
  name       = var.postgres_user
  password   = var.postgres_user_password
}


# Настройка прав доступа к БД

resource "yandex_mdb_postgresql_database" "aikido-db" {
  cluster_id = yandex_mdb_postgresql_cluster.aikido-postgres.id
  name       = "aikido-db"
  owner      = yandex_mdb_postgresql_user.aikido-admin.name
}


# Создание очереди

resource "yandex_message_queue" "email-queue" {
  name = "email-messages"
  visibility_timeout_seconds = 30
  message_retention_seconds = 86400
  receive_wait_time_seconds  = 20
}


# Создание функции для отправки сообщений

resource "yandex_function" "email-sender" {
  name               = "email-sender"
  user_hash          = "number1"
  runtime            = "python312"
  entrypoint         = "main.handler"
  memory             = 128
  execution_timeout  = 10
  environment = {
    EMAIL_HOST     = var.email_host
    EMAIL_PORT     = var.email_port
    EMAIL_USER     = var.email_user
    EMAIL_PASSWORD = var.email_password
  }
  content {
    zip_filename = "${path.module}/smtp_service/function.zip"
  }
}


# Создание триггера для очереди

resource "yandex_function_trigger" "email-queue-trigger" {
  name = "email-queue-trigger"
  message_queue {
    queue_id = yandex_message_queue.email-queue.arn
    service_account_id = yandex_iam_service_account.queue-sa.id
    batch_size = 1
    batch_cutoff = 10
  }
  function {
    id = yandex_function.email-sender.id
    service_account_id = var.service_account_id
  }
}


# Создание Instance Group

resource "yandex_compute_instance_group" "aikido-ig" {
  name               = "aikido-ig"
  service_account_id = var.service_account_id

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      initialize_params {
        image_id = "fd87vmd9vdkri77eb4n6" # Container Optimized Image
        type     = "network-hdd"
        size     = 15
      }
    }

    network_interface {
      subnet_ids = [
        yandex_vpc_subnet.subnet-a.id,
        yandex_vpc_subnet.subnet-b.id,
        yandex_vpc_subnet.subnet-d.id
      ]
      nat        = true
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
      user-data = templatefile("${path.module}/cloud-init.yml", {
        django_secret = var.django_secret
        debug = var.debug
        admin_email = var.admin_email
        admin_password = var.admin_password
        email_user = var.email_user
        postgres_password = yandex_mdb_postgresql_user.aikido-admin.password
        postgres_user = yandex_mdb_postgresql_user.aikido-admin.name
        postgres_db = yandex_mdb_postgresql_database.aikido-db.name
        postgres_host = yandex_mdb_postgresql_cluster.aikido-postgres.host[0].fqdn
        ymq_access_key = yandex_iam_service_account_static_access_key.queue-sa-key.access_key
        ymq_secret_key = yandex_iam_service_account_static_access_key.queue-sa-key.secret_key
        ymq_queue_url = yandex_message_queue.email-queue.id
        aws_access_key = yandex_iam_service_account_static_access_key.storage-sa-key.access_key
        aws_secret_key = yandex_iam_service_account_static_access_key.storage-sa-key.secret_key
        aws_bucket_name = yandex_storage_bucket.aikido-bucket.bucket
        external_ip = "$(curl -H Metadata-Flavor:Google http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
      })
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = ["ru-central1-a", "ru-central1-b", "ru-central1-d"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion = 0
  }

  load_balancer {
    target_group_name = "aikido-tg"
  }
}


# Балансировщик нагрузки

resource "yandex_lb_network_load_balancer" "aikido-lb" {
  name = "aikido-lb"

  listener {
    name = "frontend-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  listener {
    name = "backend-listener"
    port = 8000
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.aikido-ig.load_balancer.0.target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}