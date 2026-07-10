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

| Module       | Purpose                                                                                                                                                                                                           |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `s3-backend` | S3 bucket (with versioning) for Terraform state + DynamoDB table for state locking.                                                                                                                               |
| `vpc`        | VPC, public/private subnets, Internet Gateway, route tables.                                                                                                                                                      |
| `ecr`        | Amazon ECR repository for the Django image (`scan_on_push`).                                                                                                                                                      |
| `eks`        | EKS cluster, managed node group, OIDC provider (IRSA), and the EBS CSI driver add-on.                                                                                                                             |
| `jenkins`    | Jenkins via Helm + JCasC, a Kubernetes/Kaniko agent, and an IRSA role so Kaniko can push to ECR.                                                                                                                  |
| `argo-cd`    | Argo CD via Helm plus a local chart that defines the Argo CD `Application` tracking the Helm chart in Git.                                                                                                        |
| `rds`        | Universal database module: provisions **either** an Aurora cluster **or** a standard RDS instance (toggled by `use_aurora`), plus the DB subnet group, security group, and parameter group for the chosen engine. |

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
│   ├── argo-cd/               # argo_cd.tf, variables.tf, providers.tf, outputs.tf
│   │   └── chart/             # local chart rendering the Argo CD Application
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/application.yaml
│   └── rds/                   # shared.tf, rds.tf, aurora.tf, variables.tf, outputs.tf, providers.tf
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

| Template          | Description                                                                      |
| ----------------- | -------------------------------------------------------------------------------- |
| `deployment.yaml` | Runs the Django container with env from the ConfigMap.                           |
| `service.yaml`    | Exposes the app (LoadBalancer, port 80 → 8000).                                  |
| `configmap.yaml`  | PostgreSQL connection settings (`POSTGRES_*`).                                   |
| `hpa.yaml`        | Horizontal Pod Autoscaler (CPU/memory).                                          |
| `postgres.yaml`   | In-cluster PostgreSQL `Deployment` + a `db` `Service` (matches `POSTGRES_HOST`). |

> The bundled PostgreSQL uses an `emptyDir` volume (ephemeral — data resets if the
> pod is recreated), which is sufficient for a demo. Switch to a `PersistentVolumeClaim`
> (the cluster has the EBS CSI driver) for durable storage.

## Database (`modules/rds`)

A single, reusable module that provisions **either** an Aurora cluster **or** a
standard RDS instance based on `use_aurora`. For each mode it automatically creates
the **DB subnet group**, **security group**, and the correct **parameter group**
(`aws_db_parameter_group` for RDS, `aws_rds_cluster_parameter_group` for Aurora).

### Usage example

```hcl
module "rds" {
  source = "./modules/rds"

  name       = "terraform-demo-db"
  use_aurora = false # false -> standard RDS instance, true -> Aurora cluster

  # --- Aurora-only (used when use_aurora = true) ---
  engine_cluster                = "aurora-postgresql"
  engine_version_cluster        = "15.3"
  parameter_group_family_aurora = "aurora-postgresql15"
  aurora_replica_count          = 1

  # --- Standard RDS-only (used when use_aurora = false) ---
  engine                     = "postgres"
  engine_version             = "17.5"
  parameter_group_family_rds = "postgres17"

  # Common
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "terraform_demo"
  username                = "postgres"
  password                = var.rds_password # null -> auto-generated
  subnet_private_ids      = module.vpc.private_subnets
  subnet_public_ids       = module.vpc.public_subnets
  publicly_accessible     = false
  vpc_id                  = module.vpc.vpc_id
  multi_az                = false
  backup_retention_period = 7
  skip_final_snapshot     = true

  parameters = {
    max_connections            = "200"
    log_min_duration_statement = "500"
  }

  tags = {
    Environment = "dev"
    Project     = "terraform-demo"
  }
}
```

### Variables

| Variable                        | Type               | Default                 | Description                                                                       |
| ------------------------------- | ------------------ | ----------------------- | --------------------------------------------------------------------------------- |
| `name`                          | string             | –                       | Base name for the instance/cluster and all supporting resources.                  |
| `use_aurora`                    | bool               | `false`                 | `true` → Aurora cluster, `false` → single RDS instance.                           |
| `engine`                        | string             | `"postgres"`            | Engine for the **standard RDS** instance (`postgres`, `mysql`, `mariadb`, …).     |
| `engine_version`                | string             | `"17.5"`                | Engine version for the standard RDS instance (must exist in your region).          |
| `parameter_group_family_rds`    | string             | `"postgres17"`          | Parameter group family for standard RDS (e.g. `postgres17`, `mysql8.0`).          |
| `engine_cluster`                | string             | `"aurora-postgresql"`   | Engine for the **Aurora** cluster (`aurora-postgresql`, `aurora-mysql`).          |
| `engine_version_cluster`        | string             | `"15.3"`                | Engine version for the Aurora cluster.                                            |
| `parameter_group_family_aurora` | string             | `"aurora-postgresql15"` | Parameter group family for Aurora.                                                |
| `aurora_replica_count`          | number             | `1`                     | Number of Aurora reader replicas (a writer is always created on top).             |
| `instance_class`                | string             | `"db.t3.micro"`         | Instance class. `db.t3.micro` is Free Tier eligible (standard RDS only).          |
| `allocated_storage`             | number             | `20`                    | Storage in GB (standard RDS only; Free Tier allows up to 20).                     |
| `db_name`                       | string             | –                       | Name of the initial database.                                                     |
| `username`                      | string             | –                       | Master username.                                                                  |
| `password`                      | string (sensitive) | `null`                  | Master password. `null`/empty → auto-generated. Prefer `TF_VAR_rds_password`.     |
| `vpc_id`                        | string             | –                       | VPC in which the security group is created.                                       |
| `subnet_private_ids`            | list(string)       | –                       | Private subnets (subnet group when **not** publicly accessible).                  |
| `subnet_public_ids`             | list(string)       | –                       | Public subnets (subnet group when publicly accessible).                           |
| `publicly_accessible`           | bool               | `false`                 | Whether the DB gets a public endpoint. Keep `false` unless required.              |
| `allowed_cidr_blocks`           | list(string)       | `["10.0.0.0/16"]`       | CIDRs allowed to reach the DB port. Restrict in production.                       |
| `db_port`                       | number             | `null`                  | DB port. `null` → derived from engine (5432 Postgres, 3306 MySQL/MariaDB).        |
| `multi_az`                      | bool               | `false`                 | Multi-AZ (standard RDS). **Not Free Tier eligible** — keep `false` for Free Tier. |
| `backup_retention_period`       | number             | `7`                     | Days to retain automated backups.                                                 |
| `skip_final_snapshot`           | bool               | `true`                  | Skip the final snapshot on destroy (convenient for demos/dev).                    |
| `parameters`                    | map(string)        | `{}`                    | DB parameters applied to the parameter group.                                     |
| `tags`                          | map(string)        | `{}`                    | Tags applied to all resources.                                                    |

**Outputs:** `endpoint`, `reader_endpoint` (Aurora only), `port`, `db_name`,
`username`, `password` (sensitive), `security_group_id`.

### How to change DB type, engine, instance class, …

- **Aurora vs standard RDS:** flip `use_aurora`. `true` builds an Aurora cluster
  (writer + `aurora_replica_count` readers); `false` builds a single RDS instance.
  Only the resources for the selected mode are created (the others use `count = 0`).
- **Change the engine** (e.g. Postgres → MySQL):
  - Standard RDS: set `engine = "mysql"`, `engine_version = "8.0.36"`,
    `parameter_group_family_rds = "mysql8.0"`. The security group port switches to
    3306 automatically (derived from the engine); override with `db_port` if needed.
  - Aurora: set `engine_cluster = "aurora-mysql"`,
    `engine_version_cluster = "8.0.mysql_aurora.3.05.2"`,
    `parameter_group_family_aurora = "aurora-mysql8.0"`.
- **Change the instance class:** set `instance_class` (e.g. `db.t3.medium`).
  Keep `db.t3.micro` to stay in the Free Tier.
- **Storage:** adjust `allocated_storage` (standard RDS; Aurora storage autoscales).
- **Tune parameters:** add entries to the `parameters` map — they are applied to the
  correct parameter group for the active engine.

### AWS Free Tier notes

The defaults are tuned for the RDS Free Tier:

- `use_aurora = false` — **Aurora has no Free Tier**, so use standard RDS.
- `instance_class = "db.t3.micro"`, `allocated_storage <= 20`.
- `multi_az = false` — **Multi-AZ is not Free Tier eligible**.
- `backup_retention_period = 0` — the newer **AWS Free Tier plan forbids automated
  backups** (`FreeTierRestrictionError`). Set a value `> 0` on a paid plan.
- `publicly_accessible = false` and `allowed_cidr_blocks` scoped to the VPC CIDR.

### Password handling

The RDS password is **not** hardcoded. Like the Jenkins admin password, it is
generated with `random_password` inside the module when no value is supplied.
To set an explicit password, export it as an environment variable (never commit it):

```bash
export TF_VAR_rds_password="your-strong-password"
```

Retrieve the (generated or provided) password and endpoint from outputs:

```bash
terraform output -raw rds_password
terraform output -raw rds_endpoint
```

### Create only the database

Provision just the RDS module (Terraform also creates its dependencies — the VPC —
but skips EKS, ECR, Jenkins, and Argo CD):

```bash
terraform apply -target=module.rds
```

## Teardown

```bash
bash scripts/teardown.sh
```

## Security Notes

- `github_pat` is a `sensitive` Terraform variable, injected into Jenkins JCasC at
  apply time; keep it only in `terraform.tfvars` (gitignored) or `TF_VAR_github_pat`.
- Never commit tokens. If a token is ever committed, revoke it immediately and rotate.
