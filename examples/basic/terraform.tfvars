# Example terraform.tfvars for terraform-aws-pablosspot-ecs/examples/basic
# Replace the placeholder values with values from your environment.

# VPC where target group and ECS service will be created
vpc_id = "vpc-0123456789abcdef0"

# ALB listener ARN (an existing listener). Module will create listener rules on this listener.
lb_listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/50dc6c495c0c9188/6f0f8e1a2b3c4d5e"

# Host header used by the listener rule to match incoming requests
domain_url = "example.com"

# Whether to enable ALB authenticate-oidc action on the listener rule
authenticate_oidc = false

# If you set authenticate_oidc = true, provide the following object.
# Uncomment and fill with real values when enabling OIDC auth.
# authenticate_oidc_details = {
#   client_id     = "your-oidc-client-id"
#   client_secret = "your-oidc-client-secret"
#   oidc_endpoint = "https://your-oidc-issuer.example.com"
# }

# Optional: override region if you want to run the example in a different AWS region
# aws_region = "ap-southeast-2"
