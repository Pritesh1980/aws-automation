output "lb_dns" {
  value = aws_lb.lb.dns_name
}

output "region" {
  value = var.region
}

output "cdn_dns" {
  value = aws_cloudfront_distribution.alb_distribution.domain_name
}