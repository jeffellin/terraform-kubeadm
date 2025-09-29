output "master_private_ip" {
  description = "Private IP address of the Kubernetes master node"
  value       = aws_instance.k8s_master[0].private_ip
}

output "master_public_ip" {
  description = "Public IP address of the Kubernetes master node"
  value       = aws_instance.k8s_master[0].public_ip
}

output "worker_private_ips" {
  description = "Private IP addresses of the Kubernetes worker nodes"
  value       = aws_instance.k8s_worker[*].private_ip
}

output "worker_public_ips" {
  description = "Public IP addresses of the Kubernetes worker nodes"
  value       = aws_instance.k8s_worker[*].public_ip
}

output "master_instance_id" {
  description = "EC2 instance ID of the master node"
  value       = aws_instance.k8s_master[0].id
}

output "worker_instance_ids" {
  description = "EC2 instance IDs of the worker nodes"
  value       = aws_instance.k8s_worker[*].id
}

output "cluster_endpoint" {
  description = "Kubernetes cluster API endpoint"
  value       = "https://${aws_instance.k8s_master[0].private_ip}:6443"
}

output "ssh_command_master" {
  description = "SSH command to connect to the master node"
  value       = "ssh -i ~/.ssh/your-key ubuntu@${aws_instance.k8s_master[0].public_ip}"
}

output "ssh_commands_workers" {
  description = "SSH commands to connect to worker nodes"
  value       = [for ip in aws_instance.k8s_worker[*].public_ip : "ssh -i ~/.ssh/your-key ubuntu@${ip}"]
}

output "security_group_master_id" {
  description = "Security group ID for the master node"
  value       = aws_security_group.k8s_master.id
}

output "security_group_worker_id" {
  description = "Security group ID for the worker nodes"
  value       = aws_security_group.k8s_worker.id
}