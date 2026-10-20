data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "mern" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.public_key_path))

  tags = {
    Name = "${var.project_name}-key"
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.web_instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.mern.key_name
  iam_instance_profile        = aws_iam_instance_profile.web.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-web"
  }
}

resource "aws_instance" "db" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.db_instance_type
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = aws_key_pair.mern.key_name
  iam_instance_profile        = aws_iam_instance_profile.db.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-mongodb"
  }
}
