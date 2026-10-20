provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project   = "MERN-Terraform-Ansible"
      ManagedBy = "Terraform"
      Purpose   = "HeroVired-Assignment"
    }
  }
}
