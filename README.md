# AWS Fargate Event-Driven Microservices Architecture

A **production-ready Node.js microservices architecture** deployed on **AWS ECS Fargate**, demonstrating a real-world transition from a monolithic system to an **event-driven, cloud-native architecture**.

This project focuses on **Infrastructure as Code (Terraform)**, **secure networking**, **service isolation**, **asynchronous communication**, and **modern DevOps best practices** used in real enterprise systems.

---

## 🏗️ High-Level Architecture

The system consists of **three independent microservices**, deployed as serverless containers behind a single **Application Load Balancer (ALB)**.

### Core Services

| Service              | Responsibility                               |
| -------------------- | -------------------------------------------- |
| **Customer Service** | User profiles, authentication, order history |
| **Products Service** | Product catalog and inventory                |
| **Shopping Service** | Cart management and order processing         |

### Supporting Infrastructure

* **Amazon ECS (Fargate)** – Serverless container orchestration
* **Application Load Balancer (ALB)** – Path-based routing
* **Amazon DocumentDB** – MongoDB-compatible database
* **Amazon MQ (RabbitMQ)** – Event-driven messaging
* **Amazon ECR** – Container image registry
* **AWS Secrets Manager** – Centralized secrets management
* **Terraform** – End-to-end Infrastructure as Code

---

## 🧱 Architecture Diagram (Conceptual)

```
Internet
   |
[ Application Load Balancer ]
   |
   |-- /customer  --> Customer Service (ECS)
   |-- /products  --> Products Service (ECS)
   |-- /shopping  --> Shopping Service (ECS)
                       |
                       |-- Publishes events
                       v
                 RabbitMQ (Amazon MQ)
                       |
                       v
                 Customer Service (Subscriber)

All services:
- Run in private subnets
- Pull images from ECR
- Store data in DocumentDB
- Load secrets from Secrets Manager
```

---

## 🧑‍💻 Tech Stack

### Application

* **Node.js**, **Express**
* REST APIs + Event-Driven Messaging
* JWT Authentication

### Infrastructure

* **Terraform** (VPC, ECS, ALB, ECR, DocumentDB, Amazon MQ)
* **Docker**
* **AWS ECS Fargate**
* **Amazon VPC (Private Subnets + VPC Endpoints)**

---

## 🚀 Key Concepts Implemented

### 1️⃣ Infrastructure as Code (Terraform)

* Entire AWS environment is version-controlled
* Modular Terraform design:

  * `vpc`
  * `alb`
  * `ecs`
  * `ecr`
  * `database`
  * `messaging`
* Remote Terraform state stored in **S3 with DynamoDB locking**

---

### 2️⃣ Secure Networking (No NAT Gateway)

* All workloads run in **private subnets**
* **VPC Endpoints** provide private access to:

  * ECR (image pulls)
  * Secrets Manager
  * CloudWatch Logs
  * S3
* Only the ALB is internet-facing

---

### 3️⃣ Path-Based Routing with ALB

A single ALB exposes multiple services:

```
/customer/*  -> Customer Service
/products/*  -> Products Service
/shopping/*  -> Shopping Service
```

#### ❗ The Challenge

Services internally expect:

```
POST /signup
```

But ALB forwards:

```
POST /customer/signup
```

#### ✅ The Solution

A **custom Express middleware** strips the service prefix dynamically before routing requests internally.

---

### 4️⃣ Event-Driven Communication (RabbitMQ)

This architecture avoids tight coupling between services.

**Flow Example:**

1. Shopping Service publishes `CREATE_ORDER`
2. Customer Service subscribes asynchronously
3. Order history is updated without blocking the request

**Result:**

* Loose coupling
* Fault tolerance
* Improved scalability

---

### 5️⃣ Serverless Containers with ECS Fargate

* No EC2 instance management
* Each service has:

  * Independent task definition
  * Dedicated ALB target group
  * Independent scaling
* Immutable, repeatable deployments

---

### 6️⃣ Centralized Secret Management

All sensitive data is stored in **AWS Secrets Manager**:

* Database connection strings
* RabbitMQ credentials
* JWT secrets

Secrets are injected at runtime:

* No `.env` files in production
* No credentials committed to GitHub

---

## 🧠 Troubleshooting & Real-World Issues Solved

### 🔴 503 – Service Temporarily Unavailable

**Cause:** ALB health checks failed due to path mismatch
**Fix:**

* Added `/health` endpoint
* Corrected ALB health check paths
* Implemented prefix-stripping middleware

---

### 🔴 502 – Bad Gateway (Container Crash)

**Cause:** Missing repository method in Shopping Service
**Fix:** Implemented `DeleteCart` and aligned service & repository layers

---

### 🔴 DocumentDB Write Failures

**Cause:** MongoDB retryable writes not supported by DocumentDB
**Fix:**

```text
retryWrites=false
```

---

### 🔴 JWT Authentication Errors

**Cause:** Inconsistent token formatting
**Fix:** Standardized `Authorization: Bearer <token>` across services

---

## ▶️ How to Run This Project

This project supports **two execution modes**:

1. **Local Development (Docker Compose)**
2. **Production Deployment on AWS (Terraform + ECS Fargate)**

---

## 🖥️ Option 1: Run Locally (Docker Compose)

### Prerequisites

* Docker & Docker Compose
* Git
* Node.js (optional)

### Steps

#### 1️⃣ Clone the Repository

```bash
git clone https://github.com/chinnmayK/aws-fargate-event-driven-microservices.git
cd aws-fargate-event-driven-microservices
```

#### 2️⃣ Start Services

```bash
docker-compose up --build
```

This starts:

* Customer, Products, Shopping services
* RabbitMQ
* MongoDB (local replacement for DocumentDB)
* Nginx reverse proxy

#### 3️⃣ Access Services

| Service  | URL                                                    |
| -------- | ------------------------------------------------------ |
| Customer | [http://localhost/customer](http://localhost/customer) |
| Products | [http://localhost/products](http://localhost/products) |
| Shopping | [http://localhost/shopping](http://localhost/shopping) |

Health check:

```bash
curl http://localhost/customer/health
```

---

## ☁️ Option 2: Deploy to AWS (Terraform + ECS Fargate)

### Prerequisites

* AWS Account
* AWS CLI
* Terraform ≥ 1.5
* Docker

---

### 🔐 Step 1: Configure AWS Credentials

```bash
aws configure --profile terraform-worker
```

---

### 🏗️ Step 2: Bootstrap Terraform Backend (One-Time)

```bash
cd terraform-ecs-project/bootstrap
terraform init
terraform apply
```

Creates:

* S3 bucket (Terraform state)
* DynamoDB table (state locking)
* IAM user for Terraform

---

### 🧱 Step 3: Provision Infrastructure

```bash
cd ../
terraform init
terraform apply
```

---

### 🐳 Step 4: Build & Push Docker Images

```bash
aws ecr get-login-password \
  --region ap-south-1 \
  --profile terraform-worker \
| docker login \
  --username AWS \
  --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com
```

Repeat for each service (`customer`, `products`, `shopping`).

---

### 🔁 Step 5: Redeploy ECS Services

```bash
terraform apply
```

---

### 🌐 Step 6: Access the Application

```bash
terraform output alb_dns_name
```

```
http://<ALB_DNS>/customer
http://<ALB_DNS>/products
http://<ALB_DNS>/shopping
```

---

## 🧪 End-to-End Test Flow (AWS)

1. Signup → Customer Service
2. Create products → Products Service
3. Add to cart → Shopping Service
4. Place order → Shopping Service
5. Verify order history → Customer Service (via RabbitMQ)

---

## 🧹 Infrastructure Cleanup

### Destroy Application Stack

```bash
cd terraform-ecs-project
terraform destroy
```

### Destroy Backend (Optional)

```bash
cd bootstrap
terraform destroy
```

⚠️ **This deletes all AWS resources created by the project.**

---

## 📂 Repository Structure

```text
customer/           # Customer microservice
products/           # Products microservice
shopping/           # Shopping microservice
proxy/              # Nginx reverse proxy (local dev)
terraform-ecs-project/
  ├── modules/
  │   ├── vpc
  │   ├── alb
  │   ├── ecs
  │   ├── ecr
  │   ├── database
  │   └── messaging
docker-compose.yml  # Local development
```

---

## 🎯 Why This Project Matters

This repository demonstrates:

* Real-world AWS architecture patterns
* Production-grade Terraform
* Secure microservice communication
* Event-driven design at scale
* Practical debugging of distributed systems

This is **not a toy project** — it mirrors challenges faced in real production systems.

---

## 📌 Future Improvements

* HTTPS (ACM + ALB)
* Autoscaling (CPU / request-based)
* CI/CD with GitHub Actions
* Canary deployments
* Observability (OpenTelemetry / X-Ray)

---

## 🏁 Final Notes

This project is intentionally **opinionated**, **secure**, and **realistic**, designed to show not just *what works*, but *why it works* in production cloud environments.