# Terraform Infrastructure Project

## Project Overview

This project provisions AWS infrastructure using Terraform and deploys a Django application to Kubernetes with Helm. It consists of four Terraform modules and a Helm chart:

- **s3-backend** – creates an S3 bucket for storing the Terraform state file and a DynamoDB table for state locking.
- **vpc** – creates the AWS networking infrastructure, including a VPC, public and private subnets, and an Internet Gateway.
- **ecr** – creates an Amazon Elastic Container Registry (ECR) for storing Docker images.
- **eks** – creates an Amazon EKS cluster with a managed node group for running containerized workloads.
- **django-app** (Helm chart) – deploys a Django application with a ConfigMap, Service, and Horizontal Pod Autoscaler (HPA).

---

## Project Structure

```text
lesson-7/
├── backend.tf
├── main.tf
├── outputs.tf
├── README.md
├── modules/
│   ├── s3-backend/
│   │   ├── s3.tf
│   │   ├── dynamodb.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── vpc/
│   │   ├── vpc.tf
│   │   ├── routes.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecr/
│   │   ├── ecr.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── eks/
│       ├── eks.tf
│       ├── node.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── charts/
    └── django-app/
        ├── Chart.yml
        ├── values.yml
        └── templates/
            ├── configmap.yml
            ├── deployment.yml
            ├── hpa.yml
            └── service.yml
```

---

## Modules

### s3-backend

This module creates:

- An S3 bucket for storing the Terraform state file;
- S3 versioning to preserve state history;
- A DynamoDB table for state locking during Terraform operations.

**Resources:**

- AWS S3 Bucket
- AWS S3 Bucket Versioning
- AWS DynamoDB Table

---

### vpc

This module provisions the AWS networking infrastructure:

- Virtual Private Cloud (VPC);
- Public subnets;
- Private subnets;
- Internet Gateway;
- Route tables and routing configuration.

**Resources:**

- AWS VPC
- AWS Subnet
- AWS Internet Gateway
- AWS Route Tables

---

### ecr

This module creates an Amazon Elastic Container Registry (ECR) repository for storing Docker container images.

**Features:**

- Automatic image scanning on push (`scan_on_push`);
- Centralized container image storage for use with ECS, EKS, or other AWS services.

**Resources:**

- AWS ECR Repository

---

### eks

This module provisions an Amazon EKS cluster with a managed node group.

**Features:**

- IAM roles for the EKS control plane and worker nodes;
- Managed node group with configurable instance type and scaling;
- Public and private API endpoint access;
- API-based authentication with cluster creator admin permissions.

**Resources:**

- AWS IAM Role (cluster and nodes)
- AWS IAM Role Policy Attachments
- AWS EKS Cluster
- AWS EKS Node Group

---

## Helm Chart: django-app

The `charts/django-app` chart deploys a Django application to the EKS cluster.

**Templates:**

| Template         | Description                                               |
| ---------------- | --------------------------------------------------------- |
| `deployment.yml` | Runs the Django container with environment from ConfigMap |
| `service.yml`    | Exposes the application inside the cluster (ClusterIP)    |
| `configmap.yml`  | Stores PostgreSQL connection settings                     |
| `hpa.yml`        | Scales pods based on CPU and memory utilization           |

**Key values** (`values.yml`):

- `image.repository` / `image.tag` – container image to deploy;
- `service.port` – application port (default: `8000`);
- `hpa.enabled` – enable Horizontal Pod Autoscaler (default: `true`);
- `hpa.minReplicas` / `hpa.maxReplicas` – scaling bounds;
- `config` – environment variables injected into the pod.

---

## Initialization and Deployment

### 1. Initialize Terraform

```bash
terraform init
```

Downloads the required providers and initializes the Terraform working directory.

---

### 2. Review the Execution Plan

```bash
terraform plan
```

Displays the resources that Terraform will create, modify, or delete.

---

### 3. Deploy the Infrastructure

```bash
terraform apply
```

Creates all AWS resources defined in the Terraform configuration.

To skip the confirmation prompt:

```bash
terraform apply -auto-approve
```

---

### 4. Configure kubectl

After the EKS cluster is created, configure `kubectl` to connect to it:

```bash
aws eks update-kubeconfig --region eu-central-1 --name eks-cluster-demo
```

Verify the connection:

```bash
kubectl get nodes
```

---

### 5. Deploy the Django Application with Helm

Update `charts/django-app/values.yml` with your ECR image URI, then install the chart:

```bash
helm install django-app ./charts/django-app
```

Check the deployment:

```bash
kubectl get pods
kubectl get hpa
```

---

### 6. Destroy the Infrastructure

```bash
terraform destroy
```

Removes all resources managed by Terraform.

To skip the confirmation prompt:

```bash
terraform destroy -auto-approve
```
