pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
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
  volumes:
    - name: workspace-volume
      emptyDir: {}
"""
        }
    }

    environment {
        AWS_REGION = 'us-east-1'
        S3_ENDPOINT = 'http://172.30.10.11:9000'
        S3_BUCKET = 'test'
    }

    stages {
        stage('Install & Build') {
            steps {
                container('node') {
                    sh '''
                        npm ci
                        npm run build
                        tar -czf build.tar.gz build/
                        ls -lh build.tar.gz
                    '''
                }
            }
        }

        stage('Upload to MinIO') {
            steps {
                container('awscli') {
                    withCredentials([
                        string(credentialsId: 'MINIO_ACCESS_KEY', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'MINIO_SECRET_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        sh '''
                            aws --endpoint-url $S3_ENDPOINT \
                                s3 cp build.tar.gz s3://$S3_BUCKET/build.tar.gz
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'build.tar.gz', allowEmptyArchive: true
        }
    }
}
