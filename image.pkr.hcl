variable "region" {
    default = "us-east-1"
}

variable "instance_type" {
    default = "t2.micro"
}


locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ec2-docker" {
  ami_name                  = "Packer-AMI-${local.timestamp}"
  ami_description           = "Amazon Linux 2 Imaged-AMI Created Via Packer"
  instance_type             = "${var.instance_type}"
  region                    = "${var.region}"
  security_group_ids        = ["sg-0ef0ddc40580e6a0a"]
  source_ami_filter   {
    filters                 = {
      name                  = "amzn2-ami-hvm-2.0.*.1-x86_64-ebs"
      root-device-type      = "ebs"
      virtualization-type   = "hvm"
    }
    most_recent             = true
    owners                  = ["amazon"]
  }
  ssh_username              = "ec2-user"
}
build {
  sources = ["source.amazon-ebs.ec2-docker"]

provisioner "ansible" {
      playbook_file = "Mention-Ansible-File-Location"
  }
}
