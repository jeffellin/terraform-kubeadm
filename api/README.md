# WordPress User Stats API

A Go web service that queries WordPress database to retrieve user post statistics.

## Setup

1. Install dependencies:
```bash
go get github.com/go-sql-driver/mysql
```

2. Configure environment variables (copy `.env.example` to `.env`):
```bash
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=wordpress
DB_TABLE_PREFIX=wp_
PORT=8080
```

3. Run the service:
```bash
go run wordpress-stats.go
```

## Docker

### Build the image:
```bash
docker build -t wordpress-stats-api .
```

### Run the container:
```bash
docker run -d \
  -p 8080:8080 \
  -e DB_HOST=your_db_host \
  -e DB_PORT=3306 \
  -e DB_USER=root \
  -e DB_PASSWORD=your_password \
  -e DB_NAME=wordpress \
  -e DB_TABLE_PREFIX=wp_ \
  --name wordpress-stats \
  wordpress-stats-api
```

### Using Docker Compose:
```bash
docker-compose up -d
```

## Kubernetes

### Deploy to Kubernetes:

1. Update the secret with your database credentials:
```bash
# Edit k8s-secret.yaml with your actual database credentials
kubectl apply -f k8s-secret.yaml
```

2. Apply the ConfigMap:
```bash
kubectl apply -f k8s-configmap.yaml
```

3. Deploy the application:
```bash
kubectl apply -f k8s-deployment.yaml
```

4. Create the LoadBalancer service:
```bash
kubectl apply -f k8s-service.yaml
```

5. Get the external IP:
```bash
kubectl get service wordpress-stats-api
```

### Deploy all at once:
```bash
# Option 1: Use individual files
kubectl apply -f k8s-secret.yaml -f k8s-configmap.yaml -f k8s-deployment.yaml -f k8s-service.yaml

# Option 2: Use combined manifest (remember to edit database credentials first!)
kubectl apply -f k8s-all.yaml
```

### Check deployment status:
```bash
kubectl get pods -l app=wordpress-stats-api
kubectl logs -l app=wordpress-stats-api
```

## API Endpoints

### GET /api/userinfo

Returns WordPress user post statistics.

**Query Parameters:**
- `user` (optional): Username to query. If omitted, returns all users.

**Examples:**

Get all users:
```bash
curl http://localhost:8080/api/userinfo
```

Get specific user:
```bash
curl http://localhost:8080/api/userinfo?user=admin
```

**Response Format:**
```json
[
  {
    "username": "admin",
    "post_count": 42,
    "last_post_title": "Latest Post Title"
  },
  {
    "username": "editor",
    "post_count": 15,
    "last_post_title": "Another Post"
  }
]
```

## Notes

- Only published posts are counted
- Results are sorted by post count (descending)
- Returns empty string for `last_post_title` if user has no posts
