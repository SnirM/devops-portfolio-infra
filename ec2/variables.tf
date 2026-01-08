variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID for the region"
  type        = string
}

variable "ecr_repo" {
  description = "Full ECR repository URI INCLUDING repo name (no tag). Example: 8076....amazonaws.com/devops-portfolio-app"
  type        = string
}

variable "ecr_registry" {
  description = "ECR registry hostname only. Example: 8076....dkr.ecr.ap-south-1.amazonaws.com"
  type        = string
  default     = "807650718119.dkr.ecr.ap-south-1.amazonaws.com"
}

variable "key_name" {
  description = "Optional EC2 Key Pair name (leave empty if you will use SSM instead of SSH)"
  type        = string
  default     = ""
}
