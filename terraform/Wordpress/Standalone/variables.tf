variable "amis" {
  type = map(string)
  default = {
    "eu-west-1" = "ami-06ce3edf0cff21f07"
    "eu-west-2" = "ami-01a6e31ac994bbc09"
    "eu-west-3" = "ami-0de12f76efe134f2f"
  }
}

variable "region" {
  default = "eu-west-1"
}

variable "inst-type" {
  default = "t2.micro"
}