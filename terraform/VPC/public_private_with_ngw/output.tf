output "vpc_id" {
  value = aws_vpc.main.id
}
output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}
output "subnet_a_public_cidr" {
  value = aws_subnet.public_a.cidr_block
}
output "subnet_a_private_cidr" {
  value = aws_subnet.private_a.cidr_block
}
output "subnet_b_public_cidr" {
  value = aws_subnet.public_b.cidr_block
}
output "subnet_b_private_cidr" {
  value = aws_subnet.private_b.cidr_block
}
output "subnet_c_public_cidr" {
  value = aws_subnet.public_c.cidr_block
}
output "subnet_c_private_cidr" {
  value = aws_subnet.private_c.cidr_block
}

output "subnet_a_public_id" {
  value = aws_subnet.public_a.id
}

output "subnet_a_private_id" {
  value = aws_subnet.private_a.id
}