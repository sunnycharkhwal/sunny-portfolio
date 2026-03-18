// ============================================================
// Jenkinsfile — Full CI/CD Pipeline
// Push to GitHub → Jenkins CI → CD → EKS via ArgoCD
// ============================================================

pipeline {
    agent any

    environment {
        AWS_REGION       = 'us-east-1'                    // Keep in sync with variables.tf
        ECR_REPO         = credentials('ECR_REPO_URL')    // Set in Jenkins → Credentials
        IMAGE_NAME       = 'sunny-portfolio'
        IMAGE_TAG        = "${BUILD_NUMBER}"
        SONAR_HOST       = credentials('SONAR_HOST_URL')
        SONAR_TOKEN      = credentials('SONAR_AUTH_TOKEN')
        GITHUB_REPO      = 'https://github.com/sunnycharkhwal/sunny-portfolio.git'
        GIT_CREDENTIALS  = credentials('github-token')
    }

    stages {

        // ── 1. Pull Code ──────────────────────────────────────
        stage('Pull Code') {
            steps {
                git branch: 'main',
                    url: "${GITHUB_REPO}",
                    credentialsId: 'github-token'
                echo "✅ Code pulled from ${GITHUB_REPO}"
            }
        }

        // ── 2. OWASP Dependency Check ─────────────────────────
        stage('OWASP Dependency Check') {
            steps {
                sh '''
                    dependency-check \
                      --project sunny-portfolio \
                      --scan . \
                      --format HTML \
                      --out reports/dependency-check-report.html \
                      --nvdApiKey ${NVD_API_KEY} \
                      --failOnCVSS 7
                '''
            }
            post {
                always {
                    publishHTML([
                        reportDir: 'reports',
                        reportFiles: 'dependency-check-report.html',
                        reportName: 'OWASP Dependency Check'
                    ])
                }
            }
        }

        // ── 3. SonarQube Analysis ─────────────────────────────
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        docker run --rm \
                          -e SONAR_HOST_URL="${SONAR_HOST}" \
                          -e SONAR_TOKEN="${SONAR_TOKEN}" \
                          -v "$(pwd):/usr/src" \
                          sonarsource/sonar-scanner-cli \
                          -Dsonar.projectKey=sunny-portfolio \
                          -Dsonar.sources=/usr/src/src \
                          -Dsonar.host.url="${SONAR_HOST}" \
                          -Dsonar.token="${SONAR_TOKEN}"
                    '''
                }
            }
        }

        // ── 4. Quality Gate ───────────────────────────────────
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
                echo "✅ SonarQube Quality Gate passed"
            }
        }

        // ── 5. Docker Build ───────────────────────────────────
        stage('Docker Build') {
            steps {
                sh """
                    docker build \
                      -t ${IMAGE_NAME}:${IMAGE_TAG} \
                      -t ${IMAGE_NAME}:latest \
                      .
                """
                echo "✅ Docker image built: ${IMAGE_NAME}:${IMAGE_TAG}"
            }
        }

        // ── 6. Trivy Image Scan ───────────────────────────────
        stage('Trivy Image Scan') {
            steps {
                sh """
                    trivy image \
                      --exit-code 0 \
                      --severity HIGH,CRITICAL \
                      --format table \
                      --output reports/trivy-image-report.txt \
                      ${IMAGE_NAME}:${IMAGE_TAG}
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/trivy-image-report.txt', allowEmptyArchive: true
                }
            }
        }

        // ── 7. Docker Push to ECR ─────────────────────────────
        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                      docker login --username AWS --password-stdin ${ECR_REPO}

                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
                    docker tag ${IMAGE_NAME}:latest       ${ECR_REPO}:latest

                    docker push ${ECR_REPO}:${IMAGE_TAG}
                    docker push ${ECR_REPO}:latest
                """
                echo "✅ Image pushed to ECR: ${ECR_REPO}:${IMAGE_TAG}"
            }
        }

        // ── 8. Trigger Jenkins CD Job ─────────────────────────
        stage('Trigger CD Job') {
            steps {
                build job: 'sunny-portfolio-cd',
                      parameters: [string(name: 'IMAGE_TAG', value: "${IMAGE_TAG}")],
                      wait: false
                echo "✅ CD job triggered with IMAGE_TAG=${IMAGE_TAG}"
            }
        }
    }

    post {
        success {
            emailext(
                to: 'sunny@example.com',
                subject: "✅ [CI] ${JOB_NAME} #${BUILD_NUMBER} SUCCESS",
                body: "Build ${BUILD_NUMBER} succeeded.\nImage: ${ECR_REPO}:${IMAGE_TAG}\nView: ${BUILD_URL}"
            )
        }
        failure {
            emailext(
                to: 'sunny@example.com',
                subject: "❌ [CI] ${JOB_NAME} #${BUILD_NUMBER} FAILED",
                body: "Build ${BUILD_NUMBER} failed.\nSee console output: ${BUILD_URL}console"
            )
        }
        always {
            cleanWs()
        }
    }
}
