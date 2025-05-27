variable "yc_folder_id" {
  type  = string
}

variable "yc_cloud_id" {
  type  = string
}

variable "yc_zone" {
  type  = string
}

variable "ymq_access_key" {
  type  = string
  sensitive = true
}

variable "ymq_secret_key" {
  type  = string
  sensitive = true
}

variable "service_account_id" {
  type = string
  sensitive = true
}

variable "bucket_name" {
  type  = string
}

variable "postgres_user" {
  type  = string
}

variable "postgres_user_password" {
  type  = string
  sensitive = true
}

variable "django_secret" {
  type  = string
}

variable "debug" {
  type  = string
}

variable "admin_email" {
  type  = string
}

variable "admin_password" {
  type  = string
  sensitive = true
}

variable "email_host" {
  type  = string
  default = "smtp.yandex.ru"
}

variable "email_port" {
  type  = number
  default = 465
}

variable "email_user" {
  type  = string
}

variable "email_password" {
  type  = string
  sensitive = true
}