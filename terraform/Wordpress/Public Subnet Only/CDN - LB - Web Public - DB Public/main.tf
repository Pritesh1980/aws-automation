provider "aws" {
  profile = "work-user"
  region  = var.region
}


module "deploy_vpc" {
  source = "../../../VPC/public_with_igw"

  region = var.region
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
    description = "HTTP from load balancer"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
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


# IAM role for SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name               = "ec2-ssm-role"
  assume_role_policy = "${file("assumerolepolicy.json")}"
}

resource "aws_iam_policy" "ssm_policy" {
  name   = "ec2-ssm_policy"
  policy = "${file("ssm_policy.json")}"
}

resource "aws_iam_role_policy_attachment" "ssm-attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_instance_profile" "ssm_profile" {
  #name = "ec2-ssm-profile"
  role = "${aws_iam_role.ec2_ssm_role.name}"
}

resource "aws_instance" "web" {
  ami                         = var.amis[var.region]
  instance_type               = var.web-inst-type
  vpc_security_group_ids      = [aws_security_group.allow_http_from_lb.id]
  iam_instance_profile        = "${aws_iam_instance_profile.ssm_profile.name}"
  associate_public_ip_address = true
  subnet_id                   = module.deploy_vpc.subnet_a_public_id

  user_data = "${file("../../user_data/install_web.sh")}"
  tags = {
    Name = "Wordpress - Apache"
  }
}

resource "aws_instance" "db" {
  ami                         = var.amis[var.region]
  instance_type               = var.db-inst-type
  vpc_security_group_ids      = [aws_security_group.allow_mysql_from_www.id]
  iam_instance_profile        = "${aws_iam_instance_profile.ssm_profile.name}"
  associate_public_ip_address = true
  subnet_id                   = module.deploy_vpc.subnet_a_public_id

  user_data = "${file("../../user_data/install_db.sh")}"
  tags = {
    Name = "Wordpress - Mariadb"
  }
}

resource "aws_lb" "lb" {
  name               = "Web-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = [module.deploy_vpc.subnet_a_public_id,module.deploy_vpc.subnet_b_public_id,module.deploy_vpc.subnet_c_public_id]

  enable_deletion_protection = false

  tags = {
    Name = "Web ALB"
  }
}

resource "aws_lb_target_group" "web_target_group" {
  name     = "Web-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.deploy_vpc.vpc_id

  target_type = "instance"
}

resource "aws_alb_target_group_attachment" "web_attach" {
  target_group_arn = aws_lb_target_group.web_target_group.arn
  target_id        = aws_instance.web.id
  port             = 80
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

# Add Cloudfront distribution pointing at ALB
resource "aws_cloudfront_distribution" "alb_distribution" {
  origin {
    domain_name = aws_lb.lb.dns_name
    origin_id   = aws_lb.lb.id
    origin_path = "/blog"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution pointing to ALB"
  default_root_object = "index.php"


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true
    target_origin_id = aws_lb.lb.id 

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

   restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"


  viewer_certificate {
    cloudfront_default_certificate = true
  }
}