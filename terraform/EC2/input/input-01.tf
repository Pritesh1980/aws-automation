provider "aws" {
  profile    = "work-user"
  region = var.region
}



resource "aws_instance" "node" {
  ami           = "ami-06ce3edf0cff21f07"
  instance_type = "t2.nano"

}


