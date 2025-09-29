output "install_commands" {
  description = "Commands to install Kubernetes on this node"
  value = var.node_type == "master" ? [
    "chmod +x /tmp/scripts/*.sh",
    "/tmp/scripts/install-k8s-common.sh",
    "/tmp/scripts/init-k8s-master.sh ${var.master_ip} ${var.cluster_name}"
  ] : [
    "chmod +x /tmp/scripts/*.sh",
    "/tmp/scripts/install-k8s-common.sh",
    "sleep 60",
    "/tmp/scripts/join-k8s-worker.sh ${var.master_ip}"
  ]
}