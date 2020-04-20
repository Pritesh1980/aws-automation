provider "aws" {
  profile    = "work-user"
  region = var.region
}



resource "aws_instance" "node" {
  instance_type = "t2.nano"
  count         = var.instance_count
  ami           = lookup(var.ami,var.region)

  tags = {
    Name  = "Terraform-${count.index + 1}"
    Batch = "5AM"
  }
}