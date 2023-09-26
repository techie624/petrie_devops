
resource "aws_instance" "ethorian_net_dm" {
  ami           = "ami-053b0d53c279acc90" # Ubuntu 22.04 AMI ID (64-bit)
  instance_type = "t2.micro"

  security_groups = [aws_security_group.ethorian_net_home_sg.name]

  key_name = aws_key_pair.my_key.key_name

  vpc_security_group_ids = [aws_security_group.ethorian_net_home_sg.id]
  
  user_data = <<-EOF
                #!/bin/bash

                # user_data takes a couple minutes to finish
                # tail -f /var/log/cloud-init-output.log

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
                hostnamectl set-hostname ethoria-dm

                # Append custom lines to rpetrie's .bashrc
                cat <<EOL >> /home/rpetrie/.bashrc

                # Custom settings
                alias ll="ls -larth"
                alias vi="vim"
                alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"'
                alias vialias='vim ~/.bashrc'
                alias uucr='sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get autoclean && sudo reboot'
                
                # Terminal                                                                                      
                git_branch() {                                                                                                    
                      git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'                         
                  }                                                                                                               
                                                                                                                
                export PS1="\[\033[0;36m\]\[\033[0m\033[0;27m\]\u\[\033[0;37m\]@\[\033[0;31m\]\h \[\033[00;33m\][\w] \[\033[0;37m\]\$(git_branch) \[\033[95m\]\d \t \[\033[00m\]\n#~> "
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
                apt-get install -y docker-ce
                usermod -aG docker rpetrie


                # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
                ### Clone repo and run container for site

                # Create workspace directory
                mkdir -p /home/rpetrie/workspace
                chown rpetrie:rpetrie /home/rpetrie/workspace

                # disable host key checking
                echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> /home/rpetrie/.ssh/config
                ssh-keyscan github.com >> /home/rpetrie/.ssh/known_hosts

                echo "sleeping 10..."
                sleep 10
                echo;

                # Clone the repository
                su rpetrie
                cd /home/rpetrie/workspace
                git clone git@github.com:techie624/ethoria_dm.git 

                # Run the script to start the container
                cd /home/rpetrie/workspace/ethoria_dm
                htpasswd -cb .htpasswd ${var.HTPASSWD_USER} ${var.HTPASSWD_PASS}
                bash run.sh

                # Set up the cron job
                echo "0 * * * * /bin/bash /home/rpetrie/workspace/ethoria_dm/git_pull_deploy.sh >> /home/rpetrie/pull.log 2>&1" | crontab -

                # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
                ### End script and show execution time

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
    Name = "ethorian_net_dm"
  }
}

resource "aws_route53_record" "subdomain_record_dm" {
  zone_id = var.ETHORIAN_NET_HOSTED_ZONE_ID
  name    = "dm.ethorian.net"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.ethorian_net_dm.public_ip]

  lifecycle {
    create_before_destroy = true
  }
}
