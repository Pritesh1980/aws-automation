provider "aws" {
  profile = "work-user"
  region  = var.region
}


resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"

  ingress {
    description = "HTTP from all"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
  }
}



# IAM role for SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name               = "ssm-role"
  assume_role_policy = "${file("assumerolepolicy.json")}"
}

resource "aws_iam_policy" "ssm_policy" {
  name = "ssm_policy"
  #role = aws_iam_role.ec2_ssm_role.id

  policy = "${file("ssm_policy.json")}"
}

resource "aws_iam_role_policy_attachment" "ssm-attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm_profile"
  role = "${aws_iam_role.ec2_ssm_role.name}"
}

resource "aws_instance" "node" {
  ami                  = var.amis[var.region]
  instance_type        = var.inst-type 
  security_groups      = ["allow_http"]
  iam_instance_profile = "${aws_iam_instance_profile.ssm_profile.name}"

  user_data = "${file("../user_data/install_db_and_web.sh")}"
  tags = {
    Name = "Wordpress - DB + Apache"
  }
}

resource "aws_eip" "ip" {
  vpc      = true
  instance = aws_instance.node.id
}

