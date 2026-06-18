# ---------------------------------------------------------------
# VPC EXISTANT — lecture seule via data source
# ---------------------------------------------------------------
data "aws_vpc" "main" {
  id = var.existing_vpc_id
}

# IGW attaché au VPC existant (le VPC default en a toujours un)
data "aws_internet_gateway" "igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

# --- Subnets PUBLICS à créer dans le VPC existant (un par AZ) ---
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = data.aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "td-public-${count.index}" }
}

# --- Subnets PRIVÉS tier web (un par AZ) ---
resource "aws_subnet" "web" {
  count                   = length(var.azs)
  vpc_id                  = data.aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.web_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "td-web-${count.index}" }
}

# --- Subnets PRIVÉS tier app (un par AZ) ---
resource "aws_subnet" "app" {
  count                   = length(var.azs)
  vpc_id                  = data.aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.app_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "td-app-${count.index}" }
}

# --- Subnets PRIVÉS tier data (un par AZ) ---
resource "aws_subnet" "data" {
  count                   = length(var.azs)
  vpc_id                  = data.aws_vpc.main.id
  availability_zone       = var.azs[count.index]
  cidr_block              = var.data_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "td-data-${count.index}" }
}

# --- NAT Gateway : une seule (limite EIP du compte sandbox) ---
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [data.aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "td-nat" }
  depends_on    = [data.aws_internet_gateway.igw]
}

# --- Table de routage publique ---
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.igw.id
  }
  tags = { Name = "td-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Table de routage privée unique (toutes les AZ via la même NAT) ---
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "td-rt-private" }
}

resource "aws_route_table_association" "web" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private.id
}
