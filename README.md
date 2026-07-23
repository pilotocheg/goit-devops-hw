# Django CI/CD on AWS EKS — Terraform + Helm + Jenkins + Argo CD

## Project Overview

This project provisions AWS infrastructure with Terraform and runs a full CI/CD
pipeline for a Django application:

1. **Jenkins** (installed via Helm/Terraform) builds a Docker image with **Kaniko**
   on a Kubernetes agent and pushes it to **Amazon ECR**.
2. Jenkins then updates the image tag in the **Helm chart** and pushes the change to Git.
3. **Argo CD** (installed via Helm/Terraform) watches the Git repo and automatically
   syncs the updated chart to the **EKS** cluster.
4. **Prometheus & Grafana** (kube-prometheus-stack) collect cluster metrics and provide
   dashboards for observability.

```
Developer ──push──▶ app repo ──▶ Jenkins (Kaniko) ──build/push──▶ Amazon ECR
                                     │
                                     └─update tag──▶ Git (Helm chart) ──▶ Argo CD ──sync──▶ EKS
                                                                                        │
                                                                                        └──▶ Prometheus / Grafana
```

## Terraform Modules

| Module        | Purpose                                                                                                                                                                                                           |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `s3-backend`  | S3 bucket (with versioning) for Terraform state.                                                                                                                                                                  |
| `vpc`         | VPC, public/private subnets, Internet Gateway, route tables.                                                                                                                                                      |
| `ecr`         | Amazon ECR repository for the Django image (`scan_on_push`).                                                                                                                                                      |
| `eks`         | EKS cluster, managed node group, OIDC provider (IRSA), and the EBS CSI driver add-on.                                                                                                                             |
| `jenkins`     | Jenkins via Helm + JCasC, a Kubernetes/Kaniko agent, and an IRSA role so Kaniko can push to ECR.                                                                                                                  |
| `argo-cd`     | Argo CD via Helm plus a local chart that defines the Argo CD `Application` tracking the Helm chart in Git.                                                                                                        |
| `rds`         | Universal database module: provisions **either** an Aurora cluster **or** a standard RDS instance (toggled by `use_aurora`), plus the DB subnet group, security group, and parameter group for the chosen engine. |
| `monitoring`  | kube-prometheus-stack (Prometheus + Grafana + AlertManager) installed via Helm into the `monitoring` namespace. Grafana is exposed via a LoadBalancer Service.                                                    |

## Project Structure

```text
.
├── backend.tf                 # S3 backend
├── main.tf                    # Providers + module wiring + kubernetes_secret (RDS creds)
├── variables.tf               # Root variables (github_pat, rds_password, grafana_admin_password)
├── versions.tf                # Terraform + provider version constraints
├── outputs.tf                 # Aggregated outputs
├── terraform.tfvars.example   # Template for local secrets (copy to terraform.tfvars)
│
├── modules/
│   ├── s3-backend/            # s3.tf, variables.tf, outputs.tf
│   ├── vpc/                   # vpc.tf, routes.tf, nat.tf, variables.tf, outputs.tf
│   ├── ecr/                   # ecr.tf, variables.tf, outputs.tf
│   ├── eks/                   # eks.tf, node.tf, aws_ebs_csi_driver.tf, variables.tf, outputs.tf
│   ├── jenkins/               # jenkins.tf, values.yaml (JCasC), variables.tf, providers.tf, outputs.tf
│   ├── argo-cd/               # argo_cd.tf, variables.tf, providers.tf, outputs.tf
│   │   └── chart/             # local chart rendering the Argo CD Application
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/application.yaml
│   ├── rds/                   # shared.tf, rds.tf, aurora.tf, variables.tf, outputs.tf, providers.tf
│   └── monitoring/            # kube-prometheus-stack (Prometheus + Grafana + AlertManager)
│       ├── monitoring.tf      # helm_release for kube-prometheus-stack
│       ├── variables.tf
│       ├── outputs.tf
│       └── providers.tf
│
└── charts/
    └── django-app/            # Helm chart deployed by Argo CD
        ├── Chart.yaml
        ├── values.yaml        # image, service, hpa, postgres, config (non-sensitive), secrets, rdsSecretName
        └── templates/
            ├── deployment.yaml  # liveness + readiness TCP probes; envFrom: configMapRef + secretRef
            ├── service.yaml
            ├── configmap.yaml   # non-sensitive env vars only (POSTGRES_PORT, USER, DB, HOST)
            ├── secret.yaml      # Helm-managed Secret for POSTGRES_PASSWORD (dev/local mode)
            ├── hpa.yaml
            └── postgres.yaml    # optional in-cluster PostgreSQL with pg_isready probes
```

## Prerequisites

- Terraform >= 1.5, AWS CLI (configured), `kubectl`, `helm`
- An AWS account with permissions to create VPC/EKS/ECR/IAM/S3/RDS
- A GitHub Personal Access Token with **Contents: Read and write** on the GitOps repo

## Configuration

Sensitive values are passed through Terraform variables and must **not** be committed.
Copy the example file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
# terraform.tfvars  (gitignored via *.tfvars)
github_pat             = "github_pat_xxxxxxxx"   # PAT with Contents: read/write
github_username        = "your-github-username"  # optional, defaults to the configured value
grafana_admin_password = "your-grafana-password" # Grafana admin password
# rds_password = "your-rds-password"             # optional: omit to auto-generate
```

Alternatively, export as environment variables:

```bash
export TF_VAR_github_pat="github_pat_xxxxxxxx"
export TF_VAR_grafana_admin_password="your-grafana-password"
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

This creates the VPC, EKS cluster, ECR, RDS instance, installs Jenkins, Argo CD, and the
monitoring stack. It also creates the `django-app-rds` Kubernetes Secret with the real
RDS endpoint and password (see [Secrets management](#secrets-management) below).

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

### 5. Access Grafana

```bash
kubectl -n monitoring get svc kube-prometheus-stack-grafana \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
# Login: admin / <grafana_admin_password from tfvars>
```

Grafana ships with pre-built dashboards for Kubernetes nodes, workloads, and
Persistent Volumes. Prometheus scrapes all cluster components automatically via the
`kube-prometheus-stack` service monitors.

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

| Template          | Description                                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------------------------ |
| `deployment.yaml` | Runs the Django container; loads env from ConfigMap + Secret; includes liveness & readiness TCP probes (port 8000). |
| `service.yaml`    | Exposes the app (LoadBalancer, port 80 → 8000).                                                                    |
| `configmap.yaml`  | Non-sensitive PostgreSQL settings only (`POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_HOST`).         |
| `secret.yaml`     | Helm-managed Secret with `POSTGRES_PASSWORD` — only rendered when `rdsSecretName` is empty (dev/local mode).       |
| `hpa.yaml`        | Horizontal Pod Autoscaler (CPU/memory).                                                                            |
| `postgres.yaml`   | Optional in-cluster PostgreSQL `Deployment` + `db` Service; includes `pg_isready` liveness & readiness probes.    |

### Health probes

Both the Django and the optional in-cluster PostgreSQL containers define **liveness**
and **readiness** probes:

- **Django** — TCP socket probe on port 8000 (`initialDelaySeconds: 30`, `periodSeconds: 10`
  for liveness; `initialDelaySeconds: 10`, `periodSeconds: 5` for readiness).
- **PostgreSQL** — `exec: pg_isready` with the same timing pattern.

Kubernetes will restart a container that fails liveness, and will stop sending traffic
to a pod that fails readiness — ensuring only healthy pods serve requests.

### `values.yaml` structure

```yaml
config:            # → ConfigMap (non-sensitive)
  POSTGRES_PORT: 5432
  POSTGRES_HOST: ""          # overridden at runtime by the RDS Secret
  POSTGRES_USER: django_user
  POSTGRES_DB: django_db

secrets:           # → Kubernetes Secret (rendered only when rdsSecretName is empty)
  POSTGRES_PASSWORD: "..."   # placeholder; real value injected by Terraform

rdsSecretName: "django-app-rds"   # Terraform-managed Secret; set to "" for local dev
```

When `rdsSecretName` is set, the chart skips creating its own Secret and the deployment
mounts the pre-existing Terraform-created Secret instead.

## Secrets management

Sensitive database credentials are **never stored in Git** or in a ConfigMap.

| Credential        | Where it lives                                                                        |
| ----------------- | ------------------------------------------------------------------------------------- |
| `POSTGRES_HOST`   | `kubernetes_secret.django_rds` in `main.tf` — populated from `module.rds.endpoint`   |
| `POSTGRES_PASSWORD` | `kubernetes_secret.django_rds` in `main.tf` — populated from `module.rds.password` |
| `github_pat`      | Terraform sensitive variable → Jenkins JCasC at apply time                           |
| `grafana_admin_password` | Terraform sensitive variable → Grafana Helm values at apply time            |
| `rds_password`    | Terraform sensitive variable (optional; auto-generated if omitted)                   |

Terraform creates the `django-app-rds` Kubernetes Secret in the `default` namespace
after the EKS cluster is ready. The Secret is referenced by name in
`charts/django-app/values.yaml` (`rdsSecretName: "django-app-rds"`) and loaded into
the Django pod via `envFrom: secretRef`. Argo CD does not manage this Secret, so it
is not pruned on re-sync.

## Database (`modules/rds`)

A single, reusable module that provisions **either** an Aurora cluster **or** a
standard RDS instance based on `use_aurora`. For each mode it automatically creates
the **DB subnet group**, **security group**, and the correct **parameter group**.

### Usage example

```hcl
module "rds" {
  source = "./modules/rds"

  name       = "terraform-demo-db"
  use_aurora = false # false -> standard RDS instance, true -> Aurora cluster

  engine                     = "postgres"
  engine_version             = "17.5"
  parameter_group_family_rds = "postgres17"

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
  backup_retention_period = 0
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
| `engine`                        | string             | `"postgres"`            | Engine for the **standard RDS** instance.                                         |
| `engine_version`                | string             | `"17.5"`                | Engine version for the standard RDS instance.                                     |
| `parameter_group_family_rds`    | string             | `"postgres17"`          | Parameter group family for standard RDS.                                          |
| `engine_cluster`                | string             | `"aurora-postgresql"`   | Engine for the **Aurora** cluster.                                                |
| `engine_version_cluster`        | string             | `"15.3"`                | Engine version for the Aurora cluster.                                            |
| `parameter_group_family_aurora` | string             | `"aurora-postgresql15"` | Parameter group family for Aurora.                                                |
| `aurora_replica_count`          | number             | `1`                     | Number of Aurora reader replicas.                                                 |
| `instance_class`                | string             | `"db.t3.micro"`         | Instance class. `db.t3.micro` is Free Tier eligible (standard RDS only).          |
| `allocated_storage`             | number             | `20`                    | Storage in GB (standard RDS only; Free Tier allows up to 20).                     |
| `db_name`                       | string             | –                       | Name of the initial database.                                                     |
| `username`                      | string             | –                       | Master username.                                                                  |
| `password`                      | string (sensitive) | `null`                  | Master password. `null`/empty → auto-generated. Prefer `TF_VAR_rds_password`.     |
| `vpc_id`                        | string             | –                       | VPC in which the security group is created.                                       |
| `subnet_private_ids`            | list(string)       | –                       | Private subnets for the DB subnet group.                                          |
| `subnet_public_ids`             | list(string)       | –                       | Public subnets (used when `publicly_accessible = true`).                          |
| `publicly_accessible`           | bool               | `false`                 | Whether the DB gets a public endpoint.                                            |
| `allowed_cidr_blocks`           | list(string)       | `["10.0.0.0/16"]`       | CIDRs allowed to reach the DB port.                                               |
| `db_port`                       | number             | `null`                  | DB port. `null` → derived from engine (5432 Postgres, 3306 MySQL/MariaDB).        |
| `multi_az`                      | bool               | `false`                 | Multi-AZ. **Not Free Tier eligible.**                                             |
| `backup_retention_period`       | number             | `7`                     | Days to retain automated backups.                                                 |
| `skip_final_snapshot`           | bool               | `true`                  | Skip the final snapshot on destroy.                                               |
| `parameters`                    | map(string)        | `{}`                    | DB parameters applied to the parameter group.                                     |
| `tags`                          | map(string)        | `{}`                    | Tags applied to all resources.                                                    |

**Outputs:** `endpoint`, `reader_endpoint` (Aurora only), `port`, `db_name`,
`username`, `password` (sensitive), `security_group_id`.

### AWS Free Tier notes

- `use_aurora = false` — **Aurora has no Free Tier**, so use standard RDS.
- `instance_class = "db.t3.micro"`, `allocated_storage <= 20`.
- `multi_az = false` — **Multi-AZ is not Free Tier eligible**.
- `backup_retention_period = 0` — the newer **AWS Free Tier plan forbids automated
  backups**. Set a value `> 0` on a paid plan.
- `publicly_accessible = false` and `allowed_cidr_blocks` scoped to the VPC CIDR.

### Password handling

The RDS password is **not** hardcoded. It is generated with `random_password` inside
the module when no value is supplied. To set an explicit password, export it as an
environment variable (never commit it):

```bash
export TF_VAR_rds_password="your-strong-password"
```

Retrieve the (generated or provided) password and endpoint from outputs:

```bash
terraform output -raw rds_password
terraform output rds_endpoint
```

## Monitoring (`modules/monitoring`)

The monitoring module installs **kube-prometheus-stack** — a single Helm chart that
bundles Prometheus, Grafana, and AlertManager with pre-configured service monitors for
all Kubernetes system components.

| Variable                | Default               | Description                                          |
| ----------------------- | --------------------- | ---------------------------------------------------- |
| `release_name`          | `kube-prometheus-stack` | Helm release name.                                 |
| `namespace`             | `monitoring`          | Kubernetes namespace (created automatically).        |
| `chart_version`         | `61.7.2`              | kube-prometheus-stack chart version.                 |
| `grafana_admin_password`| –                     | Grafana admin password (**required**, sensitive).    |
| `prometheus_storage_size`| `10Gi`               | PVC size for Prometheus data (EBS volume via CSI).   |

```bash
# Get the Grafana LoadBalancer hostname:
kubectl -n monitoring get svc kube-prometheus-stack-grafana \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
```

## Teardown

```bash
bash scripts/destroy.sh
```

## Security Notes

- `github_pat` is a `sensitive` Terraform variable, injected into Jenkins JCasC at
  apply time; keep it only in `terraform.tfvars` (gitignored) or `TF_VAR_github_pat`.
- `grafana_admin_password` and `rds_password` follow the same pattern — never commit
  them; use `terraform.tfvars` or `TF_VAR_*` environment variables.
- `POSTGRES_PASSWORD` is stored in a Kubernetes Secret (`django-app-rds`), **not** in
  a ConfigMap, so it is base64-encoded at rest and not visible in plain-text API responses.
- Never commit tokens or passwords. If a secret is ever committed, revoke it
  immediately and rotate.
