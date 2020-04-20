provider "aws" {
  profile    = "work-user"
  region     = "eu-west-1"
}

resource "aws_instance" "node" {
  ami           = "ami-06ce3edf0cff21f07"
  instance_type = "t2.nano"
}

resource "aws_eip" "ip" {
    vpc = true
    instance = aws_instance.node.id
}

output "ip" {
  value = aws_eip.ip.public_ip
}

