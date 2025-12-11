data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"] # Canonical

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
}

resource "aws_instance" "web_server" {
  count         = var.main_instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public_subnets[count.index].id
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.project_sg.id]
  user_data = templatefile("main-userdata.tpl", {
    new_hostname = "web-server-${random_id.random.dec}-${count.index + 1}"
  })  

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.deployer.private_key_pem
    host        = self.public_ip
  }

  tags = {
    Name = "web-server-${random_id.random.dec}-${count.index + 1}"
  }

}

output "web_server_public_ips" {
  description = "Public IP addresses of the web server instances"
  value       = aws_instance.web_server.*.public_ip
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tpl", {
    web_servers = aws_instance.web_server
  })
  filename = "aws_hosts"
}

resource "null_resource" "wait_for_ssh" {
  count = var.main_instance_count

  depends_on = [aws_instance.web_server]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.deployer.private_key_pem
    host        = aws_instance.web_server[count.index].public_ip
  }

  provisioner "remote-exec" {
    inline = ["echo 'Instance is ready!'"]
  }
}

resource "null_resource" "provisioner" {
  count = var.main_instance_count > 0 ? 1 : 0

  depends_on = [
    local_file.ansible_inventory,
    null_resource.chmod_key,
    null_resource.wait_for_ssh
  ]

  triggers = {
    instance_ids = join(",", aws_instance.web_server.*.id)
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i aws_hosts --private-key terraform.pem -u ubuntu playbook.yml -v"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i aws_hosts --private-key terraform.pem -u ubuntu prometheus-playbook.yml -v"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }
}