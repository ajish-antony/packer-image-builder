# PACKER - IMAGE BUILDER

## (Packer AMI + Ansible Provisioned Docker Container + Python Flask + CI/CD Jenkins)

[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)

Here I have created an Amazon Machine Golden Image with a packer as Infrastructure as Code. The Image has been provisioned with a docker container and in that docker container, a python flask application is configured. In the part of CI/CD - Jenkins provides a pipeline with the upstream job. So the first project triggers another project as part of its execution. 

The first phase of the project is that the developers will be updating the necessary changes in the flask application, once they have completed the changes. They will upload the code to the Github Central Repository. In the part of Jenkins, a pipeline job is set up. The initial job is to build an image with the details updated by the developers and for triggering the job a webhook is configured. In that process, an image is created and it will be updated to the docker hub. These mentioned processes will be implemented via an ansible playbook. 

The second phase for the project is packer AMI building. As mentioned above a pipeline job is configured in the Jenkins. Once the initial job executes successfully and stable state. It will move on with the second job and in that packer will be triggered via the packer plugin in Jenkins. An image will be created and for the same, the ansible-playbook provisioning  a docker container with the image that has been uploaded to the docker hub which contains the python flask application.


**Packer** is a tool for building identical machine images for multiple platforms from a single source configuration. It is also lightweight, runs on every major operating system, and is highly performant, creating machine images for multiple platforms in parallel.

**Flask** is an API of Python that allows to build up web applications. Flask’s framework is more explicit than Django’s framework. A Web-Application Framework is the collection of modules and libraries that helps the developer to write applications without writing the low-level codes such as protocols, thread management. 


## Features

- Fast Infrastructure Deployment - Allows to launch, completely provision, and configured machines in seconds
- Multi-provider portability 
- Automated scripts to install and configure the software within the Packer-made images.
- Packer installs and configures all the software for a machine at the time the image is built.
- Flask is easier to learn as it has less base code to implement a simple web-Application
- Continuous Deployment with Jenkins, makes whole jobs simpler

# Architecture

![
alt_txt
](https://i.ibb.co/Q8cGmsm/Copy-of-packer-1.jpg)

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
## Jenkins Installation Steps

```sh
amazon-linux-extras install epel -y
yum install java-1.8.0-openjdk-devel -y
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
yum -y install jenkins
systemctl start jenkins
systemctl enable jenkins
```

## Packer Code

> Here update the below-given variables with the required values as per the requirements. Consider given below as an example.

```sh
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
  security_group_ids        = ["sg-0ef0d*******6a0a"]
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
      playbook_file = "/var/pack/ansible.yml"
  }
}
```

## Ansible Playbook 

#### Ansible Playbook For Python Flask Image creation and Uploads to Docker Hub

> Update the variables as per the requirements. Consider the below given as an example

```sh
---
- name: "Docker Image build & Push To Docker Hub"
  hosts: localhost
  become: true
  vars:
    git_repo_url: "https://github.com/ajish-antony/python-flask.git"
    git_clone: "/var/git/"
    image_name: "ajishantony2020/python-flask"
    docker_password: "***********"
    docker_username: "Mention-DockerHub-Username"

  tasks:
    - name: "Installing PIP"
      yum:
        name:
          - pip
          - git
        state: present
    - name: "Dependency Install dokcer-py"
      pip:
        name: docker-py
        state: present
    - name: "Cloning the conetents From GitHub"
      git:
        repo: '{{git_repo_url}}'
        dest: '{{git_clone}}'
      register: repo_status
    - name: "Installing Docker"
      shell: amazon-linux-extras install docker -y
    - name: "Docker Service Starting / Enabling"
      service:
        name: docker
        state: restarted
        enabled: true
    - name: "Log into DockerHub"
      docker_login:
        username: "{{docker_username}}"
        password: "{{docker_password}}"
    - name: "Build Python Image"
      docker_image:
        source: build
        build:
          path: "{{git_clone}}"
        name: "{{image_name}}"
        tag: latest
        push: true
    - name: "Removing Image Created"
      docker_image:
        state: absent
        name: "{{ image_name }}"
        tag: "{{ item }}"
      with_items:
        - "{{ repo_status.after }}"
        - latest
```

#### For Provisioning Docker Container with Python Flask Application Image From DockerHub

> Update the variables as per the requirements. Consider the below given as an example

```sh
---
- name: "Docker Container For Python-Flask"
  hosts: all
  become: yes
  vars:
    - image_name: "ajishantony2020/python-flask"
    - container_name: "webserver"
    - ports: "8081:5000"
  tasks:
    - name: "Installing PIP"
      yum:
        name:
          - pip
          - git
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
        restart_policy: always
        image: "{{image_name}}"
        ports: "{{ports}}"
        state: started
```

## User Instructions

- Clone the Git repository
```sh
git clone https://github.com/ajish-antony/packer-image-builder.git
```
### Jenkins Configuration

- Install the Packer Plugin and configure accordingly
- In the Same way, Install the Ansible plugin and configure it
- Update the webhook URL of GitHub for triggering the Jenkins
> Similar configuration of the Jenkins and the plugins can be referred to another project:- https://github.com/ajish-antony/asg-rolling-update

> Other Main Points to note that to update the packer plugin with the file that needs to perform the action

![
alt_txt
](https://i.ibb.co/wKm1r7T/packer-build.png)

> Next in the Post-build Action in the first project to trigger the packer. Consider the below given as an example.

![
alt_txt
](https://i.ibb.co/YdvgGSW/python-postbuild.png)

> Once the whole process completes, consider as sample output from the Jenkins

![
alt_txt
](https://i.ibb.co/5rg619b/pipeline.png)

#### Packer Image Build

- For manually building the packer AMI. Update the variables according to the requirements in the files and proceeds with Image build using the below command

```sh
packer build image.pkr.hcl
```

## Conclusion

Here I have made use of the HashiCorp Packer which makes Image creation easier. A single line can be defined as once the developer uploads the python application code  to Github, the automation process will create a DocKer image and uploads it to the Docker Hub, and further, an AMI will be created with packer having docker container provisioned with an image of python flask application from Docker Hub. 



### ⚙️ Connect with Me

<p align="center">
<a href="mailto:ajishantony95@gmail.com"><img src="https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white"/></a>
<a href="https://www.linkedin.com/in/ajish-antony/"><img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white"/></a>
