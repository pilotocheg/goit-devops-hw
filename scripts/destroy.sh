#!/usr/bin/env bash
#
# Complete teardown for the goit-devops-hw stack.
#
# Terraform does NOT track resources created by the in-cluster AWS cloud controller
# (ELBs from LoadBalancer Services) or the EBS CSI driver (PVC volumes). This script
# deletes those first, then runs `terraform destroy`, so nothing is left billing.
#
# Usage:
#   ./scripts/destroy.sh
#   DESTROY_STATE_BACKEND=true ./scripts/destroy.sh   # also remove the S3 state bucket + DynamoDB lock table
#
# Env overrides:
#   AWS_REGION            (default: eu-central-1)
#   CLUSTER_NAME          (default: eks-cluster-demo)
#   DESTROY_STATE_BACKEND (default: false)
#
set -euo pipefail

# Disable the AWS CLI v2 pager so verification output doesn't hijack the terminal
# with `less` (the "(END)" prompt that requires pressing q).
export AWS_PAGER=""

REGION="${AWS_REGION:-eu-central-1}"
CLUSTER_NAME="${CLUSTER_NAME:-eks-cluster-demo}"
DESTROY_STATE_BACKEND="${DESTROY_STATE_BACKEND:-false}"

# Run from the repo root (this script lives in scripts/).
# ${BASH_SOURCE[0]:-$0} keeps this working even if invoked as `zsh scripts/destroy.sh`.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "==> [1/5] Pointing kubectl at the cluster (best-effort)"
if aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
  CLUSTER_UP=true
else
  CLUSTER_UP=false
fi

if [ "$CLUSTER_UP" = true ]; then
  echo "==> [2/5] Deleting LoadBalancer Services (removes AWS ELBs: Jenkins, Argo CD, django-app)"
  kubectl get svc -A \
    -o go-template='{{range .items}}{{if eq .spec.type "LoadBalancer"}}{{.metadata.namespace}} {{.metadata.name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null \
    | while read -r ns name; do
        [ -z "$ns" ] && continue
        echo "    deleting svc $ns/$name"
        kubectl -n "$ns" delete svc "$name" --wait=true 2>/dev/null || true
      done

  echo "==> [3/5] Releasing and deleting PVCs (frees dynamically-provisioned EBS volumes)"
  # A PVC will NOT delete while a pod still mounts it (kubernetes.io/pvc-protection
  # finalizer), so scale the workloads down first, then request deletion WITHOUT
  # blocking. --wait=true here would hang forever if a pod is still attached.
  kubectl -n jenkins scale statefulset --all --replicas=0 2>/dev/null || true
  kubectl -n jenkins delete pvc --all --wait=false 2>/dev/null || true

  echo "    waiting ~60s for AWS to finish deleting the load balancers..."
  sleep 60
else
  echo "==> [2-3/5] Cluster not reachable; skipping in-cluster cleanup"
fi

echo "==> [4/5] terraform destroy (all modules except the state backend)"

# Phase 4a — destroy workloads and data layer first.
# RDS must be fully deleted before VPC networking is torn down; otherwise
# Terraform may destroy the NAT/IGW while the RDS DeleteDBInstance API call
# is still in-flight, causing a DNS resolution failure on the local machine.
echo "    [4a/4b] destroying workloads, RDS, ECR (keeping VPC up)..."
terraform destroy -auto-approve \
  -target=module.argo_cd \
  -target=module.jenkins \
  -target=module.rds \
  -target=module.eks \
  -target=module.ecr

# Phase 4b — VPC is safe to remove only after all resources inside it are gone.
echo "    [4b/4b] destroying VPC..."
terraform destroy -auto-approve \
  -target=module.vpc

if [ "$DESTROY_STATE_BACKEND" = true ]; then
  echo "==> [5/5] Removing the Terraform state backend (S3 bucket + DynamoDB table)"
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
  BUCKET="terraform-demo-bucket-${ACCOUNT_ID}"
  TABLE="terraform-demo-locks"

  echo "    emptying and deleting s3://${BUCKET}"
  aws s3 rm "s3://${BUCKET}" --recursive --region "$REGION" 2>/dev/null || true
  # Purge object versions and delete markers (bucket has versioning enabled).
  aws s3api delete-objects --bucket "$BUCKET" --region "$REGION" \
    --delete "$(aws s3api list-object-versions --bucket "$BUCKET" --region "$REGION" \
      --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null)" 2>/dev/null || true
  aws s3api delete-objects --bucket "$BUCKET" --region "$REGION" \
    --delete "$(aws s3api list-object-versions --bucket "$BUCKET" --region "$REGION" \
      --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null)" 2>/dev/null || true
  aws s3api delete-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null || true

  echo "    deleting DynamoDB table ${TABLE}"
  aws dynamodb delete-table --table-name "$TABLE" --region "$REGION" >/dev/null 2>&1 || true
else
  echo "==> [5/5] Skipping state backend removal (idle cost is negligible)."
  echo "    To also remove it, re-run with: DESTROY_STATE_BACKEND=true ./scripts/destroy.sh"
fi

echo ""
echo "==> Verification (each line should be empty / None):"
printf -- "-- EKS clusters:   "; aws eks list-clusters --region "$REGION" --query 'clusters' --output text
printf -- "-- Running EC2:    "; aws ec2 describe-instances --region "$REGION" --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text
printf -- "-- ELBv2 (NLB/ALB):"; aws elbv2 describe-load-balancers --region "$REGION" --query 'LoadBalancers[].LoadBalancerName' --output text
printf -- "-- Classic ELB:    "; aws elb describe-load-balancers --region "$REGION" --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text
printf -- "-- Available EBS:  "; aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text

echo ""
echo "Teardown complete."
