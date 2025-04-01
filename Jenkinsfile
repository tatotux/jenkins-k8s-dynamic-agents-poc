pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: jnlp
                    image: jenkins/inbound-agent:latest
                    args: ['$(JENKINS_SECRET)', '$(JENKINS_NAME)']
                    env:
                    - name: JENKINS_URL
                      value: "http://192.168.1.206:8080"
                    - name: JENKINS_TUNNEL
                      value: "192.168.1.206:50000"
                    - name: JENKINS_AGENT_NAME
                      value: "kubernetes-agent"
                    - name: JENKINS_AGENT_WORKDIR
                      value: "/home/jenkins/agent"
                    resources:
                      requests:
                        cpu: "100m"
                        memory: "256Mi"
                      limits:
                        cpu: "500m"
                        memory: "512Mi"
                    volumeMounts:
                    - name: jenkins-agent
                      mountPath: /home/jenkins/agent
                  volumes:
                  - name: jenkins-agent
                    emptyDir: {}
            '''
            defaultContainer 'jnlp'
            namespace 'jenkins'
            slaveConnectTimeout 60
            retries 3
        }
    }
    
    options {
        timeout(time: 1, unit: 'HOURS')
        retry(3)
        timestamps()
    }
    
    environment {
        POD_NAME = "${env.POD_NAME}"
        POD_NAMESPACE = "${env.POD_NAMESPACE}"
        POD_NUMBER = "${env.POD_NUMBER}"
        POD_IP = "${env.POD_IP}"
        NODE_NAME = "${env.NODE_NAME}"
        JENKINS_AGENT_WORKDIR = "${env.JENKINS_AGENT_WORKDIR}"
        JENKINS_URL = "${env.JENKINS_URL}"
        JENKINS_TUNNEL = "${env.JENKINS_TUNNEL}"
        JENKINS_AGENT_NAME = "${env.JENKINS_AGENT_NAME}"
        WORKSPACE_DIR = "/home/jenkins/agent/workspace/kubernetes-dynamic-agents"
    }
    
    stages {
        stage('Setup Workspace') {
            steps {
                sh '''
                    echo "Setting up workspace..."
                    mkdir -p ${WORKSPACE_DIR}
                    chown -R jenkins:jenkins ${WORKSPACE_DIR}
                    chmod -R 755 ${WORKSPACE_DIR}
                    cd ${WORKSPACE_DIR}
                    pwd
                    ls -la
                '''
            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                    echo "Verifying checkout..."
                    cd ${WORKSPACE_DIR}
                    ls -la
                    git status
                '''
            }
        }
        
        stage('Initialize') {
            steps {
                script {
                    echo "Running on pod: ${POD_NAME}"
                    echo "Pod namespace: ${POD_NAMESPACE}"
                    echo "Pod number: ${POD_NUMBER}"
                    
                    sh '''
                        echo "=== POD DIAGNOSTIC INFO ==="
                        cd ${WORKSPACE_DIR}
                        echo "Current directory: $(pwd)"
                        echo "Workspace contents:"
                        ls -la
                        echo "Container ID: $(hostname)"
                        echo "Node Name: ${NODE_NAME}"
                        echo "Pod IP: ${POD_IP}"
                        echo "Jenkins URL: ${JENKINS_URL}"
                        echo "Jenkins Tunnel: ${JENKINS_TUNNEL}"
                        echo "Jenkins Agent Name: ${JENKINS_AGENT_NAME}"
                        
                        echo "Testing connectivity to Jenkins..."
                        if curl -s -f "${JENKINS_URL}" > /dev/null; then
                            echo "Connection to Jenkins successful"
                        else
                            echo "Connection to Jenkins failed"
                            echo "Testing JNLP port..."
                            if curl -s -f "http://${JENKINS_TUNNEL}" > /dev/null; then
                                echo "JNLP port is accessible"
                            else
                                echo "JNLP port is not accessible"
                                exit 1
                            fi
                        fi
                        
                        echo "======================"
                    '''
                }
            }
        }
        
        stage('Parallel Tasks') {
            parallel {
                stage('Task 1') {
                    steps {
                        script {
                            echo "Running Task 1"
                            sh '''
                                cd ${WORKSPACE_DIR}
                                echo "=== TASK 1 DIAGNOSTIC INFO ==="
                                echo "Task 1 started at $(date)"
                                echo "Container ID: $(hostname)"
                                echo "Current directory: $(pwd)"
                                echo "Node Name: ${NODE_NAME}"
                                echo "Pod IP: ${POD_IP}"
                                echo "Jenkins URL: ${JENKINS_URL}"
                                echo "======================"
                            '''
                        }
                    }
                }
                
                stage('Task 2') {
                    steps {
                        script {
                            echo "Running Task 2"
                            sh '''
                                cd ${WORKSPACE_DIR}
                                echo "=== TASK 2 DIAGNOSTIC INFO ==="
                                echo "Task 2 started at $(date)"
                                echo "Container ID: $(hostname)"
                                echo "Current directory: $(pwd)"
                                echo "Node Name: ${NODE_NAME}"
                                echo "Pod IP: ${POD_IP}"
                                echo "Jenkins URL: ${JENKINS_URL}"
                                echo "======================"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
                    sh '''
                        echo "Cleaning up workspace..."
                        cd ${WORKSPACE_DIR}
                        rm -rf *
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Pipeline completed at ${currentBuild.currentResult}"
                echo "Build number: ${BUILD_NUMBER}"
                echo "Duration: ${currentBuild.durationString}"
            }
        }
        success {
            echo "Pipeline completed successfully"
        }
        failure {
            echo "Pipeline failed"
        }
    }
} 