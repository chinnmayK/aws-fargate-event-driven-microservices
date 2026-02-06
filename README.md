# NodeJS Microservice Architecture on AWS (ECS & Fargate)

This project demonstrates a production-grade transition from a monolithic architecture to an event-driven Microservices architecture. It focuses on modern DevOps practices, Infrastructure as Code (IaC), and solving the real-world complexities of distributed systems.

## 🏗 System Architecture

The system is composed of three core services deployed in a secure, high-availability environment on AWS:

* **Customer Service:** Manages user profiles, authentication, and order history.
* **Products Service:** Manages the product catalog and inventory.
* **Shopping Service:** Handles the cart logic and order processing.

### Tech Stack

* **Backend:** NodeJS, Express
* **Database:** Amazon DocumentDB (MongoDB compatible)
* **Message Broker:** Amazon MQ (RabbitMQ)
* **Infrastructure:** Terraform
* **Containerization:** Docker, Amazon ECR
* **Orchestration:** Amazon ECS (Fargate)
* **Networking:** Application Load Balancer (ALB), VPC, Private Subnets

---

## 🚀 Concepts Implemented

### 1. Infrastructure as Code (IaC)

The entire AWS environment was automated using Terraform. This includes the creation of a custom VPC, security groups with strict ingress/egress rules, and the automated provisioning of managed services like DocumentDB and RabbitMQ.

### 2. Path-Based Routing & Prefix Stripping

To expose multiple services via a single Application Load Balancer (ALB), path-based routing was used (e.g., `/customer/*` routes to the Customer Service).

* **The Challenge:** Services internally expect routes like `/signup`, but the ALB sends `/customer/signup`.
* **The Solution:** Implemented a custom "Middleware Stripper" in Express to dynamically remove the URL prefix before passing the request to the internal router.

### 3. Event-Driven Communication

Implemented a Publisher/Subscriber pattern using RabbitMQ.

* When an order is placed in the **Shopping Service**, it publishes a `CREATE_ORDER` event.
* The **Customer Service** subscribes to this event and updates the user’s order history asynchronously.

### 4. Container Orchestration with Fargate

Services are deployed as serverless containers using ECS Fargate. This eliminates the need to manage EC2 instances while providing seamless scaling and high availability.

### 5. Centralized Secret Management

Sensitive data, including database URIs and JWT secrets, are stored in **AWS Secrets Manager** and injected into the containers at runtime, ensuring no credentials are hardcoded in the repository.

---

## 🛠 Troubleshooting & Resolved Issues

During the development and deployment phase, several critical microservice challenges were identified and resolved:

### 1. 503 Service Temporarily Unavailable

* **Cause:** Services were failing ALB health checks due to the path-prefix mismatch.
* **Resolution:** Implemented the prefix-stripping middleware and configured the ALB health check to hit a dedicated `/health` endpoint that returns a `200 OK`.

### 2. 502 Bad Gateway (Process Crashing)

* **Cause:** A `TypeError` was encountered in the Shopping Service where the code attempted to call a non-existent repository method (`EmptyCart`).
* **Resolution:** Synchronized the Service and Repository layers by implementing a robust `DeleteCart` method in the repository.

### 3. DocumentDB Connectivity (Retryable Writes)

* **Cause:** The default MongoDB driver attempts "Retryable Writes," which are not supported by Amazon DocumentDB, causing write operations to fail.
* **Resolution:** Appended `&retryWrites=false` to the MONGODB_URI strings in the Secrets Manager configuration.

### 4. JWT Malformation

* **Cause:** Middleware was failing to parse tokens due to improper header handling during cross-service testing.
* **Resolution:** Standardized the `Authorization: Bearer <token>` flow and validated token signatures against a consistent `APP_SECRET` shared across services.

---

## 🏁 Workflow for Testing

To verify the full event-driven flow:

1. **Signup:** Create a user via the Customer Service to receive a JWT.
2. **Product Creation:** Add items to the catalog via the Products Service.
3. **Cart Management:** Add products to the cart via the Shopping Service.
4. **Order Placement:** Place an order in the Shopping Service.
5. **Verification:** Check the Customer Profile to confirm that RabbitMQ successfully synced the order data across service boundaries.

---

## 🧹 Infrastructure Cleanup

To maintain cost efficiency, the infrastructure is designed to be fully ephemeral.

* The main application stack is destroyed via `terraform destroy`.
* The backend state management (S3/DynamoDB) is removed via the bootstrap cleanup.