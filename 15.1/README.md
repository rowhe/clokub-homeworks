# Домашнее задание к занятию "15.1. Организация сети"

Домашнее задание будет состоять из обязательной части, которую необходимо выполнить на провайдере Яндекс.Облако и дополнительной части в AWS по желанию. Все домашние задания в 15 блоке связаны друг с другом и в конце представляют пример законченной инфраструктуры.  
Все задания требуется выполнить с помощью Terraform, результатом выполненного домашнего задания будет код в репозитории. 

Перед началом работ следует настроить доступ до облачных ресурсов из Terraform используя материалы прошлых лекций и [ДЗ](https://github.com/netology-code/virt-homeworks/tree/master/07-terraform-02-syntax ). А также заранее выбрать регион (в случае AWS) и зону.

---
## Задание 1. Яндекс.Облако (обязательное к выполнению)

1. Создать VPC.
- Создать пустую VPC. Выбрать зону.

  * Подготовим конфигурацию `terraform` для Yandex.Cloud создав файл main.tf
  * Укажем используемый провайдер

```shell
terraform {
  required_providers {
    yandex = { source = "yandex-cloud/yandex" }
  }
  required_version = ">= 0.13"
}
```

  * Теперь можно доваить VPC:

```shell
resource "yandex_vpc_network" "diploma" {
  name = "diploma-net"
}
```

2. Публичная подсеть.
- Создать в vpc subnet с названием public, сетью 192.168.10.0/24.
- Создать в этой подсети NAT-инстанс, присвоив ему адрес 192.168.10.254. В качестве image_id использовать fd80mrhj8fl2oe87o4e1
- Создать в этой публичной подсети виртуалку с публичным IP и подключиться к ней, убедиться что есть доступ к интернету.

  * Добавляем блок публичной подсети:

```shell
resource "yandex_vpc_subnet" "public" {
  name = "public-subnet"
  v4_cidr_blocks = ["192.168.10.0/24"]
  zone = "ru-central1-a"
  network_id = "${yandex_vpc_network.diploma.id}"
  description = "public subnet for diploma purposes"
  route_table_id = "${yandex_vpc_route_table.diploma-private.id}"
}
```

  * Добавим NAT инстанс:
  * Не забудем присвоить ему публичный айпи, иначе не будет работать интернет в приватной подсети 192.168.20.0/24

```shell
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
```

  * Создадим дополнительную ВМ с публичным айпи

```shell
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
```

3. Приватная подсеть.
- Создать в vpc subnet с названием private, сетью 192.168.20.0/24.

  * Создаем приватную сеть 192.168.20.0/24

```shell
resource "yandex_vpc_subnet" "private" {
  name = "private-subnet"
  v4_cidr_blocks = ["192.168.20.0/24"]
  zone = "ru-central1-a"
  network_id = "${yandex_vpc_network.diploma.id}"
  description = "private subnet for diploma purposes"
  route_table_id = "${yandex_vpc_route_table.diploma-private.id}"
  }
```

- Создать route table. Добавить статический маршрут, направляющий весь исходящий трафик private сети в NAT-инстанс

  * Создаем таблицу маршрутизации для подсети `diploma-private`
```shell
resource "yandex_vpc_route_table" "diploma-private" {
  network_id = "${yandex_vpc_network.diploma.id}"
    static_route {
      destination_prefix = "0.0.0.0/0"
      next_hop_address = "192.168.10.254"
    }
}
```
- Создать в этой приватной подсети виртуалку с внутренним IP, подключиться к ней через виртуалку, созданную ранее и убедиться что есть доступ к интернету

  * Создадим ВМ в подсети `private`

```shell
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
```

  * Подключимся к созданным ВМ при помощи хоста-бастиона. Для этого нужно сконфигурировать ssh на локальной машине
  * Выясним внешние айпи созданным вм в облаке яндекса

```shell
$ yc compute instance list
+----------------------+---------------------+---------------+---------+----------------+----------------+
|          ID          |        NAME         |    ZONE ID    | STATUS  |  EXTERNAL IP   |  INTERNAL IP   |
+----------------------+---------------------+---------------+---------+----------------+----------------+
| fhmcoucndj9r24iv8pe0 | pub-host1-instance  | ru-central1-a | RUNNING | 130.193.49.202 | 192.168.10.10  |
| fhmeg7d8mh1qpi1gq8bi | priv-host1-instance | ru-central1-a | RUNNING |                | 192.168.20.20  |
| fhmqnpidskugp6fbi9ut | nat-instance        | ru-central1-a | RUNNING | 158.160.34.177 | 192.168.10.254 |
+----------------------+---------------------+---------------+---------+----------------+----------------+

```

  * Теперь добавим конфигурацию в .ssh/config

```shell
$ cat .ssh/config
Host 192.168.10.10  !130.193.49.202
  User ubuntu
  ProxyCommand ssh ubuntu@130.193.49.202 -W %h:%p

Host 192.168.20.20  !130.193.49.202
  User ubuntu
  ProxyCommand ssh ubuntu@130.193.49.202 -W %h:%p


Host 192.168.10.254  !130.193.49.202
  User ubuntu
  ProxyCommand ssh ubuntu@130.193.49.202 -W %h:%p

```

  * Теперь подключимся к каждой ВМ и проверим работу интернет:
  * Подключаемся к 192.168.10.10

```shell
$ ssh 192.168.10.10
The authenticity of host '192.168.10.10 (<no hostip for proxy command>)' can't be established.
ED25519 key fingerprint is SHA256:xi9/ke6cRWmDlP+H1RDaZxh6JIO+W/yQsK5wHs+vGt4.
This host key is known by the following other names/addresses:
    ~/.ssh/known_hosts:33: 130.193.49.202
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.10.10' (ED25519) to the list of known hosts.

ubuntu@fhmcoucndj9r24iv8pe0:~$ ping mail.ru
PING mail.ru (217.69.139.200) 56(84) bytes of data.
64 bytes from mail.ru (217.69.139.200): icmp_seq=1 ttl=57 time=53.4 ms
64 bytes from mail.ru (217.69.139.200): icmp_seq=2 ttl=57 time=66.7 ms
^C
--- mail.ru ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 53.395/60.048/66.701/6.653 ms
```

  * Теперь подключимся к 192.168.10.254

```shell
$ ssh 192.168.10.254
The authenticity of host '192.168.10.254 (<no hostip for proxy command>)' can't be established.
ED25519 key fingerprint is SHA256:1mCuUV4c7b6uFaziyUOCx3jkSmH6z/7bgkjlAz2JriQ.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.10.254' (ED25519) to the list of known hosts.

ubuntu@fhmqnpidskugp6fbi9ut:~$ ping mail.ru
PING mail.ru (94.100.180.201) 56(84) bytes of data.
64 bytes from mail.ru (94.100.180.201): icmp_seq=1 ttl=58 time=53.7 ms
64 bytes from mail.ru (94.100.180.201): icmp_seq=2 ttl=58 time=52.6 ms
^C
--- mail.ru ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 52.631/53.199/53.767/0.568 ms
```

  * Теперь проверим доступность интернета для ВМ из приватной сети (ВМ без публичного айпи)

```shell
$ ssh 192.168.20.20
The authenticity of host '192.168.20.20 (<no hostip for proxy command>)' can't be established.
ED25519 key fingerprint is SHA256:NLkgD7htq3J9ZUtOm/ka5yUyvEkiYZw5TkgkFM9DrWU.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.20.20' (ED25519) to the list of known hosts.

ubuntu@fhmeg7d8mh1qpi1gq8bi:~$ ping mail.ru
PING mail.ru (94.100.180.200) 56(84) bytes of data.
64 bytes from mail.ru (94.100.180.200): icmp_seq=1 ttl=56 time=51.3 ms
64 bytes from mail.ru (94.100.180.200): icmp_seq=2 ttl=56 time=52.3 ms
64 bytes from mail.ru (94.100.180.200): icmp_seq=3 ttl=56 time=51.4 ms
^C
--- mail.ru ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 51.328/51.649/52.252/0.426 ms
```

  * Как можно видет все ВМ имеют доступ в интернет. Задание выполнено
  * Полный файл конфигурации `terraform` [main.tf](./infrastructure/terraform/main.tf)

Resource terraform для ЯО
- [VPC subnet](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_subnet)
- [Route table](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_route_table)
- [Compute Instance](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/compute_instance)
---
## Задание 2*. AWS (необязательное к выполнению)

1. Создать VPC.
- Cоздать пустую VPC с подсетью 10.10.0.0/16.
2. Публичная подсеть.
- Создать в vpc subnet с названием public, сетью 10.10.1.0/24
- Разрешить в данной subnet присвоение public IP по-умолчанию. 
- Создать Internet gateway 
- Добавить в таблицу маршрутизации маршрут, направляющий весь исходящий трафик в Internet gateway.
- Создать security group с разрешающими правилами на SSH и ICMP. Привязать данную security-group на все создаваемые в данном ДЗ виртуалки
- Создать в этой подсети виртуалку и убедиться, что инстанс имеет публичный IP. Подключиться к ней, убедиться что есть доступ к интернету.
- Добавить NAT gateway в public subnet.
3. Приватная подсеть.
- Создать в vpc subnet с названием private, сетью 10.10.2.0/24
- Создать отдельную таблицу маршрутизации и привязать ее к private-подсети
- Добавить Route, направляющий весь исходящий трафик private сети в NAT.
- Создать виртуалку в приватной сети.
- Подключиться к ней по SSH по приватному IP через виртуалку, созданную ранее в публичной подсети и убедиться, что с виртуалки есть выход в интернет.

Resource terraform
- [VPC](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)
- [Subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)
- [Internet Gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway)
