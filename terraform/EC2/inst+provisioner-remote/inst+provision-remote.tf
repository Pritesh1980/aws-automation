provider "aws" {
  profile    = "work-user"
  region     = "eu-west-1"
}

# See Usage.md to see how to create example keyfile
resource "aws_key_pair" "tf" {
  key_name   = "terraformkey"
  public_key = file("./terraform.pub")
}

resource "aws_instance" "node" {
  key_name      = aws_key_pair.tf.key_name

  ami           = "ami-06ce3edf0cff21f07"
  instance_type = "t2.nano"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("./terraform")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo systemctl start httpd"
    ]
  }
}


