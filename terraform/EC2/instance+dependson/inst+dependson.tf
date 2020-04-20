provider "aws" {
  profile    = "work-user"
  region     = "eu-west-1"
}

resource "aws_s3_bucket" "data" {
  bucket = "pm535-tf-s3-eg"
  acl    = "private"
}

resource "aws_instance" "node" {
  ami           = "ami-06ce3edf0cff21f07"
  instance_type = "t2.nano"

  # Tells Terraform that this EC2 instance must be created only after the
  # S3 bucket has been created.
  depends_on = [aws_s3_bucket.data]
}



