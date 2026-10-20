variable "project_name" {
  description = "Name prefix for AWS resources"
  type        = string
  default     = "mern-assignment"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR"
  type        = string
  default     = "10.20.2.0/24"
}

variable "my_ip" {
  description = "Public IP allowed to SSH into web EC2"
  type        = string
}

variable "public_key_path" {
  description = "Path to existing SSH public key"
  type        = string
  default     = "/home/bkori17/.ssh/mern-assignment.pub"
}

variable "web_instance_type" {
  type    = string
  default = "t3.small"
}

variable "db_instance_type" {
  type    = string
  default = "t3.small"
}
