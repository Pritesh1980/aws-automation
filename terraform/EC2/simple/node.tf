provider "aws" {
  profile    = "work-user"
  region     = "eu-west-1"
}

resource "aws_instance" "node" {
  ami           = "ami-06ce3edf0cff21f07"
  instance_type = "t2.nano"
}