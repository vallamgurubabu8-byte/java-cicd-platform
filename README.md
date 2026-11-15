# 🚀 Generic Java CI/CD Platform

A reusable, configuration-driven CI/CD platform designed to automate the build, test, containerization, and deployment of multiple Java Spring Boot applications using **Jenkins, Maven, Gradle, Docker, Kubernetes, and Helm**.

The goal of this project is to simplify application delivery by creating reusable CI/CD workflows that can support multiple Java applications with minimal project-specific changes.

Instead of creating separate Jenkins pipelines for every application, this platform uses YAML-based configuration to manage application-specific build and deployment settings.

---

## 🎯 Project Objectives

- Support multiple Java Spring Boot applications through YAML configuration.
- Support Maven and Gradle build tools.
- Support Java 17, 21, and 25 applications.
- Validate project configurations using JSON Schema.
- Automate application compilation, testing, and packaging.
- Build Docker images and push them to a container registry.
- Deploy applications to Kubernetes using reusable deployment templates.
- Support SQL databases such as MySQL and PostgreSQL.
- Separate Continuous Integration (CI) and Continuous Deployment (CD).
- Automate deployment verification and application health checks.
- Generate deployment health reports and email notifications.

---

## 🛠️ Technology Stack

| Category | Technologies |
|---|---|
| Programming Language | Java 17 / 21 / 25 |
| Framework | Spring Boot |
| Build Tools | Maven, Gradle |
| Configuration | YAML, JSON Schema |
| Scripting | Bash, Python |
| CI/CD | Jenkins |
| Containerization | Docker |
| Container Registry | Docker Registry |
| Orchestration | Kubernetes |
| Deployment Templates | Helm, Kubernetes YAML |
| Databases | MySQL, PostgreSQL |
| Notifications | Gmail SMTP |
| Version Control | Git, GitHub |

---

## 📁 Project Structure

```text
java-cicd-platform/
│
├── Jenkinsfiles/
│   ├── Jenkinsfile-ci
│   └── Jenkinsfile-cd
│
├── docs/
│
├── project-configs/
│   └── medical-appointment.yaml
│
├── schemas/
│
├── scripts/
│   ├── validate-config.sh
│   ├── validate-config.py
│   ├── check-cd-environment.sh
│   ├── health-check.sh
│   └── send-health-report.sh
│
├── shared-library/
│   └── vars/
│
├── templates/
│   ├── helm/
│   │   └── java-sql-app/
│   │
│   └── kubernetes/
│
├── requirements.txt
│
└── README.md
```

*The structure represents the platform's intended reusable components. Individual scripts and templates may vary as development progresses.*

---

## 🏗️ Architecture Overview

The platform separates application build activities from deployment activities.

```text
                  DEVELOPER
                      |
                      v
                 GitHub Repository
                      |
                      v
             Jenkins CI Pipeline
                      |
             Configuration Validation
                      |
                Source Checkout
                      |
                Maven / Gradle
                      |
                Build & Testing
                      |
                 Docker Build
                      |
               Push Docker Image
                      |
                Container Registry
                      |
                      v
             Jenkins CD Pipeline
                      |
             Configuration Validation
                      |
               Environment Check
                      |
             Kubernetes Deployment
                      |
               Rollout Verification
                      |
                Pod Readiness
                      |
               Service Validation
                      |
              Application Health Check
                      |
               Email Notification
```

---

## 🔄 CI Pipeline – Continuous Integration

The CI pipeline is responsible for building and packaging Java applications.

### CI workflow

1. Checkout the CI/CD platform repository.
2. Validate pipeline parameters.
3. Validate the project YAML configuration.
4. Load application-specific build settings.
5. Checkout the configured application repository.
6. Identify the configured build tool.
7. Execute Maven or Gradle build commands.
8. Run application tests.
9. Build the Docker image.
10. Push the Docker image to the configured container registry.

### Example Docker image tags

```text
medical-appointment-api:build-1
medical-appointment-api:build-2
medical-appointment-api:build-3
```

Each build can have a unique image tag, making it easier to identify and deploy specific application versions.

---

## 🚀 CD Pipeline – Continuous Deployment

The CD pipeline deploys an existing Docker image to Kubernetes.

### CD workflow

1. Checkout the platform repository.
2. Validate deployment parameters.
3. Validate the project configuration.
4. Verify the Kubernetes deployment environment.
5. Load deployment and database configurations.
6. Apply Kubernetes Deployment and Service resources.
7. Configure image pull secrets.
8. Inject database configuration using Kubernetes Secrets.
9. Verify Kubernetes rollout status.
10. Validate pod readiness.
11. Validate Kubernetes Service availability.
12. Perform application HTTP health checks.
13. Generate a health-check report.
14. Send deployment notifications through Gmail SMTP.

CI and CD are maintained as separate pipelines so that building an application and deploying an existing image can be performed independently.

---

## ⚙️ YAML-Based Project Configuration

Each application can have its own YAML configuration file.

Example:

```yaml
project:
  name: medical-appointment-api
  repository: https://github.com/your-username/your-java-project.git
  defaultBranch: main

build:
  tool: maven
  javaVersion: "21"
  artifactPath: target/*.jar
  testCommand: verify

container:
  imageName: medical-appointment-api
  dockerfile: Dockerfile
  port: 8080

database:
  enabled: true
  type: mysql
  version: "8.4"

deployment:
  namespace: medical-appointment
  name: medical-appointment-api
  containerName: medical-appointment-api
  serviceName: medical-appointment-service
  replicas: 1
  serviceType: ClusterIP
  servicePort: 8081
  targetPort: 8080
```

The YAML configuration allows application-specific settings to be managed separately from the reusable Jenkins pipeline logic.

---

## 🔐 Security and Configuration Management

The platform uses Jenkins Credentials and Kubernetes Secrets to avoid hardcoding sensitive values.

Security considerations:

- Store registry credentials in Jenkins Credentials.
- Store SMTP credentials in Jenkins Credentials.
- Use Kubernetes Secrets for database passwords.
- Inject sensitive configuration through environment variables.
- Avoid committing passwords, tokens, and API keys to Git.
- Use appropriate Kubernetes RBAC permissions.
- Restrict access to sensitive Actuator endpoints.
- Avoid exposing database credentials in build logs.

---

## 🩺 Deployment Health Checks

The platform includes automated deployment verification.

The health-check script validates:

- Project configuration.
- Deployment readiness.
- Pod readiness.
- Kubernetes Service availability.
- Deployment rollout status.
- Application HTTP health endpoint.

For Spring Boot applications, the health endpoint can be:

```text
/actuator/health
```

Example successful response:

```json
{
  "status": "UP"
}
```

The health-check script generates a summary indicating successful and failed checks.

---

## 📧 Email Notifications

The platform integrates Gmail SMTP for deployment health reports.

The notification includes:

- Project name.
- Jenkins job name.
- Build number.
- Deployment status.
- Kubernetes namespace.
- Deployment name.
- Jenkins build URL.
- Health-check execution results.

SMTP credentials are provided through Jenkins Credentials.

---

## 🧰 Prerequisites

Install and configure the following tools before running the pipelines:

- Java JDK 17, 21, or 25, according to the application.
- Maven or Gradle.
- Python 3.
- PyYAML and other required Python dependencies.
- Jenkins.
- Docker.
- Kubernetes cluster.
- kubectl.
- Helm, where Helm deployment is used.
- Git and GitHub access.

---

## 🚀 Getting Started

### Step 1: Clone the platform repository

```bash
git clone https://github.com/your-username/java-cicd-platform.git

cd java-cicd-platform
```

### Step 2: Install Python dependencies

```bash
pip install -r requirements.txt
```

### Step 3: Configure your application

Create a YAML configuration under:

```text
project-configs/
```

Update the application repository, build tool, Java version, Docker image name, and deployment settings.

### Step 4: Configure Jenkins Credentials

Configure the required credentials in Jenkins:

- Docker registry credentials.
- Gmail SMTP credentials.
- Kubernetes access, if required by your Jenkins environment.

Use the credential IDs configured in your Jenkinsfiles.

### Step 5: Configure Jenkins CI Pipeline

Create a Jenkins Pipeline job pointing to:

```text
Jenkinsfiles/Jenkinsfile-ci
```

Configure the required pipeline parameters and run the CI pipeline.

### Step 6: Configure Jenkins CD Pipeline

Create a separate Jenkins Pipeline job pointing to:

```text
Jenkinsfiles/Jenkinsfile-cd
```

Provide:

- CONFIG_FILE
- REGISTRY
- IMAGE_TAG

Run the CD pipeline to deploy the selected image.

---

## 🧪 Example Project

The platform is being developed and tested using a Spring Boot Medical Appointment System API.

Example application configuration:

| Property | Value |
|---|---|
| Application | Medical Appointment API |
| Framework | Spring Boot 3 |
| Java | 21 |
| Build Tool | Maven |
| Database | MySQL 8 |
| Containerization | Docker |
| Orchestration | Kubernetes |
| CI/CD | Jenkins |

This application serves as an example for validating the reusable CI/CD workflow.

---

## 📈 Future Enhancements

- Fully configuration-driven Helm deployments.
- Support for additional databases.
- Reusable Jenkins Shared Library functions.
- Support for multiple Kubernetes environments.
- Automated rollback on deployment failure.
- Integration with SonarQube for code quality analysis.
- Integration with security and container image scanning tools.
- Support for additional container registries.
- Prometheus and Grafana monitoring.
- More comprehensive automated integration testing.

---

## 🎓 Learning Outcomes

Through this project, I am gaining practical experience with:

- Designing reusable Jenkins pipelines.
- Automating Maven and Gradle builds.
- Docker image creation and registry management.
- Kubernetes deployments and services.
- YAML-based configuration management.
- Jenkins credentials and Kubernetes Secrets.
- Bash and Python automation.
- Application health monitoring.
- CI/CD troubleshooting and deployment verification.

---

## 👨‍💻 Author

**Vallam Guru Babu**

Java Backend Developer | Spring Boot | Microservices | Jenkins | Docker | Kubernetes

I believe in continuous learning, practical implementation, and building solutions that solve real engineering problems.

---

⭐ If you find this project useful, feel free to explore the repository, share feedback, and connect with me.

**Building. Learning. Improving. Contributing.**
