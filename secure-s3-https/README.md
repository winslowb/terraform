🔐 Deploy a Secure Static Website to AWS using Terraform
This module-based Terraform project deploys a secure, HTTPS-enabled static website using:

- S3 for file hosting
- CloudFront for HTTPS + CDN delivery
- Route 53 for DNS
- ACM for TLS certificates (auto-validated via DNS)

🗂️ Project Structure
secure-s3-https/
    main.tf              # Root config - wires modules together
    variables.tf         # Shared input variables
    terraform.tfvars     # User-specific config (domain, bucket, etc.)
    modules/
        s3_static_site/       # S3 bucket + website config + default index.html #
        cloudfront_cdn/       # CloudFront + origin access control #
        cert_dns/             # ACM cert + DNS validation in Route 53 #
        route53_record/       # A-record alias to CloudFront #

🚀 How to Deploy
- git clone https://github.com/your-username/terraform.git
- cd terraform/secure-s3-https
- Set up your values in terraform.tfvars:
    - bucket_name  = "your-unique-bucket-name"
    - domain_name  = "your-unique domain ie. site.doit.com.com"
    - zone_name    = "your-unique zone name ie. doit.com."
- Initialize Terraform and deploy:
    - terraform init
    - terraform plan
    - terraform apply
    - Visit your site at: https://site.doit.com

🧼 Teardown
To clean everything up:
- aws s3 rm s3://your-unique-bucket-name --recursive
- terraform destroy

🧱 Modules in This Project
- Module	Responsibility
- s3_static_site	Creates S3 bucket and uploads index.html
- cloudfront_cdn	CloudFront CDN + OAC setup
- cert_dns	ACM TLS cert with DNS validation
- route53_record	A-record for CloudFront in Route 53
