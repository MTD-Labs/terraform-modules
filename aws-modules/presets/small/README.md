# Minimal Infrastructure Preset

This Terraform configuration provides a minimal infrastructure solution suitable for small environments, particularly for development and testing. It includes foundational AWS resources to support lightweight application deployments using **Docker Compose** and **Nginx**.

---

## Features

### Core Components
- **EC2 Instance**: A compute instance to host applications.
- **Elastic IP (EIP)**: Static IP for direct access to the instance.
- **Security Groups**: Basic inbound and outbound rules for controlled access.
- **S3 Buckets**: Storage for static files or media.
- **Docker Compose**: Simplified application orchestration.
- **Nginx**: Reverse proxy and static file serving.

### Optional Features
- **Lambda Function**: Serverless image processing (enabled for CDN use cases).
- **CloudFront CDN**: Distribution of static content with optimized caching.

---

## Intended Use
This preset is designed for **development environments** and provides a lightweight, scalable setup to support small projects or isolated environments.

---

## Requirements Before Deployment

1. **SSH Authorized Keys**:
   - The SSH public keys for accessing the EC2 instance must be stored in AWS Systems Manager Parameter Store as a secure string.
   - Pass the Parameter Store key name as the `bastion_ssh_authorized_keys_secret` variable during deployment.

2. **DNS Challenge Token for Certbot**:
   - Generate and store a token for the DNS provider to be used with Certbot for automated DNS challenges during SSL certificate creation.
   - Provide the token securely in AWS Secrets Manager or another secure location.

3. **Key Pair**:
   - Create an SSH key pair with the name of the project (e.g., `<project_name>`).
   - Store the private key securely in your version control system (e.g., Bitbucket, GitHub) or another secure location.

4. **Templates Directory**:
   - Create an `inputs/templates` folder in your project directory.
   - Place the following files in this folder:
     - `docker-compose.yml`: Define the Docker Compose configuration for your application.
     - `nginx.conf`: Define the Nginx configuration for reverse proxy and static file serving.

5. **AWS Credentials**:
   - Ensure the AWS CLI is configured with credentials that have the necessary permissions to create the listed resources.

---

## Inputs
The setup allows customization through the following key variables:

| Variable Name                     | Description                                      |
|-----------------------------------|--------------------------------------------------|
| `env`                             | Deployment environment name (e.g., `dev`, `prod`). |
| `project_name`                    | Name of the project to be used for resource naming. |
| `region`                          | AWS region for resource deployment.             |
| `bastion_ssh_authorized_keys_secret` | Parameter Store key for SSH authorized keys.      |

---

## Resources Created
The configuration will provision the following resources:

1. **EC2 Instance**:
   - Runs the applications using Docker Compose.
   - Serves content and handles proxying with Nginx.
   - Configured with an Elastic IP and basic security group rules.
2. **S3 Bucket**:
   - Public or private bucket for static file storage.
3. **CloudFront CDN** (Optional):
   - For static content distribution and optimization.

---

## Deployment Steps

1. Prepare the templates:
   - Create an `inputs/templates` directory.
   - Add your `docker-compose.yml` and `nginx.conf` files to this folder.

2. Generate and configure:
   - Generate a Certbot DNS challenge token and store it securely.
   - Create an SSH key pair for the project and store it securely in your version control system or another secure location.

3. Initialize Terraform:
   ```bash
   terraform init

3. Validate the configuration:
   ```bash
   terraform validate

4. Plan the deployment:
   ```bash
   terraform plan

5. Apply the changes:
   ```bash
   terraform apply
