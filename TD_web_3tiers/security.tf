# Chaine de Security Groups - principe du moindre privilege :
# Internet -> alb_public -> web -> alb_internal -> app -> rds

resource "aws_security_group" "alb_public" {
  name        = "td-alb-public-sg"
  description = "ALB public - HTTP entrant depuis Internet"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web" {
  name        = "td-web-sg"
  description = "Tier web - HTTP depuis ALB public uniquement"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "HTTP depuis ALB public"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_internal" {
  name        = "td-alb-internal-sg"
  description = "ALB interne - HTTP depuis tier web uniquement"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "HTTP depuis tier web"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "td-app-sg"
  description = "Tier app - HTTP depuis ALB interne uniquement"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "HTTP depuis ALB interne"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "td-rds-sg"
  description = "RDS PostgreSQL - port 5432 depuis tier app uniquement"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "PostgreSQL depuis tier app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
