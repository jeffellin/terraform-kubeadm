#!/bin/bash

# Download and run shared scripts
curl -fsSL https://raw.githubusercontent.com/jeffellin/terraform-kubeadm/main/kubeadm/shared/install-k8s-common.sh | bash

# Run master initialization
curl -fsSL https://raw.githubusercontent.com/jeffellin/terraform-kubeadm/main/kubeadm/shared/init-k8s-master.sh | bash -s -- "${master_ip}" "${cluster_name}"

# Create a simple script to retrieve the join command
cat > /home/ubuntu/get-join-command.sh <<EOF
#!/bin/bash
cat /tmp/join-command
EOF
chmod +x /home/ubuntu/get-join-command.sh
chown ubuntu:ubuntu /home/ubuntu/get-join-command.sh

# Wait for the cluster to be ready
sleep 60

# Create admin service account for dashboard access (optional)
cat > /tmp/admin-user.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Log completion
echo "Kubernetes master initialization completed at $(date)" >> /var/log/k8s-init.log