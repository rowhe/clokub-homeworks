terraform {
  required_providers {
    yandex = { source = "yandex-cloud/yandex" }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
    token               = ""
    cloud_id            = ""
    folder_id           = ""
    zone                = ""
}

resource "yandex_vpc_network" "diploma2023" {
    name                = "diploma2023-network"
}