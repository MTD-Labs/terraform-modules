This preset category is intended to roll out a large infrastructure solution that includes:

* EKS cluster with Karpenter autoscaler for dynamic load distribution across nodes
* ArgoCD GitOps agent installed into cluster to manage applications delivery (basic and progressive)
* Application Load Balancer with target groups that point to NGINX ingress controller inside EKS cluster and EIP assigned to it with provisioned certificate from ACM
* RDS database instance for Postgres
* Elasticache cluster instance for Redis
* S3 bucket for static files storage

Requirements before the deployment:

1. SSH authorized keys file content should be put into a Parameter Store secure string and the key name should be passed as "bastion_ssh_authorized_keys_secret" variable.