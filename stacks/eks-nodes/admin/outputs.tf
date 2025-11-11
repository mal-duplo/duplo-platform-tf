output "node_ami" {
  value     = local.asg_ami
  sensitive = true
}

output "node_ami_description" {
  value = data.aws_ami.ami.description
}