# Cloud Provider Configuration Guide

This guide provides detailed configuration instructions for running the FreeBSD Docker environment on various cloud platforms.

## Table of Contents
- [AWS (Amazon Web Services)](#aws-amazon-web-services)
- [Google Cloud Platform](#google-cloud-platform)
- [Replit](#replit)
- [Azure](#azure)
- [DigitalOcean](#digitalocean)

## Prerequisites

All cloud deployments require:
- Docker installed on the host
- Cloud provider CLI tools (installed automatically in container)
- Appropriate cloud provider credentials

## AWS (Amazon Web Services)

### EC2 Deployment

1. **Launch EC2 Instance**:
```bash
# Using AWS CLI
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \  # Ubuntu 22.04 LTS
  --instance-type t3.xlarge \
  --key-name your-key \
  --security-group-ids sg-xxxxxx \
  --user-data file://aws-userdata.sh
```

2. **User Data Script** (`aws-userdata.sh`):
```bash
#!/bin/bash
# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

# Clone and run FreeBSD Docker
git clone https://github.com/aygp-dr/freebsd-docker
cd freebsd-docker
docker-compose up -d
```

3. **ECS Deployment**:
```yaml
# task-definition.json
{
  "family": "freebsd-dev",
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskRole",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsExecutionRole",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "4096",
  "memory": "8192",
  "containerDefinitions": [{
    "name": "freebsd",
    "image": "ghcr.io/aygp-dr/freebsd:14.3-RELEASE",
    "essential": true,
    "privileged": true,
    "portMappings": [
      {"containerPort": 22, "protocol": "tcp"},
      {"containerPort": 8080, "protocol": "tcp"}
    ]
  }]
}
```

4. **AWS Credentials Configuration**:
```bash
# Inside container
aws configure
# Or use environment variables
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=us-west-2
```

### EKS Deployment

```bash
# Create EKS cluster
eksctl create cluster \
  --name freebsd-cluster \
  --version 1.28 \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.xlarge \
  --nodes 3

# Deploy FreeBSD
kubectl apply -f k8s/freebsd-deployment.yaml
```

## Google Cloud Platform

### Compute Engine Deployment

1. **Create VM with Container**:
```bash
gcloud compute instances create-with-container freebsd-vm \
  --container-image=ghcr.io/aygp-dr/freebsd:14.3-RELEASE \
  --machine-type=n2-standard-4 \
  --zone=us-central1-a \
  --container-privileged \
  --container-mount-host-path=/workspace:/workspace
```

2. **Using Instance Template**:
```bash
# Create template
gcloud compute instance-templates create freebsd-template \
  --machine-type=n2-standard-4 \
  --image-family=cos-stable \
  --image-project=cos-cloud \
  --metadata-from-file user-data=gcp-startup.sh

# Create instance group
gcloud compute instance-groups managed create freebsd-group \
  --template=freebsd-template \
  --size=1 \
  --zone=us-central1-a
```

3. **GCP Credentials Configuration**:
```bash
# Inside container
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Or use service account
gcloud auth activate-service-account --key-file=/path/to/key.json
```

### GKE Deployment

```bash
# Create GKE cluster
gcloud container clusters create freebsd-cluster \
  --num-nodes=3 \
  --machine-type=n2-standard-4 \
  --zone=us-central1-a \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=5

# Get credentials
gcloud container clusters get-credentials freebsd-cluster \
  --zone=us-central1-a

# Deploy
kubectl apply -f k8s/freebsd-deployment.yaml
```

### Cloud Run Deployment

```yaml
# service.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: freebsd-dev
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/execution-environment: gen2
    spec:
      containers:
      - image: ghcr.io/aygp-dr/freebsd:14.3-RELEASE
        resources:
          limits:
            cpu: "4"
            memory: "8Gi"
        env:
        - name: ENABLE_SSH
          value: "true"
```

## Replit

### Replit Configuration

1. **Create `.replit` file**:
```toml
run = "docker-compose up"

[nix]
channel = "stable-24_05"

[deployment]
run = ["sh", "-c", "docker-compose up"]

[[ports]]
localPort = 2222
externalPort = 22
description = "SSH"

[[ports]]
localPort = 8080
externalPort = 80
description = "Web"

[[ports]]
localPort = 5900
externalPort = 5900
description = "VNC"
```

2. **Create `replit.nix`**:
```nix
{ pkgs }: {
  deps = [
    pkgs.docker
    pkgs.docker-compose
    pkgs.git
    pkgs.curl
    pkgs.wget
  ];
  
  env = {
    DOCKER_HOST = "unix:///var/run/docker.sock";
  };
}
```

3. **Replit-specific Docker Compose**:
```yaml
# docker-compose.replit.yml
version: '3.8'

services:
  freebsd:
    image: aygpdr/freebsd:14.3-RELEASE  # or ghcr.io/aygp-dr/freebsd:14.3-RELEASE
    container_name: freebsd-replit
    privileged: true
    environment:
      - MEMORY=2G  # Replit limits
      - CPUS=2
      - REPLIT_DB_URL=${REPLIT_DB_URL}
      - REPLIT_OWNER=${REPLIT_OWNER}
      - REPLIT_SLUG=${REPLIT_SLUG}
    ports:
      - "0.0.0.0:22:22"
      - "0.0.0.0:80:8080"
    volumes:
      - ./workspace:/workspace
      - replit-data:/freebsd
    networks:
      - replit-net

volumes:
  replit-data:

networks:
  replit-net:
    driver: bridge
```

4. **Replit Database Integration**:
```python
# replit_integration.py
from replit import db
import os

# Store configuration
db["freebsd_config"] = {
    "memory": "2G",
    "cpus": 2,
    "version": "14.3-RELEASE"
}

# Retrieve and apply
config = db["freebsd_config"]
os.environ.update(config)
```

## Azure

### Azure Container Instances

```bash
# Create container instance
az container create \
  --resource-group myResourceGroup \
  --name freebsd-container \
  --image ghcr.io/aygp-dr/freebsd:14.3-RELEASE \
  --cpu 4 \
  --memory 8 \
  --ports 22 8080 \
  --environment-variables MEMORY=4G CPUS=4
```

### AKS Deployment

```bash
# Create AKS cluster
az aks create \
  --resource-group myResourceGroup \
  --name freebsd-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4_v3 \
  --generate-ssh-keys

# Get credentials
az aks get-credentials \
  --resource-group myResourceGroup \
  --name freebsd-cluster

# Deploy
kubectl apply -f k8s/freebsd-deployment.yaml
```

## DigitalOcean

### Droplet Deployment

```bash
# Create Docker Droplet
doctl compute droplet create freebsd-docker \
  --image docker-20-04 \
  --size s-4vcpu-8gb \
  --region nyc1 \
  --user-data-file do-userdata.sh \
  --ssh-keys $(doctl compute ssh-key list --format ID --no-header)
```

### DOKS Deployment

```bash
# Create Kubernetes cluster
doctl kubernetes cluster create freebsd-cluster \
  --count 3 \
  --size s-4vcpu-8gb \
  --region nyc1

# Deploy
kubectl apply -f k8s/freebsd-deployment.yaml
```

## Environment Variables

Common environment variables for cloud deployments:

```bash
# AWS
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
AWS_DEFAULT_REGION=us-west-2
AWS_SESSION_TOKEN=xxx  # For temporary credentials

# Google Cloud
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
GCP_PROJECT=your-project-id
GCP_REGION=us-central1

# Replit
REPLIT_DB_URL=xxx
REPLIT_OWNER=username
REPLIT_SLUG=project-name

# Azure
AZURE_SUBSCRIPTION_ID=xxx
AZURE_TENANT_ID=xxx
AZURE_CLIENT_ID=xxx
AZURE_CLIENT_SECRET=xxx

# DigitalOcean
DIGITALOCEAN_ACCESS_TOKEN=xxx
```

## Kubernetes Deployment

Universal Kubernetes deployment for all cloud providers:

```yaml
# k8s/freebsd-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: freebsd-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: freebsd
  template:
    metadata:
      labels:
        app: freebsd
    spec:
      containers:
      - name: freebsd
        image: aygpdr/freebsd:14.3-RELEASE  # or ghcr.io/aygp-dr/freebsd:14.3-RELEASE
        securityContext:
          privileged: true
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
        ports:
        - containerPort: 22
        - containerPort: 8080
        env:
        - name: MEMORY
          value: "4G"
        - name: CPUS
          value: "4"
        volumeMounts:
        - name: workspace
          mountPath: /workspace
      volumes:
      - name: workspace
        persistentVolumeClaim:
          claimName: freebsd-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: freebsd-service
spec:
  selector:
    app: freebsd
  ports:
  - name: ssh
    port: 22
    targetPort: 22
  - name: web
    port: 80
    targetPort: 8080
  type: LoadBalancer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: freebsd-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

## Cost Optimization

### Recommended Instance Types

| Provider | Development | Production | Cost-Optimized |
|----------|------------|------------|----------------|
| AWS | t3.large | m5.xlarge | t3a.medium |
| GCP | n2-standard-2 | n2-standard-4 | e2-medium |
| Azure | Standard_D2_v3 | Standard_D4_v3 | Standard_B2ms |
| DO | s-2vcpu-4gb | s-4vcpu-8gb | s-2vcpu-2gb |

### Auto-shutdown Scripts

```bash
# AWS Auto-shutdown after 2 hours of inactivity
aws ec2 modify-instance-attribute \
  --instance-id i-xxxxx \
  --instance-initiated-shutdown-behavior terminate

# GCP Auto-shutdown
gcloud compute instances add-metadata freebsd-vm \
  --metadata shutdown-script='#!/bin/bash
  if [ $(who | wc -l) -eq 0 ]; then
    shutdown -h now
  fi'
```

## Security Best Practices

1. **Use IAM Roles** instead of access keys when possible
2. **Enable VPC** and restrict network access
3. **Use Secrets Management**:
   - AWS Secrets Manager
   - GCP Secret Manager
   - Azure Key Vault
4. **Enable audit logging**
5. **Regular security scanning** with Trivy/Snyk

## Troubleshooting

### Common Issues

1. **Insufficient Privileges**:
   - Ensure `privileged: true` in container specs
   - Check IAM/Service Account permissions

2. **Network Connectivity**:
   - Verify security groups/firewall rules
   - Check VPC/Network configuration

3. **Resource Limits**:
   - Increase memory/CPU limits
   - Check cloud provider quotas

## Support

For cloud-specific issues:
- AWS: [AWS Support](https://aws.amazon.com/support)
- GCP: [Google Cloud Support](https://cloud.google.com/support)
- Replit: [Replit Community](https://ask.replit.com)
- Azure: [Azure Support](https://azure.microsoft.com/support)
- DigitalOcean: [DO Support](https://www.digitalocean.com/support)

For FreeBSD Docker issues:
- [GitHub Issues](https://github.com/aygp-dr/freebsd-docker/issues)