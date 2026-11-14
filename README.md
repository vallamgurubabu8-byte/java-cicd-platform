# Generic Java CI/CD Platform

A reusable CI/CD platform designed to build, test, containerize, and deploy multiple Java Spring Boot applications using Jenkins, Docker, Kubernetes, and Helm.

## Objectives

- Support multiple Java projects through YAML configuration.
- Support Maven and Gradle builds.
- Validate project configurations using JSON Schema.
- Build and test applications independently from deployment.
- Build and push Docker images to a container registry.
- Deploy applications to Kubernetes using reusable templates.
- Support SQL databases such as MySQL and PostgreSQL.
- Separate CI and CD pipelines.

## Technology Stack

- Java 17 / 21 / 25
- Maven / Gradle
- Python and PyYAML
- Jenkins
- Docker
- Docker Registry
- Kubernetes
- Helm
- MySQL / PostgreSQL

## Project Structure

```text
java-cicd-platform/
├── Jenkinsfiles/
├── docs/
├── project-configs/
├── schemas/
├── scripts/
├── shared-library/
│   └── vars/
├── templates/
│   ├── helm/
│   │   └── java-sql-app/
│   └── kubernetes/
├── requirements.txt
└── README.md
