output "lb_dns" {
  value = aws_lb.lb.dns_name
}

output "region" {
  value = var.region
}
