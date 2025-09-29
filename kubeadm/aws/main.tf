terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "k8s" {
  key_name   = "${var.cluster_name}-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "k8s_master" {
  name_prefix = "${var.cluster_name}-master-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    from_port   = 10250
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-master-sg"
    Role = "master"
  })
}

resource "aws_security_group" "k8s_worker" {
  name_prefix = "${var.cluster_name}-worker-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-worker-sg"
    Role = "worker"
  })
}

resource "aws_instance" "k8s_master" {
  count                  = 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_instance_type
  key_name               = aws_key_pair.k8s.key_name
  vpc_security_group_ids = [aws_security_group.k8s_master.id]
  subnet_id              = var.subnet_id
  private_ip             = var.master_private_ip

  root_block_device {
    volume_type = "gp3"
    volume_size = var.master_disk_size
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data-master.sh", {
    cluster_name = var.cluster_name
    master_ip    = var.master_private_ip
  }))

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-master-${count.index + 1}"
    Role = "master"
    Type = "kubernetes"
  })
}

resource "aws_instance" "k8s_worker" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.k8s.key_name
  vpc_security_group_ids = [aws_security_group.k8s_worker.id]
  subnet_id              = var.subnet_id

  root_block_device {
    volume_type = "gp3"
    volume_size = var.worker_disk_size
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data-worker.sh", {
    master_ip = aws_instance.k8s_master[0].private_ip
  }))

  depends_on = [aws_instance.k8s_master]

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
    Type = "kubernetes"
  })
}