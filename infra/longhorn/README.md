# Longhorn Distributed Storage

Longhorn provides distributed block storage for Kubernetes using local disks on each node.

## Installation

```bash
./install.sh
```

## Features

- Distributed storage across all nodes
- Replication for high availability
- Snapshots and backups
- Web UI for management
- Dynamic volume provisioning

## Requirements

- `open-iscsi` installed on all nodes (already included in install-k8s-common.sh)
- At least 5GB free space on each node

## Usage

After installation, create a PVC using the `longhorn` storage class:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
```

## Accessing the UI

```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

Then open http://localhost:8080

## Set as Default Storage Class

```bash
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```