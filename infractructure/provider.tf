terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  service_account_key_file = "${path.module}/key.json"
  ymq_access_key = var.ymq_access_key
  ymq_secret_key = var.ymq_secret_key
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}