data "aws_vpc" "default" {
  default = true
}


data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  prefix = "td2-${var.student_id}"
}
