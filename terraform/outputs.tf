output "vpc_id" {
  description = "MERN VPC identifier"
  value       = aws_vpc.mern.id
}

output "web_public_ip" {
  description = "Public IP address of the MERN web server"
  value       = aws_instance.web.public_ip
}

output "web_private_ip" {
  description = "Private IP address of the web EC2"
  value       = aws_instance.web.private_ip
}

output "db_private_ip" {
  description = "Private IP address of the MongoDB EC2"
  value       = aws_instance.db.private_ip
}

output "application_url" {
  description = "TravelMemory application address"
  value       = "http://${aws_instance.web.public_ip}"
}

output "web_security_group_id" {
  value = aws_security_group.web.id
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}
