provider "aws" {
  region  = "us-east-1"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

resource "aws_security_group" "example" {
  name        = "example"
  description = "Allow SSH inbound and all outbound traffic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example"
  }
}

resource "aws_instance" "my_instance" {
  ami           = "ami-053b0d53c279acc90" # Ubuntu 22.04 AMI ID (64-bit)
  instance_type = "t2.micro"

  security_groups = [aws_security_group.example.name]

  key_name = aws_key_pair.my_key.key_name

  vpc_security_group_ids = [aws_security_group.example.id]


  user_data = <<-EOF
                #!/bin/bash

                # user_data takes a couple minutes to finish
                # tail -f /var/log/cloud-init-output.log

                # TAG
                TAG=$(date +"%Y%m%d_%H%M%S")
                START_TIME=$(date +%s)

                # Set date time to EST
                timedatectl set-timezone America/New_York

                # For the default ubuntu user
                echo "${var.SSH_PUBLIC_KEY}" > /home/ubuntu/.ssh/authorized_keys
                chmod 600 /home/ubuntu/.ssh/authorized_keys
                chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

                # Create the rpetrie user
                useradd rpetrie -m -s /bin/bash
                echo "rpetrie ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

                # Set up SSH for rpetrie
                mkdir /home/rpetrie/.ssh
                echo "${var.SSH_PUBLIC_KEY}" > /home/rpetrie/.ssh/authorized_keys
                chmod 700 /home/rpetrie/.ssh
                chmod 600 /home/rpetrie/.ssh/authorized_keys
                chown -R rpetrie:rpetrie /home/rpetrie/.ssh

                # Set hostname
                hostnamectl set-hostname testing

                # Append custom lines to rpetrie's .bashrc
                cat <<EOL >> /home/rpetrie/.bashrc

                # Custom settings
                alias ll="ls -larth"
                alias ..="cd .."
                EOL

                # Ensure ownership is correct
                chown rpetrie:rpetrie /home/rpetrie/.bashrc

                # Update the system
                apt-get update

                # Install the requested packages
                apt-get install -y vim tree htop tmux curl git

                # Install Docker
                apt-get install -y apt-transport-https ca-certificates curl software-properties-common
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
                add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
                apt-get update
                apt-get install -y docker-ce
                usermod -aG docker rpetrie

                # echo completion
                END_TIME=$(date +%s)
                DURATION=$((END_TIME - START_TIME))
                echo;
                echo "user_data has completed!"
                echo "Script execution time: $DURATION seconds"
                echo "Current date/time: $TAG"
                echo;

              EOF

  tags = {
    Name = "Instance1"
  }
}

resource "aws_key_pair" "my_key" {
  key_name   = "my_key_pair"
  public_key = var.SSH_PUBLIC_KEY
}

terraform {
  backend "s3" {
    bucket = "rpetrie-tfstate"
    key    = "statefile.tfstate"
    region = "us-east-1"
    # If using DynamoDB for state locking (recommended):
    # dynamodb_table = "your-dynamodb-table-name"
  }
}

resource "aws_route53_record" "example" {
  zone_id = var.ETHORIAN_NET_HOSTED_ZONE_ID # replace this with your hosted zone ID
  name    = "ethorian.net"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.my_instance.public_ip]
}

resource "aws_route53_record" "subdomain_record" {
  name    = "home.ethorian.net"
  type    = "A"
  zone_id = var.ETHORIAN_NET_HOSTED_ZONE_ID
  ttl     = "300"
  records = [aws_instance.my_instance.public_ip]
}
