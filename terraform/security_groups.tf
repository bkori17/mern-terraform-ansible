resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-web-"
  description = "Security group for MERN web server"
  vpc_id      = aws_vpc.mern.id

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

resource "aws_security_group" "db" {
  name_prefix = "${var.project_name}-db-"
  description = "Security group for MongoDB server"
  vpc_id      = aws_vpc.mern.id

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

# SSH to web server only from our public IP
resource "aws_vpc_security_group_ingress_rule" "web_ssh" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from developer IP"
}

# HTTP for frontend and reverse-proxied API
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Public HTTP access"
}

# Database SSH only from web server
resource "aws_vpc_security_group_ingress_rule" "db_ssh" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "SSH via web instance"
}

# MongoDB available only to the web server
resource "aws_vpc_security_group_ingress_rule" "db_mongodb" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
  description                  = "MongoDB from web instance"
}

resource "aws_vpc_security_group_egress_rule" "web_outbound" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Web outbound access"
}

resource "aws_vpc_security_group_egress_rule" "db_outbound" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Database outbound via NAT"
}
