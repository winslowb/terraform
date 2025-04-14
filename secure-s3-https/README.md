🔐 Deploy a Secure Static Website to AWS using Terraform
This module-based Terraform project deploys a secure, HTTPS-enabled static website using:

Modules in This Project
 - s3_static_site	# Creates S3 bucket and uploads index.html
 - cloudfront_cdn	# CloudFront CDN + OAC setup
 - cert_dns	        # ACM TLS cert with DNS validation
 - route53_record	# A-record for CloudFront in Route 53


🚀 How to Deploy
Ensure you have terraform installed, and that your AWS creds are exported, then;
- git clone https://github.com/your-username/terraform.git
- cd terraform/secure-s3-https
- Set up your values in terraform.tfvars:
    - bucket_name  = "your-unique-bucket-name"
    - domain_name  = "your-unique domain ie. site.doit.com.com"
    - zone_name    = "your-unique zone name ie. doit.com."
- Initialize Terraform and deploy:
    - terraform init (if necessary)
    - terraform plan
    - terraform apply

Visit your site at: https://$domain_name/$zone_name

This does not automatically provide WAF protection. You can enable this within your cdn distrobution by 'Enabling' *Security - Web Application Firewall(WAF)*.

🧼 Teardown
To clean everything up:
- aws s3 rm s3://$bucket_name --recursive (or delete index.html from the console)
- terraform destroy

