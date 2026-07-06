resource "kubernetes_namespace_v1" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

# Generate the Jenkins admin password instead of hardcoding it in values.yaml.
resource "random_password" "jenkins_admin" {
  length  = 16
  special = true
}

resource "kubernetes_secret" "jenkins_admin" {
  metadata {
    name      = "jenkins-admin-secret"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }

  data = {
    "jenkins-admin-user"     = "admin"
    "jenkins-admin-password" = random_password.jenkins_admin.result
  }

  type = "Opaque"
}

resource "kubernetes_storage_class_v1" "ebs_sc" {
  metadata {
    name = "ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"

  reclaim_policy       = "Delete"
  volume_binding_mode  = "WaitForFirstConsumer"

  parameters = {
    type = "gp3"
  }
}

resource "aws_iam_role" "jenkins_kaniko_role" {
  name = "${var.cluster_name}-jenkins-kaniko-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:jenkins:jenkins-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "jenkins_ecr_policy" {
  name = "${var.cluster_name}-jenkins-kaniko-ecr-policy"
  role = aws_iam_role.jenkins_kaniko_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "EcrAuthToken"
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories"
        ],
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

resource "helm_release" "jenkins" {
  name             = "jenkins"
  namespace        = kubernetes_namespace_v1.jenkins.metadata[0].name
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = "5.9.32"
  create_namespace = false

  # Jenkins тягне образи та чекає на PVC (EBS), тож даємо більше часу
  timeout         = 900
  cleanup_on_fail = true
  wait            = true

  values = [
    templatefile("${path.module}/values.yaml", {
      kaniko_role_arn = aws_iam_role.jenkins_kaniko_role.arn
      github_username = var.github_username
      github_pat      = var.github_pat
    })
  ]

  depends_on = [
    kubernetes_storage_class_v1.ebs_sc,
    kubernetes_secret.jenkins_admin
  ]
}
