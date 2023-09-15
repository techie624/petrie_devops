provider "aws" {
  region  = "us-east-1"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

resource "aws_instance" "my_instance" {
  ami           = "ami-053b0d53c279acc90" # Ubuntu 22.04 AMI ID (64-bit)
  instance_type = "t2.micro"

  key_name = aws_key_pair.my_key.key_name

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = <<-EOF
              #!/bin/bash
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
              EOF

  tags = {
    Name = "MyInstance"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "my_key" {
  key_name   = "my_key_pair"
  public_key = var.SSH_PUBLIC_KEY
}
