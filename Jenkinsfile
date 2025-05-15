pipeline {
    agent any
    
    tools {
        nodejs "NodeJS_18"
    }
    
    environment {
        AWS_REGION = 'us-east-1'
        S3_ENDPOINT = 'http://172.30.10.11:32001'
        S3_BUCKET = 'test'
        HARBOR_REGISTRY = 'harbor.local.com'
        HARBOR_PROJECT = 'test-registry'
        IMAGE_NAME = 'test-images'
        DOCKER_HOST = "unix:///var/run/docker.sock"
    }

    parameters {
        choice(
            name: 'confirmProcess',
            choices: ['Yes', 'No'],
            description: 'Confirm to proceed?'
        )
    }

    stages {
        stage('Test Docker Access') {
            steps {
                script {
                    try {
                        sh 'docker version'
                        sh 'docker ps'
                    } catch (Exception e) {
                        error("Docker is not accessible. Please check Docker permissions and socket mounting.")
                    }
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install & Build') {
            steps {
                script {
                    if (params.confirmProcess == 'Yes') {
                        sh '''
                            echo "📁 Current path:"
                            pwd
                            echo "📄 List files before build:"
                            ls -alh

                            npm ci

                            # เพิ่ม version แบบ patch (เช่น 1.0.0 -> 1.0.1)
                            npm version patch --no-git-tag-version

                            VERSION=$(node -p "require('./package.json').version")
                            echo "🔖 New version: $VERSION"
                            echo $VERSION > .version.txt

                            npm run build

                            echo "📄 List files after build:"
                            ls -alh

                            tar -czf build.tar.gz build/

                            echo "📦 Compressed build directory:"
                            ls -lh build.tar.gz
                        '''
                    } else {
                        echo "Build cancelled."
                        error('Build cancelled by user.')
                    }
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                sh '''
                    # ตรวจสอบว่ามีไฟล์ .version.txt จริงหรือไม่
                    if [ -f .version.txt ]; then
                        VERSION=$(cat .version.txt)
                        cp build.tar.gz build-v$VERSION.tar.gz
                    else
                        echo "⚠️ Warning: .version.txt not found, using build number instead"
                        cp build.tar.gz build-v${BUILD_NUMBER}.tar.gz
                    fi
                '''
                archiveArtifacts artifacts: 'build*.tar.gz', allowEmptyArchive: true
                archiveArtifacts artifacts: '.version.txt', allowEmptyArchive: true
            }
        }

        stage('Test') {
            when { expression { params.confirmProcess == 'Yes' } }
            steps {
                sh 'npm test'
            }
        }

        stage('Docker Build and Push') {
            when { expression { params.confirmProcess == 'Yes' } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'HARBOR_CREDENTIALS',
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASS'
                )]) {
                    script {
                        try {
                            IMAGE_TAG = ''
                            if (fileExists('.version.txt')) {
                                IMAGE_TAG = readFile('.version.txt').trim()
                            } else {
                                IMAGE_TAG = "${env.BUILD_NUMBER}"
                            }
                            env.IMAGE_TAG = IMAGE_TAG

                            sh '''
                                echo "📋 Docker version:"
                                docker version

                                echo "🐳 Building Docker image..."
                                docker build -t ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile .

                                echo "🔐 Logging in to Harbor registry..."
                                echo "$HARBOR_PASS" | docker login -u $HARBOR_USER --password-stdin ${HARBOR_REGISTRY}

                                echo "📦 Pushing Docker image to Harbor..."
                                docker push ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}

                                echo "✅ Image pushed successfully: ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
                            '''
                        } catch (Exception e) {
                            error("Failed to build or push Docker image: ${e.getMessage()}")
                        }
                    }
                }
            }
        }

        stage('Update Kubernetes Manifest') {
            when { expression { params.confirmProcess == 'Yes' } }
            steps {
                script {
                    // กำหนดค่าตัวแปร
                    def MANIFEST_REPO = "https://gitlab.com/Pittayasr/k8s-manifests.git"
                    def GIT_CREDS = "GITLAB_CREDENTIALS" // Credential ของ Git ใน Jenkins
                    def IMAGE_TAG = readFile('.version.txt').trim() // หรือใช้ env.BUILD_NUMBER

                    // Clone Kubernetes Manifests Repo
                    dir('k8s-manifests') {
                        git url: MANIFEST_REPO, credentialsId: GIT_CREDS, branch: 'main'

                        // แทนที่ VERSION ในไฟล์ deployment.yaml ด้วย Image Tag จริง
                        sh """
                            sed -i 's|harbor.local.com/test-registry/test-images:VERSION|harbor.local.com/test-registry/test-images:${IMAGE_TAG}|g' deployment.yaml
                        """

                        // Commit & Push การเปลี่ยนแปลง
                        withCredentials([usernamePassword(
                            credentialsId: GIT_CREDS,
                            usernameVariable: 'GIT_USER',
                            passwordVariable: 'GIT_PASSWORD'
                        )]) {
                            sh """
                                        git config user.name "Jenkins Bot"
                                        git config user.email "jenkins@example.com"
                                        git add deployment.yaml
                                        git commit -m "[Jenkins] Update image to ${IMAGE_TAG}"
                                        git push https://${GIT_USER}:${GIT_PASSWORD}@github.com/Pittayasr/k8s-manifests.git HEAD:main
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline completed - ${currentBuild.result}"
        }
        success {
            echo "Pipeline succeeded!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
