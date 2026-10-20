data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${var.project_name}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = {
    Name = "${var.project_name}-web-role"
  }
}

resource "aws_iam_role" "db" {
  name               = "${var.project_name}-db-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = {
    Name = "${var.project_name}-db-role"
  }
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "db_ssm" {
  role       = aws_iam_role.db.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project_name}-web-profile"
  role = aws_iam_role.web.name
}

resource "aws_iam_instance_profile" "db" {
  name = "${var.project_name}-db-profile"
  role = aws_iam_role.db.name
}
