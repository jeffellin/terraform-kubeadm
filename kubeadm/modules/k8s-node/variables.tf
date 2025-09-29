variable "node_type" {
  description = "Type of node: master or worker"
  type        = string
  validation {
    condition     = contains(["master", "worker"], var.node_type)
    error_message = "Node type must be either 'master' or 'worker'."
  }
}

variable "master_ip" {
  description = "IP address of the master node"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s-cluster"
}