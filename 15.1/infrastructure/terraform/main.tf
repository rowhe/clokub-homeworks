terraform {
  required_providers {
    yandex = { source = "yandex-cloud/yandex" }
  }
  required_version = ">= 0.13"
}

resource "yandex_vpc_network" "diploma" {
  name = "diploma-net"
}

resource "yandex_vpc_subnet" "public" {
  name = "public-subnet"
  v4_cidr_blocks = ["192.168.10.0/24"]
  zone = "ru-central1-a"
  network_id = "${yandex_vpc_network.diploma.id}"
  description = "public subnet for diploma purposes"
  }

resource "yandex_vpc_subnet" "private" {
  name = "private-subnet"
  v4_cidr_blocks = ["192.168.20.0/24"]
  zone = "ru-central1-a"
  network_id = "${yandex_vpc_network.diploma.id}"
  description = "private subnet for diploma purposes"
  route_table_id = "${yandex_vpc_route_table.diploma-private.id}"
  }

resource "yandex_vpc_route_table" "diploma-private" {
  network_id = "${yandex_vpc_network.diploma.id}"
    static_route {
      destination_prefix = "0.0.0.0/0"
      next_hop_address = "192.168.10.254"
    }
}

resource "yandex_compute_instance" "nat" {
  name = "nat-instance"
  zone = "ru-central1-a"
  allow_stopping_for_update = true
  scheduling_policy {
    preemptible = true
  }

  resources {
    cores = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.public.id}"
    ip_address = "192.168.10.254"
    nat = true
    }

   metadata = {
  ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "pub-host1" {
  name = "pub-host1-instance"
  zone = "ru-central1-a"
  allow_stopping_for_update = true
  scheduling_policy {
    preemptible = true
  }
  resources {
    cores = 2
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = "fd864gbboths76r8gm5f"
    }
  }
  network_interface {
    subnet_id = "${yandex_vpc_subnet.public.id}"
    ip_address = "192.168.10.10"
    nat = true
  }
  metadata = {
  ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "priv-host1" {
  name = "priv-host1-instance"
  zone = "ru-central1-a"
  allow_stopping_for_update = true
  scheduling_policy {
    preemptible = true
  }
  resources {
    cores = 2
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = "fd864gbboths76r8gm5f"
    }
  }
  network_interface {
    subnet_id = "${yandex_vpc_subnet.private.id}"
    ip_address = "192.168.20.20"
    }
  metadata = {
  ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

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