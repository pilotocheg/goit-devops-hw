# Django CI/CD on AWS EKS — Terraform + Helm + Jenkins + Argo CD

## Project Overview

This project provisions AWS infrastructure with Terraform and runs a full CI/CD
pipeline for a Django application:

1. **Jenkins** (installed via Helm/Terraform) builds a Docker image with **Kaniko**
   on a Kubernetes agent and pushes it to **Amazon ECR**.
2. Jenkins then updates the image tag in the **Helm chart** and pushes the change to Git.
3. **Argo CD** (installed via Helm/Terraform) watches the Git repo and automatically
   syncs the updated chart to the **EKS** cluster.

```
Developer ──push──▶ app repo ──▶ Jenkins (Kaniko) ──build/push──▶ Amazon ECR
                                     │
                                     └─update tag──▶ Git (Helm chart) ──▶ Argo CD ──sync──▶ EKS
```

## Terraform Modules

| Module        | Purpose |
| ------------- | ------- |
| `s3-backend`  | S3 bucket (with versioning) for Terraform state + DynamoDB table for state locking. |
| `vpc`         | VPC, public/private subnets, Internet Gateway, route tables. |
| `ecr`         | Amazon ECR repository for the Django image (`scan_on_push`). |
| `eks`         | EKS cluster, managed node group, OIDC provider (IRSA), and the EBS CSI driver add-on. |
| `jenkins`     | Jenkins via Helm + JCasC, a Kubernetes/Kaniko agent, and an IRSA role so Kaniko can push to ECR. |
| `argo-cd`     | Argo CD via Helm plus a local chart that defines the Argo CD `Application` tracking the Helm chart in Git. |

## Project Structure

```text
.
├── backend.tf                 # S3 + DynamoDB backend
├── main.tf                    # Providers + module wiring
├── variables.tf               # Root variables (incl. github_pat, sensitive)
├── versions.tf                # Terraform + provider version constraints
├── outputs.tf                 # Aggregated outputs
├── terraform.tfvars.example   # Template for local secrets (copy to terraform.tfvars)
│
├── modules/
│   ├── s3-backend/            # s3.tf, dynamodb.tf, variables.tf, outputs.tf
│   ├── vpc/                   # vpc.tf, routes.tf, variables.tf, outputs.tf
│   ├── ecr/                   # ecr.tf, variables.tf, outputs.tf
│   ├── eks/                   # eks.tf, node.tf, aws_ebs_csi_driver.tf, variables.tf, outputs.tf
│   ├── jenkins/               # jenkins.tf, values.yaml (JCasC), variables.tf, providers.tf, outputs.tf
│   └── argo-cd/               # argo_cd.tf, variables.tf, providers.tf, outputs.tf
│       └── chart/             # local chart rendering the Argo CD Application
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/application.yaml
│
└── charts/
    └── django-app/            # Helm chart deployed by Argo CD
        ├── Chart.yaml
        ├── values.yaml        # image repo/tag, service, hpa, postgres, config (env vars)
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── configmap.yaml
            ├── hpa.yaml
            └── postgres.yaml  # in-cluster PostgreSQL (Deployment + `db` Service)
```

## Prerequisites

- Terraform >= 1.5, AWS CLI (configured), `kubectl`, `helm`
- An AWS account with permissions to create VPC/EKS/ECR/IAM/S3/DynamoDB
- A GitHub Personal Access Token with **Contents: Read and write** on the GitOps repo

## Configuration

Sensitive values are passed through Terraform variables and must **not** be committed.
Copy the example file and fill in your token:

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
# terraform.tfvars  (gitignored via *.tfvars)
github_pat      = "github_pat_xxxxxxxx"   # PAT with Contents: read/write
github_username = "your-github-username"  # optional, defaults to the configured value
```

Alternatively, export it as an environment variable:

```bash
export TF_VAR_github_pat="github_pat_xxxxxxxx"
```

> Only `terraform.tfvars` and `*.auto.tfvars` are auto-loaded by Terraform — a file
> named `.tfvars` is ignored unless passed with `-var-file`.

## Deployment

### 1. Initialize and apply

```bash
terraform init
terraform plan
terraform apply
```

This creates the VPC, EKS cluster, ECR, and installs Jenkins and Argo CD.

> On a cold environment the `helm` provider authenticates to the cluster via
> `aws eks get-token`, so a single `terraform apply` works. If you ever hit a
> provider-timing error, apply the cluster first: `terraform apply -target=module.eks`.

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-central-1 --name eks-cluster-demo
kubectl get nodes
```

### 3. Access Jenkins

```bash
kubectl -n jenkins get svc jenkins \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
# admin password:
kubectl -n jenkins get secret jenkins \
  -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo
```

Jenkins is bootstrapped via JCasC with:
- the `github-token` credential (from `var.github_pat`),
- a seed job that generates the Django pipeline job,
- a Kubernetes cloud that runs builds on dynamic Kaniko agent pods (SA `jenkins-sa`,
  annotated with an IRSA role that grants ECR push).

### 4. Access Argo CD

```bash
kubectl -n argocd get svc argo-cd-argocd-server \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
# initial admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

The Argo CD `Application` (`django-app`) tracks `charts/django-app` in Git and syncs
automatically (`prune` + `selfHeal`). The tracked branch/path is configured in
`modules/argo-cd/chart/values.yaml`.

## CI/CD Pipeline

The `Jenkinsfile` lives in the application repository
(`github.com/pilotocheg/goit-devops-django-project`). On each build it:

1. Builds the image from `django/Dockerfile` with Kaniko and pushes
   `terraform-demo-ecr:django-app-<BUILD_NUMBER>` to ECR.
2. Clones the GitOps repo, updates `image.tag` in `charts/django-app/values.yaml`,
   and pushes the commit.
3. Argo CD detects the change and rolls out the new image.

### Verify the flow end-to-end

```bash
# newest tag in ECR
aws ecr describe-images --region eu-central-1 --repository-name terraform-demo-ecr \
  --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags'

# Argo CD app status
kubectl -n argocd get application django-app \
  -o jsonpath='SYNC={.status.sync.status} HEALTH={.status.health.status}'; echo

# running image in the cluster
kubectl -n default get deploy django-app-django \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

## Application Chart (`charts/django-app`)

| Template          | Description |
| ----------------- | ----------- |
| `deployment.yaml` | Runs the Django container with env from the ConfigMap. |
| `service.yaml`    | Exposes the app (LoadBalancer, port 80 → 8000). |
| `configmap.yaml`  | PostgreSQL connection settings (`POSTGRES_*`). |
| `hpa.yaml`        | Horizontal Pod Autoscaler (CPU/memory). |
| `postgres.yaml`   | In-cluster PostgreSQL `Deployment` + a `db` `Service` (matches `POSTGRES_HOST`). |

> The bundled PostgreSQL uses an `emptyDir` volume (ephemeral — data resets if the
> pod is recreated), which is sufficient for a demo. Switch to a `PersistentVolumeClaim`
> (the cluster has the EBS CSI driver) for durable storage.

## Teardown

```bash
terraform destroy
```

## Security Notes

- `github_pat` is a `sensitive` Terraform variable, injected into Jenkins JCasC at
  apply time; keep it only in `terraform.tfvars` (gitignored) or `TF_VAR_github_pat`.
- Never commit tokens. If a token is ever committed, revoke it immediately and rotate.
