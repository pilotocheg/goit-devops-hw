resource "helm_release" "jenkins" {
  name             = "jenkins"
  namespace        = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = "5.9.32"
  create_namespace = true

  # Jenkins тягне образи та чекає на PVC (EBS), тож даємо більше часу
  timeout         = 900
  cleanup_on_fail = true
  wait            = true

  values = [
    file("${path.module}/values.yaml")
  ]
}
