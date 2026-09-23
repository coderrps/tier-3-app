# Three-Tier Application — Complete Deployment Guide

This document contains the commands used to deploy the three-tier application on AWS EKS.

## Architecture

```text
Internet
   |
   v
AWS Application Load Balancer
   |
   v
Kubernetes Ingress
   |
   +-------------------+
   |                   |
   v                   v
Frontend Service    Backend Service
   |                   |
   v                   v
Frontend Pod        Backend Pod
                       |
                       v
                  MongoDB Atlas
````

---

# 1. Prerequisites

Required tools:

* AWS CLI
* Docker
* kubectl
* eksctl
* Helm

Check installed versions:

```bash
aws --version
docker --version
kubectl version --client
eksctl version
helm version
```

---

# 2. Configure AWS CLI

Configure AWS credentials:

```bash
aws configure
```

Verify AWS identity:

```bash
aws sts get-caller-identity
```

Set/check AWS region:

```bash
aws configure get region
```

For this project:

```text
Region: ap-south-1
```

---

# 3. Clone the Application Repository

```bash
git clone https://github.com/LondheShubham153/TWSThreeTierAppChallenge.git
```

Move into the project:

```bash
cd TWSThreeTierAppChallenge
```

Check the project:

```bash
ls
```

---

# 4. Create MongoDB Atlas Database

Create a MongoDB Atlas cluster.

Create a database user.

Configure MongoDB Atlas Network Access.

Obtain the MongoDB connection string.

Do NOT commit the connection string to GitHub.

---

# 5. Build Backend Docker Image

Move to the backend:

```bash
cd Application-Code/backend
```

Build the image:

```bash
docker build -t backend-app:latest .
```

Verify:

```bash
docker images | grep backend-app
```

---

# 6. Build Frontend Docker Image

Move to frontend:

```bash
cd ../frontend
```

Build:

```bash
docker build -t frontend-app:latest .
```

Verify:

```bash
docker images | grep frontend-app
```

---

# 7. Configure Frontend API URL

The frontend should communicate with the backend through the Kubernetes Ingress.

The API URL should be:

```javascript
const apiUrl = "/api/tasks";
```

This allows the browser to use:

```text
http://<ALB-DNS>/api/tasks
```

instead of directly accessing the backend Pod or Service.

After modifying the frontend code, rebuild the frontend image:

```bash
docker build -t frontend-app:latest .
```

---

# 8. Create / Push Images to Public ECR

Login to Public ECR:

```bash
aws ecr-public get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin public.ecr.aws
```

Tag backend image:

```bash
docker tag backend-app:latest \
public.ecr.aws/<ECR_ALIAS>/backend-app:latest
```

Tag frontend image:

```bash
docker tag frontend-app:latest \
public.ecr.aws/<ECR_ALIAS>/frontend-app:latest
```

Push backend:

```bash
docker push public.ecr.aws/<ECR_ALIAS>/backend-app:latest
```

Push frontend:

```bash
docker push public.ecr.aws/<ECR_ALIAS>/frontend-app:latest
```

Verify local images:

```bash
docker images | grep -E "backend-app|frontend-app"
```

---

# 9. Create EKS Cluster

Create the EKS cluster using `eksctl`:

```bash
eksctl create cluster \
  --name tws-three-tier \
  --region ap-south-1 \
  --nodegroup-name tws-nodes \
  --node-type t3.small \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 1
```

Verify the cluster:

```bash
kubectl get nodes
```

Expected:

```text
STATUS
Ready
```

---

# 10. Create Kubernetes Directory

From the project root:

```bash
cd ~/TWSThreeTierAppChallenge
```

Create Kubernetes directory:

```bash
mkdir k8s
```

Move into it:

```bash
cd k8s
```

---

# 11. Create MongoDB Kubernetes Secret

Create the Kubernetes Secret using the MongoDB Atlas connection string:

```bash
kubectl create secret generic mongodb-secret \
  --from-literal=MONGO_CONN_STR='<YOUR_MONGODB_CONNECTION_STRING>'
```

Verify:

```bash
kubectl get secrets
```

Expected:

```text
mongodb-secret
```

---

# 12. Create Backend Deployment

Create:

```bash
nano backend-deployment.yaml
```

Use:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: backend

spec:
  replicas: 1

  selector:
    matchLabels:
      app: backend

  template:
    metadata:
      labels:
        app: backend

    spec:
      containers:
        - name: backend
          image: public.ecr.aws/<ECR_ALIAS>/backend-app:latest

          ports:
            - containerPort: 3500

          env:
            - name: MONGO_CONN_STR
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: MONGO_CONN_STR
```

Apply:

```bash
kubectl apply -f backend-deployment.yaml
```

Verify:

```bash
kubectl get pods
```

---

# 13. Verify Backend Logs

Get the backend Pod:

```bash
kubectl get pods
```

Check logs:

```bash
kubectl logs <BACKEND_POD_NAME>
```

Expected:

```text
Listening on port 3500...
Connected to database.
```

---

# 14. Create Backend Service

Create:

```bash
nano backend-service.yaml
```

Use:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: backend-service

spec:
  selector:
    app: backend

  ports:
    - protocol: TCP
      port: 3500
      targetPort: 3500

  type: ClusterIP
```

Apply:

```bash
kubectl apply -f backend-service.yaml
```

Verify:

```bash
kubectl get services
```

Expected:

```text
backend-service   ClusterIP   ...   3500/TCP
```

---

# 15. Create Frontend Deployment

Create:

```bash
nano frontend-deployment.yaml
```

Use:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: frontend

spec:
  replicas: 1

  selector:
    matchLabels:
      app: frontend

  template:
    metadata:
      labels:
        app: frontend

    spec:
      containers:
        - name: frontend
          image: public.ecr.aws/<ECR_ALIAS>/frontend-app:latest

          ports:
            - containerPort: 3000
```

Apply:

```bash
kubectl apply -f frontend-deployment.yaml
```

Verify:

```bash
kubectl get pods
```

Expected:

```text
backend-xxxxx    1/1   Running
frontend-xxxxx   1/1   Running
```

---

# 16. Create Frontend Service

Create:

```bash
nano frontend-service.yaml
```

Use:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: frontend-service

spec:
  selector:
    app: frontend

  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000

  type: ClusterIP
```

Apply:

```bash
kubectl apply -f frontend-service.yaml
```

Verify:

```bash
kubectl get services
```

Expected:

```text
backend-service
frontend-service
kubernetes
```

---

# 17. Configure IAM OIDC Provider

Associate an IAM OIDC provider with EKS:

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster tws-three-tier \
  --region ap-south-1 \
  --approve
```

---

# 18. Download AWS Load Balancer Controller IAM Policy

Go to the project root:

```bash
cd ~/TWSThreeTierAppChallenge
```

Download the IAM policy:

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.3/docs/install/iam_policy.json
```

Create the IAM policy:

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

---

# 19. Create IAM Service Account

```bash
eksctl create iamserviceaccount \
  --cluster tws-three-tier \
  --region ap-south-1 \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve
```

Verify:

```bash
kubectl get serviceaccount -n kube-system
```

---

# 20. Install Helm

Check Helm:

```bash
helm version
```

If Helm is not installed:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Verify:

```bash
helm version
```

---

# 21. Add AWS EKS Helm Repository

```bash
helm repo add eks https://aws.github.io/eks-charts
```

Update repositories:

```bash
helm repo update
```

---

# 22. Install AWS Load Balancer Controller

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=tws-three-tier \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=$(aws eks describe-cluster \
    --name tws-three-tier \
    --region ap-south-1 \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)
```

Verify:

```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

Expected:

```text
aws-load-balancer-controller-xxxxx   1/1   Running
aws-load-balancer-controller-xxxxx   1/1   Running
```

---

# 23. Create Ingress

Move to the Kubernetes directory:

```bash
cd ~/TWSThreeTierAppChallenge/k8s
```

Create:

```bash
nano ingress.yaml
```

Use:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: three-tier-ingress

  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip

spec:
  ingressClassName: alb

  rules:
    - http:
        paths:

          - path: /api
            pathType: Prefix

            backend:
              service:
                name: backend-service
                port:
                  number: 3500

          - path: /
            pathType: Prefix

            backend:
              service:
                name: frontend-service
                port:
                  number: 3000
```

Apply:

```bash
kubectl apply -f ingress.yaml
```

---

# 24. Verify Ingress

Check:

```bash
kubectl get ingress
```

Expected:

```text
NAME                 CLASS   HOSTS   ADDRESS
three-tier-ingress   alb     *       <ALB-DNS-NAME>
```

Get detailed information:

```bash
kubectl describe ingress three-tier-ingress
```

Look for:

```text
SuccessfullyReconciled
```

---

# 25. Test Frontend

Get ALB DNS:

```bash
kubectl get ingress
```

Test:

```bash
curl -I http://<ALB-DNS-NAME>
```

Expected:

```text
HTTP/1.1 200 OK
```

Open in browser:

```text
http://<ALB-DNS-NAME>
```

---

# 26. Test Backend API

```bash
curl -i http://<ALB-DNS-NAME>/api/tasks
```

Expected initially:

```json
[]
```

After adding tasks:

```json
[
  {
    "_id": "...",
    "completed": false,
    "task": "example task",
    "__v": 0
  }
]
```

---

# 27. Test End-to-End

Open:

```text
http://<ALB-DNS-NAME>
```

Perform:

1. Add a task.
2. Verify the task appears.
3. Refresh the page.
4. Verify the task is still present.

This confirms:

```text
Browser
   ↓
AWS ALB
   ↓
Ingress
   ↓
Frontend
   ↓
/api/tasks
   ↓
Backend
   ↓
MongoDB Atlas
```

---

# 28. Verify MongoDB Data

MongoDB Atlas:

```text
Cluster
  ↓
Database
  ↓
Collection
```

For this project:

```text
tws-three-tier-db
        ↓
       test
        ↓
      tasks
```

The backend model:

```javascript
mongoose.model("task", taskSchema)
```

maps to the MongoDB collection:

```text
tasks
```

---

# 29. Final Verification Commands

Check nodes:

```bash
kubectl get nodes
```

Check Pods:

```bash
kubectl get pods
```

Check Services:

```bash
kubectl get services
```

Check Ingress:

```bash
kubectl get ingress
```

Check Load Balancer Controller:

```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

Check backend logs:

```bash
kubectl logs <BACKEND_POD_NAME>
```

Check backend API:

```bash
curl -i http://<ALB-DNS-NAME>/api/tasks
```

Check frontend:

```bash
curl -I http://<ALB-DNS-NAME>
```

---

# Troubleshooting

## 1. EKS Node is not Ready

Check:

```bash
kubectl get nodes
```

Check detailed information:

```bash
kubectl describe node <NODE_NAME>
```

Check cluster:

```bash
eksctl get cluster --region ap-south-1
```

Check nodegroup:

```bash
eksctl get nodegroup \
  --cluster tws-three-tier \
  --region ap-south-1
```

---

## 2. Pod is not Running

Check:

```bash
kubectl get pods
```

Describe the Pod:

```bash
kubectl describe pod <POD_NAME>
```

Check logs:

```bash
kubectl logs <POD_NAME>
```

If the Pod restarted:

```bash
kubectl logs <POD_NAME> --previous
```

---

## 3. Backend Cannot Connect to MongoDB

Check backend logs:

```bash
kubectl logs <BACKEND_POD_NAME>
```

Check Secret exists:

```bash
kubectl get secret mongodb-secret
```

Check backend Deployment:

```bash
kubectl describe deployment backend
```

Check Pod environment configuration:

```bash
kubectl describe pod <BACKEND_POD_NAME>
```

Do NOT print or expose the actual MongoDB password/connection string.

---

## 4. Service Has No Endpoints

Check Services:

```bash
kubectl get services
```

Check endpoints:

```bash
kubectl get endpoints
```

For backend:

```bash
kubectl get endpoints backend-service
```

For frontend:

```bash
kubectl get endpoints frontend-service
```

Check Pod labels:

```bash
kubectl get pods --show-labels
```

The labels must match the Service selectors.

Example:

```text
Deployment label:
app: backend

Service selector:
app: backend
```

---

## 5. Ingress Has No ALB Address

Check:

```bash
kubectl get ingress
```

Describe:

```bash
kubectl describe ingress three-tier-ingress
```

Check controller:

```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

Check controller logs:

```bash
kubectl logs \
  -n kube-system \
  deployment/aws-load-balancer-controller
```

Check IngressClass:

```bash
kubectl get ingressclass
```

Expected:

```text
alb
```

---

## 6. ALB DNS Does Not Resolve

Check DNS:

```bash
nslookup <ALB-DNS-NAME>
```

If `nslookup` is not installed:

```bash
sudo apt update
sudo apt install -y dnsutils
```

Then:

```bash
nslookup <ALB-DNS-NAME>
```

---

## 7. ALB Returns 502 / 503

Check:

```bash
kubectl describe ingress three-tier-ingress
```

Check Services:

```bash
kubectl get services
```

Check endpoints:

```bash
kubectl get endpoints
```

Check Pods:

```bash
kubectl get pods -o wide
```

Check backend logs:

```bash
kubectl logs <BACKEND_POD_NAME>
```

Check frontend logs:

```bash
kubectl logs <FRONTEND_POD_NAME>
```

---

## 8. Frontend Loads but API Doesn't Work

Test backend directly through ALB:

```bash
curl -i http://<ALB-DNS-NAME>/api/tasks
```

Check frontend API configuration:

```text
/api/tasks
```

Check Ingress:

```bash
kubectl describe ingress three-tier-ingress
```

Expected routing:

```text
/api → backend-service:3500
/    → frontend-service:3000
```

---

## 9. AWS Load Balancer Controller Pod is Not Ready

Check:

```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

Describe:

```bash
kubectl describe pod \
  -n kube-system \
  <CONTROLLER_POD_NAME>
```

Check logs:

```bash
kubectl logs \
  -n kube-system \
  <CONTROLLER_POD_NAME>
```

Check ServiceAccount:

```bash
kubectl get serviceaccount \
  aws-load-balancer-controller \
  -n kube-system
```

---

## 10. Helm Installation Problem

Check Helm:

```bash
helm version
```

Check repositories:

```bash
helm repo list
```

Update:

```bash
helm repo update
```

Check installed releases:

```bash
helm list -n kube-system
```

Check Load Balancer Controller:

```bash
helm status aws-load-balancer-controller -n kube-system
```

---

## 11. Docker ImagePullBackOff

Check:

```bash
kubectl get pods
```

Describe:

```bash
kubectl describe pod <POD_NAME>
```

Check the image:

```bash
kubectl get deployment backend -o yaml
```

or:

```bash
kubectl get deployment frontend -o yaml
```

Verify the ECR image exists and that the image name/tag is correct.

For Public ECR, the image should look like:

```text
public.ecr.aws/<ECR_ALIAS>/backend-app:latest
```

or:

```text
public.ecr.aws/<ECR_ALIAS>/frontend-app:latest
```

---

## 12. Frontend Image Changes Are Not Visible

Rebuild:

```bash
docker build -t frontend-app:latest .
```

Retag:

```bash
docker tag frontend-app:latest \
public.ecr.aws/<ECR_ALIAS>/frontend-app:latest
```

Push:

```bash
docker push public.ecr.aws/<ECR_ALIAS>/frontend-app:latest
```

Restart the Deployment:

```bash
kubectl rollout restart deployment frontend
```

Check rollout:

```bash
kubectl rollout status deployment frontend
```

---

# Useful Kubernetes Commands

Get everything:

```bash
kubectl get all
```

Get Pods:

```bash
kubectl get pods
```

Get Pods with node information:

```bash
kubectl get pods -o wide
```

Get Services:

```bash
kubectl get svc
```

Get Deployments:

```bash
kubectl get deployments
```

Get Ingress:

```bash
kubectl get ingress
```

Get Secrets:

```bash
kubectl get secrets
```

Get ConfigMaps:

```bash
kubectl get configmaps
```

Get events:

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

Describe a resource:

```bash
kubectl describe <RESOURCE_TYPE> <RESOURCE_NAME>
```

Delete a Pod:

```bash
kubectl delete pod <POD_NAME>
```

Restart a Deployment:

```bash
kubectl rollout restart deployment <DEPLOYMENT_NAME>
```

Check rollout:

```bash
kubectl rollout status deployment <DEPLOYMENT_NAME>
```

---

# Useful AWS Commands

Check AWS identity:

```bash
aws sts get-caller-identity
```

Check EKS cluster:

```bash
aws eks describe-cluster \
  --name tws-three-tier \
  --region ap-south-1
```

Get EKS VPC ID:

```bash
aws eks describe-cluster \
  --name tws-three-tier \
  --region ap-south-1 \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text
```

List EKS clusters:

```bash
aws eks list-clusters \
  --region ap-south-1
```

Get nodegroups:

```bash
eksctl get nodegroup \
  --cluster tws-three-tier \
  --region ap-south-1
```

---

# Important Security Notes

Never commit the following to GitHub:

```text
MongoDB passwords
MongoDB connection strings
AWS access keys
AWS secret keys
.pem files
SSH private keys
Kubernetes kubeconfig
Kubernetes Secrets containing credentials
.env files containing secrets
```

Add sensitive files to `.gitignore`.

Example:

```gitignore
.env
*.pem
iam_policy.json
kubeconfig
secrets.yaml
```

Use Kubernetes Secrets or AWS Secrets Manager for sensitive application configuration.

---

# Final Deployment Flow

```text
Application Source Code
        |
        v
      Docker
        |
        v
      ECR
        |
        v
      EKS
        |
        v
 Kubernetes Deployments
        |
        v
 Kubernetes Services
        |
        v
 Kubernetes Ingress
        |
        v
 AWS Load Balancer Controller
        |
        v
 AWS Application Load Balancer
        |
        v
      Internet
```

Database flow:

```text
Backend Pod
     |
     v
Kubernetes Secret
     |
     v
MongoDB Connection String
     |
     v
MongoDB Atlas
     |
     v
test.tasks
```

---

# End-to-End Validation

The deployment is considered successful when all of the following work:

```text
✓ EKS node is Ready
✓ Backend Pod is Running
✓ Frontend Pod is Running
✓ Backend Service exists
✓ Frontend Service exists
✓ MongoDB connection succeeds
✓ AWS Load Balancer Controller is Ready
✓ Ingress has an ALB DNS address
✓ Frontend returns HTTP 200
✓ /api/tasks returns HTTP 200
✓ UI can create a task
✓ Task remains after browser refresh
✓ Task is persisted in MongoDB Atlas
```

## Final Result

The application is successfully deployed on Amazon EKS with:

* Dockerized frontend and backend
* Public ECR container images
* Kubernetes Deployments
* Kubernetes ClusterIP Services
* Kubernetes Secret for MongoDB credentials
* MongoDB Atlas
* AWS Load Balancer Controller
* Kubernetes Ingress
* AWS Application Load Balancer
* Path-based routing
* Persistent application data

```

**One important correction for your actual GitHub README:** replace every `<ECR_ALIAS>` with your real Public ECR alias (`v2n1v6c7` in the deployment you just completed), but **do not put the MongoDB connection string or credentials in the README.**
```
