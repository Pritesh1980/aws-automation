output "web_ip" {
  value = aws_eip.ip_web.public_ip
}

output "region" {
  value = var.region
}
