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
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    echo "Running the pipeline for branch: ${env.BRANCH_NAME}"
                    def tfvarsFile = 'dev.tfvars'
                    if (env.BRANCH_NAME == 'main') {
                        tfvarsFile = 'main.tfvars'
                    }
                    sh "terraform plan -var-file=${tfvarsFile} -out=tfplan"
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'dev') {
                        input message: "Do you want to apply the plan for branch: ${env.BRANCH_NAME}?", ok: 'Apply'
                    }
                    sh 'terraform apply -auto-approve tfplan'
                }
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
