pipeline {
    agent any
    
    tools {
        nodejs "NodeJS_18"
    }
    
    environment {
        IMAGE_REGISTRY = '172.30.10.11:5000' // หรือ port registry ที่คุณใช้จริง เช่น 5000
        IMAGE_NAME = 'test-images'
        IMAGE_PROJECT = 'test-registry' // ถ้าไม่ได้แยก project prefix ใน registry นี้ ให้ลบ
        DOCKER_HOST = "unix:///var/run/docker.sock"
    }

    parameters {
        choice(
            name: 'confirmProcess',
            choices: ['Yes', 'No'],
            description: 'Confirm to proceed?'
        )

        string(
            name: 'customVersion',
            defaultValue: '',
            description: 'Custom version (e.g. 1.2.3) — leave blank to auto-increment'
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

                            if [ -n "$customVersion" ]; then
                                echo "⚙️ Using custom version: $customVersion"
                                npm version $customVersion --no-git-tag-version
                            else
                                echo "🔁 Auto incrementing version (patch)"
                                npm version patch --no-git-tag-version
                            fi

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
                script {
                    IMAGE_TAG = fileExists('.version.txt') ? readFile('.version.txt').trim() : "${env.BUILD_NUMBER}"
                    env.IMAGE_TAG = IMAGE_TAG

                    def IMAGE_FULL_NAME = "${env.IMAGE_REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"

                    sh """
                        echo "📋 Docker version:"
                        docker version

                        echo "🐳 Building Docker image..."
                        docker build -t ${IMAGE_FULL_NAME} -f Dockerfile .

                        echo "📦 Pushing Docker image to local registry..."
                        docker push ${IMAGE_FULL_NAME}

                        echo "✅ Image pushed successfully: ${IMAGE_FULL_NAME}"
                    """
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
                            sed -i 's|image: .*|image: ${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}|g' deployment.yaml
                        """

                        // Commit & Push การเปลี่ยนแปลง
                        withCredentials([usernamePassword(
                            credentialsId: GIT_CREDS,
                            usernameVariable: 'GIT_USER',
                            passwordVariable: 'GIT_PASSWORD'
                        )]) {
                            sh '''
                                        git config user.name "Jenkins Bot"
                                        git config user.email "jenkins@example.com"
                                        git add deployment.yaml
                                        git diff --cached --quiet || git commit -m "[Jenkins] Update image to '$IMAGE_TAG'"
                                        git push https://$GIT_USER:$GIT_PASSWORD@gitlab.com/Pittayasr/k8s-manifests.git HEAD:main
                            '''
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
