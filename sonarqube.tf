# ============================================================
# sonarqube.tf — SonarQube code quality server (EC2)
# ============================================================

resource "aws_instance" "sonarqube" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"   # SonarQube needs ≥ 2 GB RAM
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.sonarqube.id]
  key_name               = aws_key_pair.jenkins.key_name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = base64encode(file("${path.module}/scripts/sonarqube_bootstrap.sh"))

  tags = {
    Name = "${var.project_name}-sonarqube"
  }
}

output "sonarqube_url" {
  description = "SonarQube web UI URL"
  value       = "http://${aws_instance.sonarqube.public_ip}:9000"
}
