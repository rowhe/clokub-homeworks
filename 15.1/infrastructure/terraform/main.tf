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