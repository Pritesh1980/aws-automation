provider "aws" {
  profile = var.aws_profile 
  region  = var.region
}


module "deploy_vpc" {
  source = "../../../VPC/public_with_igw"

  region = var.region
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = module.deploy_vpc.vpc_id

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

resource "aws_security_group" "allow_mysql" {
  name        = "allow_mysql"
  description = "Allow MySQL inbound traffic from allow_http SG"
  vpc_id      = module.deploy_vpc.vpc_id

  ingress {
    description     = "MySQL from allow_http"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_http.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_mysql"
  }
}

resource "aws_security_group" "ingress-efs-sg" {

   name = "ingress-efs-sg"
   vpc_id = module.deploy_vpc.vpc_id

   ingress {
     security_groups = [aws_security_group.allow_http.id]
     from_port = 2049
     to_port = 2049
     protocol = "tcp"
   }

   egress {
     security_groups = [aws_security_group.allow_http.id]
     from_port = 0
     to_port = 0
     protocol = "-1"
   }
}

# IAM role for SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name               = "ec2-ssm-role"
  assume_role_policy = file("assumerolepolicy.json")
}

resource "aws_iam_policy" "ssm_policy" {
  name   = "ec2-ssm_policy"
  policy = file("ssm_policy.json")
}

resource "aws_iam_role_policy_attachment" "ssm-attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_instance_profile" "ssm_profile" {
  #name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}


resource "aws_efs_file_system" "www" {
  creation_token = "web-server"
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
  encrypted = "true"
  
  tags = {
    Name = "WWW EFS"
  }
}

resource "aws_efs_mount_target" "www-efs-mt" {

   file_system_id = aws_efs_file_system.www.id
   subnet_id = module.deploy_vpc.subnet_a_public_id
   security_groups = [aws_security_group.ingress-efs-sg.id]

}

resource "aws_instance" "web" {
  ami                         = var.amis[var.region]
  instance_type               = var.web-inst-type
  vpc_security_group_ids      = [aws_security_group.allow_http.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = true
  subnet_id                   = module.deploy_vpc.subnet_a_public_id

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted = true
  }

  volume_tags = {
    Name = "Wordpress - Apache"
  }

  user_data = data.template_file.script.rendered
  tags = {
    Name = "Wordpress - Apache (EFS)"
  }
}

resource "aws_instance" "db" {
  ami                         = var.amis[var.region]
  instance_type               = var.db-inst-type
  vpc_security_group_ids      = [aws_security_group.allow_mysql.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = true
  subnet_id                   = module.deploy_vpc.subnet_a_public_id

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted = true
  }

  volume_tags = {
    Name = "Wordpress - Mariadb"
  }

  user_data = file("../../user_data/install_db.sh")
  tags = {
    Name = "Wordpress - Mariadb"
  }
}

resource "aws_eip" "ip_web" {
  vpc      = true
  instance = aws_instance.web.id
}


data "template_file" "script" {
  template = file("../../user_data/install_web_efs.sh")
  vars = {
    efs_id = aws_efs_file_system.www.id
  }
}