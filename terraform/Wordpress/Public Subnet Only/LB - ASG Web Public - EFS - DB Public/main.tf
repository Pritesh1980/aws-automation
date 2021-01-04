provider "aws" {
  profile = var.aws_profile
  region  = var.region
}


module "deploy_vpc" {
  source = "../../../VPC/public_with_igw"

  region      = var.region
  aws_profile = var.aws_profile
}


# SG for LoadBalancer
resource "aws_security_group" "lb" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic from Internet"
  vpc_id      = module.deploy_vpc.vpc_id

  ingress {
    description = "HTTP from Internet"
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
    Name = "allow_http_from_internet"
  }
}

# SG for www from Loadbalancer
resource "aws_security_group" "allow_http_from_lb" {
  name        = "allow_http_from_lb"
  description = "Allow HTTP inbound traffic from Load Balancer"
  vpc_id      = module.deploy_vpc.vpc_id

  ingress {
    description     = "HTTP from load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_from_lb"
  }
}

# SG for MySQL from allow_http_from_lb SG
resource "aws_security_group" "allow_mysql_from_www" {
  name        = "allow_mysql_from_www"
  description = "Allow MySQL inbound traffic from allow_http_from_lb SG"
  vpc_id      = module.deploy_vpc.vpc_id

  ingress {
    description     = "MySQL from allow_http"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_http_from_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_mysql_from_www"
  }
}

resource "aws_security_group" "ingress-efs-sg" {

  name   = "ingress-efs-sg"
  vpc_id = module.deploy_vpc.vpc_id

  ingress {
    security_groups = [aws_security_group.allow_http_from_lb.id]
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
  }

  egress {
    security_groups = [aws_security_group.allow_http_from_lb.id]
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
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
  role = aws_iam_role.ec2_ssm_role.name
}

resource "aws_efs_file_system" "www" {
  creation_token   = "web-server"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"

  tags = {
    Name = "WWW EFS"
  }
}

resource "aws_efs_mount_target" "www-efs-mt" {

  file_system_id  = aws_efs_file_system.www.id
  subnet_id       = module.deploy_vpc.subnet_a_public_id
  security_groups = [aws_security_group.ingress-efs-sg.id]

}


resource "aws_launch_template" "web" {
  name_prefix            = "web_"
  description            = "Web server template"
  update_default_version = true
  image_id               = var.amis[var.region]
  instance_type          = var.web-inst-type
  vpc_security_group_ids = [aws_security_group.allow_http_from_lb.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  credit_specification {
    cpu_credits = "standard"
  }

  user_data = base64encode(data.template_file.script.rendered)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "Wordpress - Apache (EFS) - ASG"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "Volume: Wordpress - Apache (EFS) - ASG"
    }
  }

  tags = {
    Name = "Template: Wordpress - Apache (EFS) - ASG"
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "web_asg_"
  desired_capacity    = 2
  max_size            = 2
  min_size            = 1
  health_check_type   = "EC2"
  target_group_arns   = [aws_lb_target_group.web_target_group.arn]
  vpc_zone_identifier = [module.deploy_vpc.subnet_a_public_id]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
}


resource "aws_instance" "db" {
  ami                         = var.amis[var.region]
  instance_type               = var.db-inst-type
  vpc_security_group_ids      = [aws_security_group.allow_mysql_from_www.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = true
  subnet_id                   = module.deploy_vpc.subnet_a_public_id

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  volume_tags = {
    Name = "Wordpress - Mariadb"
  }

  user_data = file("../../user_data/install_db.sh")
  tags = {
    Name = "Wordpress - Mariadb"
  }
}

resource "aws_lb" "lb" {
  name               = "Web-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = [module.deploy_vpc.subnet_a_public_id, module.deploy_vpc.subnet_b_public_id, module.deploy_vpc.subnet_c_public_id]

  enable_deletion_protection = false

  tags = {
    Name = "Web ALB"
  }
}

resource "aws_lb_target_group" "web_target_group" {
  name_prefix = "WebTG-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.deploy_vpc.vpc_id

  target_type = "instance"
}

# resource "aws_alb_target_group_attachment" "web_attach" {
#   target_group_arn = aws_lb_target_group.web_target_group.arn
#   target_id        = aws_instance.web.id
#   port             = 80
# }

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

data "template_file" "script" {
  template = file("../../user_data/install_web_efs.sh")
  vars = {
    efs_id = aws_efs_file_system.www.id
  }
}