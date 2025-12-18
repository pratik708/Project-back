pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        // Ensure these credentials are created in Jenkins
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION    = 'us-east-1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init'
                sh 'env.$BRANCH_NAME.tfvars'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }

        stage('Terraform Apply') {
            steps {
                // Pauses the pipeline for manual approval
                // input message: 'Do you want to apply the plan?', ok: 'Apply'
                sh 'terraform apply -auto-approve tfplan'
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished successfully!'
            // cleanWs()
        }
    }
}
