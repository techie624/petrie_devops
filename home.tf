provider "aws" {
  region  = "us-east-1"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

resource "aws_security_group" "ethorian_net_home_sg" {
  name        = "ethorian_net_home_sg"
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

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ethorian_net_home_sg"
  }
}

resource "aws_instance" "ethorian_net_home" {
  ami           = "ami-053b0d53c279acc90" # Ubuntu 22.04 AMI ID (64-bit)
  instance_type = "t2.micro"

  security_groups = [aws_security_group.ethorian_net_home_sg.name]

  key_name = aws_key_pair.my_key.key_name

  vpc_security_group_ids = [aws_security_group.ethorian_net_home_sg.id]

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 30  # Set the root volume size to 30 GB
    encrypted   = false  # Set to true if you want to enable EBS encryption
  }
  
  user_data = <<-EOT
                #!/bin/bash

                # user_data takes a couple minutes to finish
                # sudo cat /var/log/cloud-init-output.log

                # TAG
                TAG=$(date +"%Y%m%d_%H%M%S")
                START_TIME=$(date +%s)

                # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
                ### Configure instance

                # Set date time to EST
                timedatectl set-timezone America/New_York

                # Create the rpetrie user
                useradd rpetrie -m -s /bin/bash
                echo "rpetrie ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

                # Set up SSH for rpetrie
                mkdir /home/rpetrie/.ssh
                echo "${var.SSH_PUBLIC_KEY}" > /home/rpetrie/.ssh/authorized_keys
                chmod 700 /home/rpetrie/.ssh
                chmod 600 /home/rpetrie/.ssh/authorized_keys
                chown -R rpetrie:rpetrie /home/rpetrie/.ssh

                # Set up the public and private keys for rpetrie
                echo "${var.SSH_PUBLIC_KEY_HOME}" > /home/rpetrie/.ssh/id_rsa.pub
                echo "${var.OPEN_SSH_PRIVATE_KEY}" > /home/rpetrie/.ssh/id_rsa
                chmod 644 /home/rpetrie/.ssh/id_rsa.pub
                chmod 600 /home/rpetrie/.ssh/id_rsa
                chown rpetrie:rpetrie /home/rpetrie/.ssh/id_rsa.pub
                chown rpetrie:rpetrie /home/rpetrie/.ssh/id_rsa


                # Set hostname
                hostnamectl set-hostname ethoria-home

                # Append custom lines to rpetrie's .bashrc
                cat <<EOL >> /home/rpetrie/.bashrc

                # Custom settings
                alias ll="ls -larth"
                alias vi="vim"
                alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"'
                alias vialias='vim ~/.bashrc'
                alias uucr='sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get autoclean && sudo reboot'
                alias pull='cd /home/rpetrie/workspace/ethorian_brindlings && git stash && git pull'
                
                # Terminal
                git_branch() {
                  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
                }

                export PS1="\[\033[0;36m\]\[\033[0m\033[0;36m\]\u\[\033[0;37m\]@\[\033[0;34m\]\h \[\033[00;37m\][\w] \[\033[0;91m\]\$(git_branch) \[\033[95m\]\d \t \[\033[00m\]\n#~> "

                EOL

                # Ensure ownership is correct
                chown rpetrie:rpetrie /home/rpetrie/.bashrc

                # Update the system
                apt-get update

                # Install the requested packages
                apt-get install -y vim tree htop tmux curl git apache2-utils

                # Install Docker
                apt-get install -y apt-transport-https ca-certificates curl software-properties-common
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
                add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
                apt-get update
                apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                usermod -aG docker rpetrie

                # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
                ### Nginx installation and configuration for reverse proxy

                # Install Nginx
                apt-get install -y nginx

                # Configure Nginx for ethorian.net
                cat <<'EOF' > /etc/nginx/sites-available/ethorian.net
                server {
                    listen 80;
                    listen [::]:80;
                    server_name ethorian.net;

                    location / {
                        proxy_pass http://localhost:8080;
                        proxy_set_header Host \$host;
                        proxy_set_header X-Real-IP \$remote_addr;
                        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto \$scheme;
                    }
                }
                EOF
                
                # Configure Nginx for brindlings.ethorian.net
                cat <<'EOF' > /etc/nginx/sites-available/brindlings.ethorian.net
                server {
                    listen 80;
                    listen [::]:80;
                    server_name brindlings.ethorian.net;

                    location / {
                        proxy_pass http://localhost:8081;
                        proxy_set_header Host \$host;
                        proxy_set_header X-Real-IP \$remote_addr;
                        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto \$scheme;
                    }
                }
                EOF

                # Configure Nginx for ember-hearts.ethorian.net
                cat <<'EOF' > /etc/nginx/sites-available/ember-hearts.ethorian.net
                server {
                    listen 80;
                    listen [::]:80;
                    server_name ember-hearts.ethorian.net;

                    location / {
                        proxy_pass http://localhost:8082;
                        proxy_set_header Host \$host;
                        proxy_set_header X-Real-IP \$remote_addr;
                        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto \$scheme;
                    }
                }
                EOF

                # Enable the configurations
                ln -s /etc/nginx/sites-available/brindlings.ethorian.net /etc/nginx/sites-enabled/
                ln -s /etc/nginx/sites-available/ember-hearts.ethorian.net /etc/nginx/sites-enabled/

                # Remove the default site configuration
                rm /etc/nginx/sites-enabled/default

                # Reload Nginx to apply the configurations
                systemctl reload nginx

                # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
                ### Clone repo and run container for site

                # Create workspace directory
                mkdir -p /home/rpetrie/workspace
                chown rpetrie:rpetrie /home/rpetrie/workspace

                # Switch to the 'rpetrie' user and run commands as that user
                echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> /home/rpetrie/.ssh/config
                ssh-keyscan github.com >> /home/rpetrie/.ssh/known_hosts

                # Clone the repository

                su - rpetrie -c "echo 'Current User: '\$(whoami) && echo 'Current dir: '\$(pwd)"
                
                su - rpetrie -c 'cd /home/rpetrie/workspace && git clone git@github.com:techie624/ethorian_brindlings.git'
                su - rpetrie -c 'cd /home/rpetrie/workspace && git clone git@github.com:techie624/ethorian_home.git'

                su - rpetrie -c 'cd /home/rpetrie/workspace/ethorian_brindlings && bash run.sh'

                sleep 1

                su - rpetrie -c 'cd /home/rpetrie/workspace/ethorian_home && bash run.sh'

                # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
                ### Clone repo and run container for site dm

                # Clone the repository
                # su - rpetrie -c 'cd /home/rpetrie/workspace && git clone git@github.com:techie624/ethoria_dm.git'
                # su - rpetrie -c 'htpasswd -cb /home/rpetrie/workspace/ethoria_dm/.htpasswd ${var.HTPASSWD_USER} ${var.HTPASSWD_PASS}'

                # su - rpetrie -c 'cd /home/rpetrie/workspace/ethoria_dm && bash run.sh'

                # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
                ### End script and show execution time

                docker start ethorian-home ethorian-brindlings || true
                docker ps -a

                # echo completion
                END_TIME=$(date +%s)
                DURATION=$((END_TIME - START_TIME))
                echo;
                echo "user_data has completed!"
                echo "Script execution time: $DURATION seconds"
                echo "Current date/time: $TAG"
                echo;

              EOT

  tags = {
    Name = "ethorian_net_home"
  }
}

resource "aws_key_pair" "my_key" {
  key_name   = "ethorian_home_keypair"
  public_key = var.SSH_PUBLIC_KEY
}

terraform {
  backend "s3" {
    bucket = "rpetrie-tfstate"
    key    = "statefile.tfstate"
    region = "us-east-1"
  }
}

resource "aws_route53_record" "example" {
  zone_id = var.ETHORIAN_NET_HOSTED_ZONE_ID
  name    = "ethorian.net"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.ethorian_net_home.public_ip]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "subdomain_record_brindlings" {
  zone_id = var.ETHORIAN_NET_HOSTED_ZONE_ID
  name    = "brindlings.ethorian.net"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.ethorian_net_home.public_ip]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "subdomain_record_dm" {
  zone_id = var.ETHORIAN_NET_HOSTED_ZONE_ID
  name    = "dm.ethorian.net"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.ethorian_net_home.public_ip]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "subdomain_record_emberhearts" {
  zone_id = var.ETHORIAN_NET_HOSTED_ZONE_ID
  name    = "ember-hearts.ethorian.net"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.ethorian_net_home.public_ip]

  lifecycle {
    create_before_destroy = true
  }
}

