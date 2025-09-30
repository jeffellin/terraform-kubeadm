#!/bin/bash
set -e

echo "Installing external-dns..."

# Create namespace
kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -

# Create ServiceAccount, ClusterRole, and ClusterRoleBinding
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: external-dns
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services","endpoints","pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions","networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: external-dns
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
        - name: external-dns
          image: k8s.gcr.io/external-dns/external-dns:v0.14.0
          args:
            - --provider=aws
            - --registry=txt
            - --txt-owner-id=external-dns
            # zone ID from configmap env var
            - --zone-id-filter=$(ROUTE53_ZONE_ID)
          env:
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: aws-credentials
                  key: access-key-id
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: aws-credentials
                  key: secret-access-key
            - name: AWS_REGION
              value: us-east-1   # adjust if needed
            - name: ROUTE53_ZONE_ID
              valueFrom:
                configMapKeyRef:
                  name: external-dns-config
                  key: zone-id
EOF

echo ""
echo "external-dns installation complete!"
echo ""
echo "IMPORTANT: Before external-dns can work:"
echo "  1. Create AWS credentials secret: ../secrets/create-aws-secret.sh"
echo "  2. Edit the deployment to replace 'example.com' with your actual domain"
echo ""
echo "To verify the installation:"
echo "  kubectl get pods -n external-dns"
echo "  kubectl logs -n external-dns -l app=external-dns"