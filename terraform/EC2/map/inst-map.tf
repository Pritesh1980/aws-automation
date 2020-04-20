provider "aws" {
  profile    = "work-user"
  region = var.region
}



resource "aws_instance" "node" {
ami           = var.amis[var.region]
  instance_type = "t2.nano"

}