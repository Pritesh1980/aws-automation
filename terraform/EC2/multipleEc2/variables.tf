variable "ami" {
  type = map(string)
  default = {
    "eu-west-1" = "ami-06ce3edf0cff21f07"
    "eu-west-2" = "ami-01a6e31ac994bbc09"
  }
}

variable "region" {
  default = "eu-west-1"
}

variable "instance_count" {
  default = "3"
}