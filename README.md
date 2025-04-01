# Jenkins Kubernetes Dynamic Agents Setup

This guide documents the setup of Jenkins with dynamic Kubernetes agents using Minikube, including troubleshooting steps and common issues.

## Prerequisites

- Ubuntu 24.04.2 LTS
- Jenkins installed and running
- Minikube installed
- Docker installed
- kubectl installed

## Video

[![Jenkins Kubernetes Dynamic Agents Setup Demo](/jenkins_k8s.gif)](https://www.youtube.com/watch?v=bi77RTDzjiY)

Click on the image above to watch the video on YouTube.

## Initial Setup

### 1. Fix Docker Permissions

First, we need to ensure the user has proper permissions to access Docker:

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply the new group membership without logging out
newgrp docker
```

### 2. Configure Minikube

Start Minikube with Docker driver:

```bash
# Stop and delete existing Minikube instance if any
minikube stop
minikube delete

# Start Minikube with Docker driver
minikube start --driver=docker

# Verify Minikube status
minikube status

# Get Minikube IP (needed for Jenkins configuration)
minikube ip
```

### 3. Configure Jenkins JNLP Port

Before proceeding, configure Jenkins to use a fixed port for JNLP agents:

1. Go to "Manage Jenkins" > "Configure Global Security"
2. Scroll down to "TCP port for JNLP agents"
3. Select "Fixed" and set the port to 50000
4. Click "Save"

This is crucial for Kubernetes agents to connect properly. The fixed port ensures consistent communication between Jenkins and the agents.

### 4. Create Jenkins Namespace and Secret

Create the Jenkins namespace and configure the secret for agent communication:

```bash
# Create Jenkins namespace
kubectl create namespace jenkins

# Create Jenkins secret using the JNLP secret
sudo cat /var/lib/jenkins/secrets/jenkins.slaves.JnlpSlaveAgentProtocol.secret | \
kubectl create secret generic jenkins-agent-secret \
    --from-file=secret=/dev/stdin \
    -n jenkins
```

### 5. Get Kubernetes Certificate and Credentials

Get the Minikube CA certificate and credentials for Jenkins configuration:

```bash
# Get the certificate content
cat /home/tatotux/.minikube/ca.crt

# Get the client certificate and key
cat /home/tatotux/.minikube/profiles/minikube/client.crt
cat /home/tatotux/.minikube/profiles/minikube/client.key
```

## Jenkins Configuration

### 1. Install Kubernetes Plugin

1. Go to "Manage Jenkins" > "Manage Plugins"
2. Click on "Available" tab
3. Search for "Kubernetes"
4. Check the box next to "Kubernetes plugin"
5. Click "Install without restart"

### 2. Configure Kubernetes Credentials

1. Go to "Manage Jenkins" > "Manage Credentials"
2. Click on "(global)" under "Stores scoped to Jenkins"
3. Click "Add Credentials"
4. Configure the Kubernetes credentials:
   - Kind: Kubernetes configuration
   - ID: kubernetes-config
   - Description: Kubernetes configuration for dynamic agents
   - Server Certificate Key: Paste the content of the Minikube CA certificate
   - Client Certificate Key: Paste the content of the client certificate
   - Client Key: Paste the content of the client key
   - Click "OK"

### 3. Configure Kubernetes Cloud

1. Go to "Manage Jenkins" > "Configure Clouds"
2. Click "Add a new cloud"
3. Select "Kubernetes"
4. Configure with these settings:
   - Name: kubernetes
   - Kubernetes URL: https://192.168.49.2:8443 (use your Minikube IP)
   - Jenkins URL: http://192.168.1.206:8080 (use your Jenkins server IP)
   - Jenkins tunnel: 192.168.1.206:50000 (use your Jenkins server IP)
   - Pod Labels: jenkins-agent=jenkins-agent
   - Kubernetes Credentials: Select the kubernetes-config credential we just created

5. Under "Pod Templates":
   - Name: jenkins-agent
   - Namespace: jenkins
   - Labels: jenkins-agent
   - Usage: Use this node as much as possible
   - Container Template:
     - Name: jnlp
     - Docker image: jenkins/inbound-agent:latest

6. Click "Save"

7. Restart Jenkins to apply changes:
```bash
sudo systemctl restart jenkins
```

## Diagnostic and Verification Steps

### 1. Verify Jenkins Accessibility

```bash
# Check if Jenkins is accessible
curl -I http://192.168.1.206:8080

# Check Jenkins agent port (after configuring fixed port)
curl -I http://192.168.1.206:50000
```

### 2. Verify Kubernetes Cluster Status

```bash
# Check Minikube status
minikube status

# Check Kubernetes cluster status
kubectl cluster-info

# Check if we can access the Kubernetes API
kubectl get nodes
```

### 3. Verify Jenkins Namespace and Resources

```bash
# List all resources in jenkins namespace
kubectl get all -n jenkins

# List pods in jenkins namespace
kubectl get pods -n jenkins

# List secrets in jenkins namespace
kubectl get secrets -n jenkins

# Check specific pod details
kubectl describe pod <pod-name> -n jenkins
```

### 4. Verify Pod Communication

```bash
# Test network connectivity from pod to Jenkins
kubectl exec <pod-name> -n jenkins -c jenkins-agent -- ping -c 1 192.168.1.206

# Check pod environment variables
kubectl exec <pod-name> -n jenkins -c jenkins-agent -- env

# Check pod logs
kubectl logs <pod-name> -n jenkins -c jenkins-agent
kubectl logs <pod-name> -n jenkins -c jnlp
```

### 5. Verify Jenkins Agent Secret

```bash
# Check if secret exists
kubectl get secret jenkins-agent-secret -n jenkins

# Verify secret content (base64 encoded)
kubectl get secret jenkins-agent-secret -n jenkins -o yaml
```

### 6. Common Issues and Solutions

1. **Pod Creation Fails**
   ```bash
   # Check pod events for errors
   kubectl describe pod <pod-name> -n jenkins
   
   # Check pod logs
   kubectl logs <pod-name> -n jenkins
   ```

2. **Agent Connection Issues**
   ```bash
   # Check Jenkins agent logs
   kubectl logs <pod-name> -n jenkins -c jnlp
   
   # Verify Jenkins agent secret
   kubectl get secret jenkins-agent-secret -n jenkins
   ```

3. **Network Issues**
   ```bash
   # Test network connectivity
   kubectl exec <pod-name> -n jenkins -c jenkins-agent -- ping -c 1 192.168.1.206
   
   # Check pod IP and network configuration
   kubectl describe pod <pod-name> -n jenkins
   ```

4. **Permission Issues**
   ```bash
   # Check service account permissions
   kubectl auth can-i create pods --as=system:serviceaccount:jenkins:default
   
   # Check pod security context
   kubectl describe pod <pod-name> -n jenkins
   ```

### 7. Cleanup and Reset

```bash
# Delete all pods in jenkins namespace
kubectl delete pods --all -n jenkins

# Delete and recreate secret
kubectl delete secret jenkins-agent-secret -n jenkins
sudo cat /var/lib/jenkins/secrets/jenkins.slaves.JnlpSlaveAgentProtocol.secret | \
kubectl create secret generic jenkins-agent-secret \
    --from-file=secret=/dev/stdin \
    -n jenkins

# Restart Jenkins
sudo systemctl restart jenkins
```

### 8. Pod and Jenkins Communication Verification

To verify the communication between Kubernetes pods and Jenkins, we can perform a series of tests:

1. **Create a Test Pod**
   ```bash
   # Create a test pod with busybox
   kubectl run test-connection --image=busybox -n jenkins -- sleep 3600
   
   # Verify that the pod is running
   kubectl get pod test-connection -n jenkins
   ```

2. **Verify Basic Connectivity**
   ```bash
   # Test ping to Jenkins
   kubectl exec test-connection -n jenkins -- ping -c 1 192.168.1.206
   ```

3. **Verify Jenkins Access (Port 8080)**
   ```bash
   # Test access to port 8080
   kubectl exec test-connection -n jenkins -- wget -qO- http://192.168.1.206:8080
   # Note: The 403 error is normal as it requires authentication
   ```

4. **Verify JNLP Port Access (50000)**
   ```bash
   # Test access to JNLP port
   kubectl exec test-connection -n jenkins -- nc -zv 192.168.1.206 50000
   ```

5. **Verify Port Status in Jenkins**
   ```bash
   # Verify that Jenkins is listening on port 50000
   sudo netstat -tulpn | grep 50000
   
   # Check firewall status
   sudo ufw status
   ```

#### Results Interpretation

- ✅ **Basic Connectivity**: If ping is successful, indicates that the network is properly configured
- ✅ **Port 8080**: If receiving a 403 response, indicates that Jenkins is accessible (the 403 error is normal as it requires authentication)
- ✅ **Port 50000**: If the port is open, indicates that the JNLP service is available
- ✅ **Firewall**: If inactive, indicates there are no network restrictions

#### Common Issues and Solutions

1. **If ping fails**:
   - Verify Minikube network configuration
   - Check if the pod is on the same network as Jenkins
   - Verify DNS configuration

2. **If port 8080 is not accessible**:
   - Verify that Jenkins is running
   - Check network configuration
   - Verify that no firewall is blocking the port

3. **If port 50000 is not accessible**:
   - Verify JNLP port configuration in Jenkins
   - Check that Jenkins is listening on all interfaces (0.0.0.0)
   - Verify that no firewall is blocking the port

4. **If firewall is active**:
   ```bash
   # Allow traffic on required ports
   sudo ufw allow 8080
   sudo ufw allow 50000
   ```

#### Cleanup

After testing, remove the test pod:
```bash
kubectl delete pod test-connection -n jenkins
```

### 9. Examples of Commands and Results

This section shows the commands executed and their results for verifying the configuration:

#### 1. Verify Pod Status
```bash
$ kubectl get pods -n jenkins
NAME                                             READY   STATUS      RESTARTS   AGE
kubernetes-dynamic-agents-10-c7120-cvj8t-wltkp   0/1     Completed   0          5m42s
kubernetes-dynamic-agents-9-090cw-7cs7r-xxszp    0/1     Completed   0          6m32s
```

#### 2. Verify Node Status
```bash
$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   78m   v1.32.0
```

#### 3. Verify Jenkins Accessibility
```bash
$ curl -I http://192.168.1.206:8080
HTTP/1.1 403 Forbidden
Server: Jetty(12.0.18)
Date: Tue, 01 Apr 2025 05:52:12 GMT
X-Content-Type-Options: nosniff
Set-Cookie: JSESSIONID.6c773d4e=node0194p2fn6r3bttvx1as16nz7jh290.node0; Path=/; HttpOnly
Expires: Thu, 01 Jan 1970 00:00:00 GMT
Content-Type: text/html;charset=utf-8
X-Hudson: 1.395
X-Jenkins: 2.503
X-Jenkins-Session: 6405fd06
Transfer-Encoding: chunked
```

#### 4. Verify Firewall Status
```bash
$ sudo ufw status
Status: inactive
```

#### 5. Verify JNLP Port
```bash
$ sudo netstat -tulpn | grep 50000
tcp6       0      0 :::50000                :::*                    LISTEN      85970/java
```

#### 6. Create and Verify Test Pod
```bash
# Create test pod
$ kubectl run test-connection --image=busybox -n jenkins -- sleep 3600
pod/test-connection created

# Verify pod status
$ kubectl get pod test-connection -n jenkins
NAME              READY   STATUS    RESTARTS   AGE
test-connection   1/1     Running   0          10s
```

#### 7. Verify Connectivity from Pod
```bash
# Test ping to Jenkins
$ kubectl exec test-connection -n jenkins -- ping -c 1 192.168.1.206
PING 192.168.1.206 (192.168.1.206): 56 data bytes
64 bytes from 192.168.1.206: seq=0 ttl=63 time=0.171 ms

--- 192.168.1.206 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.171/0.171/0.171 ms

# Test access to port 8080
$ kubectl exec test-connection -n jenkins -- wget -qO- http://192.168.1.206:8080
wget: server returned error: HTTP/1.1 403 Forbidden
command terminated with exit code 1

# Test access to JNLP port
$ kubectl exec test-connection -n jenkins -- nc -zv 192.168.1.206 50000
192.168.1.206 (192.168.1.206:50000) open
```

#### 8. Verify Pod Details
```bash
$ kubectl describe pod kubernetes-dynamic-agents-10-c7120-cvj8t-wltkp -n jenkins
Name:             kubernetes-dynamic-agents-10-c7120-cvj8t-wltkp
Namespace:        jenkins
Priority:         0
Service Account:  default
Node:             minikube/192.168.49.2
Start Time:       Mon, 31 Mar 2025 23:46:15 -0600
Labels:           jenkins-agent=jenkins-agent
                  jenkins/label=kubernetes-dynamic-agents_10-c7120
                  jenkins/label-digest=2075b0b9f5651c512977e3863eadf92658631afc
                  kubernetes.jenkins.io/controller=http___192_168_1_206_8080x
Annotations:      buildUrl: http://192.168.1.206:8080/job/kubernetes-dynamic-agents/10/
                  kubernetes.jenkins.io/last-refresh: 1743486375490
                  runUrl: job/kubernetes-dynamic-agents/10/
Status:           Succeeded
IP:               10.244.0.15
IPs:
  IP:  10.244.0.15
Containers:
  jnlp:
    Container ID:   docker://ff4477c775059f2feae9668335e9b40c1ac9f90f0d6b65f13a1dde5b5fef9be9
    Image:          jenkins/inbound-agent:latest
    Image ID:       docker-pullable://jenkins/inbound-agent@sha256:5446c06d73538a725b267aa303b80bbb89e36d2d71bbe4ffa4a7ba57cda54bf2
    Port:           <none>
    Host Port:      <none>
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 31 Mar 2025 23:46:16 -0600
      Finished:     Mon, 31 Mar 2025 23:46:16 -0600
    Ready:          False
    Restart Count:  0
    Requests:
      cpu:     100m
      memory:  256Mi
    Environment:
      JENKINS_SECRET:         <set to the key 'secret' in secret 'jenkins-agent-secret'>  Optional: false
      JENKINS_TUNNEL:         192.168.1.206:50000
      JENKINS_AGENT_NAME:     kubernetes-dynamic-agents-10-c7120-cvj8t-wltkp (v1:metadata.name)
      NODE_NAME:               (v1:spec.nodeName)
      POD_NAME:               kubernetes-dynamic-agents-10-c7120-cvj8t-wltkp (v1:metadata.name)
      REMOTING_OPTS:          -noReconnectAfter 1d
      JENKINS_NAME:           kubernetes-dynamic-agents-10-c7120-cvj8t-wltkp (v1:metadata.name)
      JENKINS_AGENT_WORKDIR:  /home/jenkins/agent
      POD_IP:                  (v1:status.podIP)
      JENKINS_URL:            http://192.168.1.206:8080
      POD_NAMESPACE:          jenkins (v1:metadata.namespace)
    Mounts:
      /home/jenkins/agent from workspace-volume (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-b5dtl (ro)
```

#### 9. Verify Pod Logs
```bash
$ kubectl logs kubernetes-dynamic-agents-10-c7120-cvj8t-wltkp -n jenkins -c jnlp
WARNING: Providing the secret and agent name as positional arguments is deprecated; use "-secret" and "-name" instead.
Cannot provide secret via both named and positional arguments
java -jar agent.jar [options...]
 -agentLog FILE                         : Local agent error log destination
                                          (overrides workDir)
 -auth user:pass                        : (deprecated) unused; use -credentials
                                          or -proxyCredentials
 -cert VAL                              : Specify additional X.509 encoded PEM
                                          certificates to trust when connecting
                                          to Jenkins root URLs. If starting
                                          with @ then the remainder is assumed
                                          to be the name of the certificate
                                          file to read.
 -connectTo HOST:PORT                   : (deprecated) make a TCP connection to
                                          the given host and port, then start
                                          communication.
 -credentials (-jnlpCredentials)        : HTTP BASIC AUTH header to pass in for
 USER:PASSWORD                            making HTTP requests.
 -direct (-directConnection) HOST:PORT  : Connect directly to this TCP agent
                                          port, skipping the HTTP(S) connection
                                          parameter download. For example,
                                          "myjenkins:50000".
 -failIfWorkDirIsMissing                : Fails the initialization if the
                                          requested workDir or internalDir are
                                          missing ('false' by default)
                                          (default: false)
 -headless                              : (deprecated; now always headless)
 -help                                  : Show this help message (default:
                                          false)
 -instanceIdentity VAL                  : The base64 encoded InstanceIdentity
                                          byte array of the Jenkins controller.
                                          When this is set, the agent skips
                                          connecting to an HTTP(S) port for
                                          connection info.
 -internalDir VAL                       : Specifies a name of the internal
                                          files within a working directory
                                          ('remoting' by default) (default:
                                          remoting)
 -jar-cache DIR                         : Cache directory that stores jar files
                                          sent from the controller
 -jnlpUrl URL                           : instead of talking to the controller
                                          via stdin/stdout, emulate a JNLP
                                          client by making a TCP connection to
                                          the controller. Connection parameters
                                          are obtained by parsing the JNLP file.
 -loggingConfig FILE                    : Path to the property file with
                                          java.util.logging settings
 -name VAL                              : Name of the agent. (default:
                                          kubernetes-dynamic-agents-10-c7120-cvj8t-wltkp)
 -noCertificateCheck (-disableHttpsCert : Ignore SSL validation errors - use as
 Validation)                              a last resort only. (default: false)
 -noKeepAlive                           : Disable TCP socket keep alive on
                                          connection to the controller.
                                          (default: false)
 -noReconnect (-noreconnect)            : Doesn't try to reconnect when a
                                          communication fail, and exit instead
                                          (default: false)
 -noReconnectAfter DURATION             : Bail out after the given time after
                                          the first attempt to reconnect
                                          (default: 1 day)
 -ping                                  : (deprecated; now always pings)
 -protocols VAL                         : Specify the remoting protocols to
                                          attempt when instanceIdentity is
                                          provided.
 -proxyCredentials USER:PASSWORD        : HTTP BASIC AUTH header to pass in for
                                          making HTTP authenticated proxy
                                          requests.
 -secret HEX_SECRET                     : Agent connection secret. (default:
ya][K)                                ;NJ:c%Ev
 -tcp FILE                              : (deprecated) instead of talking to
                                          the controller via stdin/stdout,
                                          listens to a random local port, write
                                          that port number to the given file,
                                          then wait for the controller to
                                          connect to that port.
 -text                                  : encode communication with the
                                          controller with base64. Useful for
                                          running agent over 8-bit unsafe
                                          protocol like telnet
 -tunnel HOST:PORT                      : Connect to the specified host and
                                          port, instead of connecting directly
                                          to Jenkins. Useful when connection to
                                          Jenkins needs to be tunneled. Can be
                                          also HOST: or :PORT, in which case
                                          the missing portion will be
                                          auto-configured like the default
                                          behavior. (default: 192.168.1.206:5000
                                          0)
 -url URL                               : Specify the Jenkins root URLs to
                                          connect to. (default: http://192.168.1
                                          .206:8080)
 -version                               : Shows the version of the remoting jar
                                          and then exits (default: false)
 -webSocket                             : Make a WebSocket connection to
                                          Jenkins rather than using the TCP
                                          port. (default: false)
 -webSocketHeader NAME=VALUE            : Additional WebSocket header to set,
                                          eg for authenticating with reverse
                                          proxies. To specify multiple headers,
                                          call this flag multiple times, one
                                          with each header
 -workDir FILE                          : Declares the working directory of the
                                          remoting instance (stores cache and
                                          logs by default) (default:
                                          /home/jenkins/agent)
```

#### 10. Cleanup Test Pod
```bash
$ kubectl delete pod test-connection -n jenkins
pod "test-connection" deleted
```

These commands and their results show the complete state of the system and can be used as a reference to verify the correct configuration of Jenkins with dynamic Kubernetes agents.

## Pipeline Configuration

### 1. Jenkinsfile Structure

The Jenkinsfile is configured to use Kubernetes dynamic agents with the following structure:

```groovy
pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins/kubernetes/jenkins-agent.yaml'
            defaultContainer 'jnlp'
            namespace 'jenkins'
        }
    }
    
    options {
        timeout(time: 1, unit: 'HOURS')
    }
    
    environment {
        POD_NAME = "${env.POD_NAME}"
        POD_NAMESPACE = "${env.POD_NAMESPACE}"
        POD_NUMBER = "${env.POD_NUMBER}"
    }
    
    stages {
        // Your stages here
    }
}
```

### 2. Pod Template Configuration

Each pod template in the Jenkinsfile should include:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins-agent: pod-name
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    env:
    - name: POD_NUMBER
      value: "1"
    - name: JENKINS_URL
      value: "http://192.168.1.206:8080"
    - name: JENKINS_TUNNEL
      value: "192.168.1.206:50000"
    - name: JENKINS_SECRET
      valueFrom:
        secretKeyRef:
          name: jenkins-agent-secret
          key: secret
    - name: JENKINS_AGENT_NAME
      value: "pod-name"
    - name: JENKINS_NAME
      value: "pod-name"
```

### 3. Jenkins Agent YAML Configuration

The `jenkins-agent.yaml` file should be configured as follows:

```yaml
apiVersion: v1
kind: Pod
metadata:
  namespace: jenkins
  labels:
    jenkins-agent: jenkins-agent
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    imagePullPolicy: Always
    env:
    - name: JENKINS_URL
      value: "http://192.168.1.206:8080"
    - name: JENKINS_TUNNEL
      value: "192.168.1.206:50000"
    - name: JENKINS_SECRET
      valueFrom:
        secretKeyRef:
          name: jenkins-agent-secret
          key: secret
    - name: JENKINS_AGENT_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: JENKINS_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: JENKINS_AGENT_WORKDIR
      value: "/home/jenkins/agent"
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  volumes:
  - name: workspace-volume
    emptyDir: {}
  restartPolicy: Never
```