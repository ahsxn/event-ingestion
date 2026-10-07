data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_ecs_cluster" "main" {
  name = "event-ingestion"
}

resource "aws_iam_role" "ecs_instance" {
  name = "event-ingestion-ecs-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role = aws_iam_role.ecs_instance.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role = aws_iam_role.ecs_instance.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "event-ingestion-ecs-instance"

  role = aws_iam_role.ecs_instance.name
}

resource "aws_instance" "ecs_host" {
  ami           = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.ecs_host.id,
  ]

  iam_instance_profile = aws_iam_instance_profile.ecs.name

  user_data = <<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name = "event-ingestion-ecs-host"
  }
}

data "aws_eip" "ecs_host" {
  tags = {
    Name = "event-ingestion"
  }
}

resource "aws_eip_association" "ecs_host" {
  instance_id   = aws_instance.ecs_host.id
  allocation_id = data.aws_eip.ecs_host.id
}
