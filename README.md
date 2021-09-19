# PACKER - IMAGE BUILDER
## (AMI with Ansible Provisioned Docker Container)

[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)

Here I have created an Amazon Machine Golden Image with a packer as Infrastructure as Code. The AMI is provisioned with a docker container with httpd image using the Ansible playbook. 

Packer is a tool for building identical machine images for multiple platforms from a single source configuration. It is also lightweight, runs on every major operating system, and is highly performant, creating machine images for multiple platforms in parallel.



## Features

- Fast Infrastructure Deployment - Allows to launch, completely provision, and configured machines in seconds
- Multi-provider portability 
- Automated scripts to install and configure the software within the Packer-made images.
- Packer installs and configures all the software for a machine at the time the image is built.

# Architecture

![
alt_txt
](https://i.ibb.co/N38xsJC/packer-1.jpg)

## Pre-Requests

- Ansible and IAM Role with necessary privileges, should be configured with the instance 
> IAM Role Creation refer - [IAM Role Steps](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create.html)


>Ansible Installation refer - [Ansible Installation Steps](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) 


## Packer Installation Steps

```sh
wget https://releases.hashicorp.com/packer/1.7.5/packer_1.7.5_linux_amd64.zip
unzip packer_1.7.5_linux_amd64.zip
mv packer /usr/bin/
```

## Packer Code

> Here update the below-given variables with the required values as per the requirements. Consider given below as an example.

```sh
#######################################################
            # Variable Declaration
#######################################################
variable "region" {
    default = "us-east-1"
}

variable "instance_type" {
    default = "t2.micro"
}
#######################################################
            # Timestamp Variable
#######################################################

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ec2-docker" {
  ami_name                  = "Packer-AMI-${local.timestamp}"
  ami_description           = "Amazon Linux 2 Image-AMI Created Via Packer"
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
      playbook_file = "./ansible.yml"
  }
}
```

## Ansible Playbook For Docker Provisioning 

> Update the variables as per the requirements. Consider the below given as an example

```sh
---
- name: "Docker Container For HTTP"
  hosts: all
  become: yes
  vars:
    - image_name: "httpd:2.4.48"
    - container_name: "webserver" 
    - ports: "8080:80"
  tasks:
    - name: "Installing PIP"
      yum:
        name: pip
        state: present
    - name: "Dependency Install dokcer-py"
      pip:
        name: docker-py
        state: present
    - name: "Installing Docker"
      shell: amazon-linux-extras install docker -y
    - name: "Docker Service Starting / Enabling"
      service:
        name: docker
        state: restarted
        enabled: true
    - name: "Pulling httpd Docker Image"
      docker_image: 
        name: "{{image_name}}"
        source: pull
    - name: "Creating Docker Container"
      docker_container:
        name: "{{container_name}}"
        detach: yes
        image: "{{image_name}}"
        ports: "{{ports}}"
        state: started
    - name: "Listing the Container"
      shell: docker container ls -q
      register: out
    - name: debug
      debug: var=out.stdout
    - name: "Cronjob For Reboot"
      cron:
        name: "Cronjob"
        special_time: reboot
        job: docker container start {{ item }}
      with_items:
        - "{{ out.stdout_lines }}"
```
## User Instructions

- Clone the Git repository
```sh
git clone https://github.com/ajish-antony/packer-image-builder.git
```

- Update the variables according to the requirements and proceeds with Image build using the below command

```sh
packer build image.pkr.hcl
```

## Conclusion

Here I have made use of the HashiCorp Packer which makes it easy to use and automates the creation of any type of machine image.



### ⚙️ Connect with Me

<p align="center">
<a href="mailto:ajishantony95@gmail.com"><img src="https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white"/></a>
<a href="https://www.linkedin.com/in/ajish-antony/"><img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white"/></a>
