# Terraform Infrastructure Project

## Project Overview

This project provisions basic AWS infrastructure using Terraform and consists of three modules:

- **s3-backend** – creates an S3 bucket for storing the Terraform state file and a DynamoDB table for state locking.
- **vpc** – creates the AWS networking infrastructure, including a VPC, public and private subnets, and an Internet Gateway.
- **ecr** – creates an Amazon Elastic Container Registry (ECR) for storing Docker images.

---

## Project Structure

```text
lesson-5/
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
│   └── ecr/
│       ├── ecr.tf
│       ├── variables.tf
│       └── outputs.tf
└── .terraform.lock.hcl
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

### 4. Destroy the Infrastructure

```bash
terraform destroy
```

Removes all resources managed by Terraform.

To skip the confirmation prompt:

```bash
terraform destroy -auto-approve
```
