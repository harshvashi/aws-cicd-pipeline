// Jenkinsfile - Jenkins CI/CD Pipeline
// This pipeline orchestrates the build, test, and deployment process

pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        APP_NAME = 'my-app'
        ECR_REPOSITORY = 'my-app-repo'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    stages {
        // ============================================
        // Stage 1: Checkout
        // ============================================
        stage('Checkout') {
            steps {
                script {
                    echo "Checking out code from branch: ${env.BRANCH_NAME}"
                    checkout scm
                }
            }
        }
        
        // ============================================
        // Stage 2: Build
        // ============================================
        stage('Build') {
            steps {
                script {
                    echo "Building application..."
                    sh 'npm ci'
                    sh 'npm run build'
                }
            }
        }
        
        // ============================================
        // Stage 3: Test
        // ============================================
        stage('Test') {
            steps {
                script {
                    echo "Running tests..."
                    sh 'npm test -- --coverage'
                }
            }
            post {
                always {
                    junit 'test-results/**/*.xml'
                    publishHTML(target: [
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        // ============================================
        // Stage 4: Security Scan
        // ============================================
        stage('Security Scan') {
            steps {
                script {
                    echo "Running security scan..."
                    sh 'trivy fs --security-checks vuln .'
                }
            }
        }
        
        // ============================================
        // Stage 5: Build Docker Image
        // ============================================
        stage('Build Docker') {
            steps {
                script {
                    def imageTag = sh(
                        script: "echo ${env.BUILD_NUMBER}-${env.GIT_COMMIT}",
                        returnValue: true
                    )
                    env.IMAGE_TAG = imageTag
                    
                    echo "Building Docker image: ${APP_NAME}:${imageTag}"
                    sh """
                        docker build -t ${ECR_REPOSITORY}:${imageTag} .
                        docker tag ${ECR_REPOSITORY}:${imageTag} ${ECR_REPOSITORY}:latest
                    """
                }
            }
        }
        
        // ============================================
        // Stage 6: Push to ECR
        // ============================================
        stage('Push to ECR') {
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'aws-ecr', variable: 'AWS_ECR_TOKEN')
                    ]) {
                        sh '''
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                            docker push ${ECR_REPOSITORY}:${IMAGE_TAG}
                            docker push ${ECR_REPOSITORY}:latest
                        '''
                    }
                }
            }
        }
        
        // ============================================
        // Stage 7: Terraform Plan
        // ============================================
        stage('Terraform Plan') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    dir('terraform/environments/prod') {
                        sh 'terraform init'
                        sh 'terraform plan -out=tfplan'
                    }
                }
            }
        }
        
        // ============================================
        // Stage 8: Approval (Production only)
        // ============================================
        stage('Approval') {
            when {
                branch 'main'
            }
            steps {
                script {
                    timeout(time: 1, unit: 'HOURS') {
                        def userInput = input(
                            id: 'userInput',
                            message: 'Deploy to Production?',
                            ok: 'Deploy',
                            parameters: [
                                string(name: 'VERSION', defaultValue: "${env.IMAGE_TAG}", description: 'Version to deploy')
                            ]
                        )
                        env.DEPLOY_VERSION = userInput.VERSION
                    }
                }
            }
        }
        
        // ============================================
        // Stage 9: Deploy
        // ============================================
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'aws-ecr', variable: 'AWS_ECR_TOKEN')
                    ]) {
                        sh '''
                            aws ecs update-service \
                                --cluster staging-cluster \
                                --service ${APP_NAME} \
                                --force-new-deployment \
                                --region ${AWS_REGION}
                        '''
                    }
                    
                    // Wait for deployment
                    sh 'aws ecs wait services-stable --cluster staging-cluster --services ${APP_NAME} --region ${AWS_REGION}'
                    
                    // Smoke test
                    sh 'curl -f http://staging.example.com/health || exit 1'
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    withCredentials([
                        string(credentialsId: 'aws-ecr', variable: 'AWS_ECR_TOKEN')
                    ]) {
                        sh '''
                            aws ecs update-service \
                                --cluster prod-cluster \
                                --service ${APP_NAME} \
                                --force-new-deployment \
                                --region ${AWS_REGION}
                        '''
                    }
                    
                    // Wait for deployment
                    sh 'aws ecs wait services-stable --cluster prod-cluster --services ${APP_NAME} --region ${AWS_REGION}'
                    
                    // Smoke test
                    sh 'curl -f http://prod.example.com/health || exit 1'
                }
            }
        }
    }
    
    // ============================================
    // Post-build actions
    // ============================================
    post {
        success {
            echo 'Pipeline completed successfully!'
            emailext(
                subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Build completed successfully.\nCheck console output at ${env.BUILD_URL}",
                to: 'team@example.com'
            )
        }
        failure {
            echo 'Pipeline failed!'
            emailext(
                subject: "FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Build failed.\nCheck console output at ${env.BUILD_URL}",
                to: 'team@example.com'
            )
        }
        always {
            cleanWs()
        }
    }
}