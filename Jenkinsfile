pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  hostAliases:
  - ip: "172.30.10.11"
    hostnames:
    - "harbor.local.com"
  volumes:
  - name: harbor-ca
    configMap:
      name: harbor-ca-cert

  containers:
  - name: node
    image: node:18-alpine
    command:
    - cat
    tty: true
    volumeMounts:
      - name: workspace-volume
        mountPath: /home/jenkins/agent
  - name: awscli
    image: amazon/aws-cli
    command:
    - cat
    tty: true
    volumeMounts:
      - name: workspace-volume
        mountPath: /home/jenkins/agent
  - name: docker
    image: docker:24.0-cli  
    command:
    - cat
    tty: true
    volumeMounts:
      - name: workspace-volume
        mountPath: /home/jenkins/agent
      - name: docker-sock
        mountPath: /var/run/docker.sock
      - name: harbor-ca
        mountPath: /usr/local/share/ca-certificates/extra/
  - name: dind
    image: docker:24.0-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_EXTRA_OPTS
      value: "--dns 172.30.10.11 --dns 8.8.8.8"
    volumeMounts:
      - name: docker-graph
        mountPath: /var/lib/docker
  volumes:
    - name: workspace-volume
      emptyDir: {}
    - name: docker-graph
      emptyDir: {}
    - name: docker-sock
      hostPath:
        path: /var/run/docker.sock
"""
        }
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
        stage('Checkout') {
        steps {
            checkout scm
            }
        }

        stage('Archive Artifacts') {
        steps {
            container('node') {
                sh '''
                    VERSION=$(cat .version.txt)
                    cp build.tar.gz build-v$VERSION.tar.gz
                '''
            }

            archiveArtifacts artifacts: 'build*.tar.gz', allowEmptyArchive: true
            archiveArtifacts artifacts: '.version.txt', allowEmptyArchive: true
    }
}

        
        stage('Check ping and Curl') {
        steps {
            sh '''
                echo "🔍 Testing DNS:"
                ping -c 3 harbor.local.com || true

                echo "🔍 Testing curl:"
                curl -v https://harbor.local.com || true
            '''
            }
        }

        stage('Set Version') {
            steps {
                script {
                    // ใช้ BUILD_NUMBER เป็น tag
                    env.IMAGE_TAG = "v${env.BUILD_NUMBER}"
                }
            }
        }

        stage('Install & Build') {
            steps {
                script {
                    if (params.confirmProcess == 'Yes') {
                        container('node') {
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
                        }
                    } else {
                        echo "Build cancelled."
                        error('Build cancelled by user.')
                    }
                }
            }
        }

        stage('Test') {
            when { expression { params.confirmProcess == 'Yes' } }
            steps {
                container('node') {
                    sh 'npm test'
                }
            }
        }

        // stage('Linting') {
        //     when { expression { params.confirmProcess == 'Yes' } }
        //     steps {
        //         container('node') {
        //             sh 'npm run lint'
        //         }
        //     }
        // }

        // stage('Security Scan') {
        //     when { expression { params.confirmProcess == 'Yes' } }
        //     steps {
        //         container('node') {
        //             withCredentials([string(credentialsId: 'SNYK_API_TOKEN', variable: 'SNYK_TOKEN')]) {
        //                 sh 'npx snyk test --file=package-lock.json --severity-threshold=high'
        //                 sh 'npx snyk monitor'
        //             }
        //         }
        //     }
        // }

        stage('Upload to MinIO') {
            when { expression { params.confirmProcess == 'Yes' } }
            steps {
                container('awscli') {
                    withCredentials([
                        string(credentialsId: 'MINIO_ACCESS_KEY', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'MINIO_SECRET_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            VERSION=$(cat .version.txt)
                            echo "📦 Uploading build-v$VERSION.tar.gz to MinIO..."

                            mv build.tar.gz build-v$VERSION.tar.gz

                            aws --endpoint-url $S3_ENDPOINT \
                                s3 cp build-v$VERSION.tar.gz s3://$S3_BUCKET/build-v$VERSION.tar.gz
                        '''
                    }
                }
            }
        }


        stage('Docker Build and Push') {
            when { expression { params.confirmProcess == 'Yes' } }
            steps {
                container('docker') {
                    withCredentials([usernamePassword(
                        credentialsId: 'HARBOR_CREDENTIALS',
                        usernameVariable: 'HARBOR_USER',
                        passwordVariable: 'HARBOR_PASS'
                    )]) {
                        sh '''
                            echo "📋 Docker version:"
                            docker version

                            echo "📁 Current path:"
                            pwd
                            echo "📄 List files:"
                            ls -lah

                            echo "🛠️ Installing CA tools..."
                            apk add --no-cache ca-certificates
                            
                            echo "🛠️ Update trusted certs..."
                            update-ca-certificates

                            echo "🔧 Go to correct workspace"
                            cd ${WORKSPACE}

                            echo "📦 Extracting build..."
                            tar -xzf build.tar.gz

                            echo "🐳 Build Docker image..."                          
                            docker build -t ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile .

                            echo "🔐 Login to Harbor..."
                            echo "$HARBOR_PASS" | docker login -u $HARBOR_USER --password-stdin ${HARBOR_REGISTRY}

                            echo "📦 Push Docker image to Harbor..."
                            docker push ${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}
                        '''
                    }
                }
            }
        }
    }
}
