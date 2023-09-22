output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.ethorian_net_home.public_ip
}
