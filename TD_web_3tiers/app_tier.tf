
# AMI Amazon Linux 2023 la plus récente (partagée avec web_tier.tf)
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

# --- ALB INTERNE (jamais joignable depuis Internet) ---
resource "aws_lb" "internal" {
  name               = "td-alb-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_internal.id]
  subnets            = aws_subnet.app[*].id
}

resource "aws_lb_target_group" "app" {
  name     = "td-tg-app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- Instances EC2 du tier APP (une par AZ) ---
resource "aws_instance" "app" {
  count         = 1
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.app[count.index].id

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = templatefile("${path.module}/app/user_data.sh.tpl", {
    db_host     = data.aws_db_instance.postgres.address
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
    app_py      = file("${path.module}/app/app.py")
  })

  tags = { Name = "td-app-${count.index}" }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = 1
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}
