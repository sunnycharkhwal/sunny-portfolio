# ============================================================
# jenkins.tf — Jenkins CI server (EC2 instance)
# ============================================================

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM role for Jenkins EC2 (ECR push + EKS describe) ────────
resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_iam_role_policy" "jenkins_ecr_eks" {
  name = "${var.project_name}-jenkins-ecr-eks"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── Key Pair for SSH access ───────────────────────────────────
# NOTE: Replace the public_key value with YOUR OWN public key
# Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/jenkins-key
resource "aws_key_pair" "jenkins" {
  key_name   = "${var.project_name}-jenkins-key"
  public_key = "ssh-rsa AAAA...YOUR_PUBLIC_KEY_HERE"   # ← Replace this
}

# ── Jenkins EC2 Instance ──────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.large"   # Jenkins needs at least 2 vCPU / 4 GB
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  key_name               = aws_key_pair.jenkins.key_name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # ── Bootstrap: install Java, Jenkins, Docker, kubectl ────────
  user_data = base64encode(templatefile("${path.module}/scripts/jenkins_bootstrap.sh", {
    aws_region       = var.aws_region
    ecr_repo_url     = aws_ecr_repository.app.repository_url
    eks_cluster_name = var.eks_cluster_name
    github_repo      = var.github_repo
  }))

  tags = {
    Name = "${var.project_name}-jenkins"
  }

  depends_on = [aws_eks_cluster.main]
}

output "jenkins_public_ip" {
  description = "SSH / browser access: http://<ip>:8080"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_initial_password_cmd" {
  description = "Run this on the Jenkins server to get the initial admin password"
  value       = "ssh -i ~/.ssh/jenkins-key ec2-user@${aws_instance.jenkins.public_ip} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
}
