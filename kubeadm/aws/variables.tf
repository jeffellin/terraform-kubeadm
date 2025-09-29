variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-west-2"
}

variable "vpc_id" {
  description = "VPC ID where EC2 instances will be created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where EC2 instances will be created"
  type        = string
}

variable "cluster_name" {
  description = "Name prefix for the Kubernetes cluster resources"
  type        = string
  default     = "k8s-cluster"
}

variable "master_instance_type" {
  description = "EC2 instance type for the Kubernetes master node"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for the Kubernetes worker nodes"
  type        = string
  default     = "t3.small"
}

variable "master_disk_size" {
  description = "Root disk size in GB for the master node"
  type        = number
  default     = 20
}

variable "worker_disk_size" {
  description = "Root disk size in GB for the worker nodes"
  type        = number
  default     = 20
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes to create"
  type        = number
  default     = 2
}

variable "master_private_ip" {
  description = "Private IP address for the Kubernetes master node (must be within subnet CIDR)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for accessing EC2 instances"
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR block allowed to access the cluster via SSH and API"
  type        = string
  default     = "0.0.0.0/0"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "kubernetes"
    ManagedBy   = "terraform"
  }
}