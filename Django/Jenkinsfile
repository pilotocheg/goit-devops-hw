pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    some-label: jenkins-kaniko
spec:
  serviceAccountName: jenkins-sa
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.16.0-debug
      imagePullPolicy: Always
      command:
        - sleep
      args:
        - 99d
    - name: git
      image: alpine/git:latest
      command:
        - cat
      tty: true
"""
    }
  }

  environment {
    ECR_REGISTRY  = "683210040028.dkr.ecr.eu-central-1.amazonaws.com"
    ECR_REPO      = "terraform-demo-ecr"
    IMAGE_TAG     = "django-app-${BUILD_NUMBER}"
    GITOPS_REPO   = "github.com/pilotocheg/goit-devops-hw.git"
    GITOPS_BRANCH = "main"
    CHART_VALUES  = "charts/django-app/values.yaml"
    COMMIT_EMAIL  = "jenkins@ci.local"
    COMMIT_NAME   = "Jenkins CI"
  }

  stages {
    stage('Build & Push Docker Image') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \\
              --context "$(pwd)/django" \\
              --dockerfile "$(pwd)/django/Dockerfile" \\
              --destination "$ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG"
          '''
        }
      }
    }

    stage('Update Chart Tag in Git') {
      steps {
        container('git') {
          withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PAT')]) {
            sh '''
              set -e
              rm -rf gitops
              git clone -b "$GITOPS_BRANCH" "https://$GIT_USERNAME:$GIT_PAT@$GITOPS_REPO" gitops
              cd gitops

              sed -i "s|^\\( *tag:\\).*|\\1 $IMAGE_TAG|" "$CHART_VALUES"

              git config user.email "$COMMIT_EMAIL"
              git config user.name  "$COMMIT_NAME"

              git add "$CHART_VALUES"
              if git diff --cached --quiet; then
                echo "No tag change; nothing to commit."
              else
                git commit -m "ci: update django-app image tag to $IMAGE_TAG [skip ci]"
                git push origin "$GITOPS_BRANCH"
              fi
            '''
          }
        }
      }
    }
  }
}
