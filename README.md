# EKS + Karpenter Autoscaling with ARM64 and x86 Support

This repo provides Terraform code to deploy an optimized Kubernetes (EKS) cluster on AWS with:
- Graviton and x86 instance support
- Spot + fallback to OnDemand
- Karpenter for fast autoscaling

---

## Prerequisites

- Terraform >= 1.5
- AWS CLI installed and configured
- kubectl installed

---

## 🛠 Deployment Instructions

```bash
git clone https://github.com/nikdavnik/Opsfleet_tech_task
cd eks-karpenter
terraform init
terraform apply
```

---

# How Developers Can Run Pods

## Deploy to ARM64 (Graviton):

```
nodeSelector:
  kubernetes.io/arch: arm64
```

---

## Deploy to x86 (Intel/AMD):

```
nodeSelector:
  kubernetes.io/arch: amd64
```

---

## Example ARM64 app:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-arm64-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: arm64-app
  template:
    metadata:
      labels:
        app: arm64-app
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
      containers:
      - name: app
        image: public.ecr.aws/ubuntu/ubuntu:latest
        command: ["sleep", "3600"]
```
