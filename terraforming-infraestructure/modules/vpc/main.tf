resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge({ Name = "${var.project_name}-vpc" }, var.tags)

  lifecycle {
    precondition {
      condition = (
        length(var.public_subnets) == length(var.private_subnets) &&
        length(var.availability_zones) >= length(var.public_subnets) &&
        length(var.availability_zones) >= length(var.database_subnets)
      )
      error_message = "As listas de subnets públicas e privadas devem ter o mesmo tamanho, e cada subnet deve possuir uma zona de disponibilidade."
    }
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge({ Name = "${var.project_name}-igw" }, var.tags)
}

resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name                     = "${var.project_name}-public-${count.index + 1}"
      Tier                     = "public"
      "kubernetes.io/role/elb" = "1"
    },
    var.tags
  )
}

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name                              = "${var.project_name}-private-${count.index + 1}"
      Tier                              = "private"
      "kubernetes.io/role/internal-elb" = "1"
    },
    var.tags
  )
}

resource "aws_eip" "nat" {
  count  = length(var.public_subnets)
  domain = "vpc"

  tags = merge({ Name = "${var.project_name}-nat-eip-${count.index + 1}" }, var.tags)

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = length(var.public_subnets)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge({ Name = "${var.project_name}-nat-${count.index + 1}" }, var.tags)

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge({ Name = "${var.project_name}-public-rt" }, var.tags)
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge({ Name = "${var.project_name}-private-rt-${count.index + 1}" }, var.tags)
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_subnet" "database" {
  count = length(var.database_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.database_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    {
      Name = "${var.project_name}-database-${count.index + 1}"
      Tier = "database"
    },
    var.tags
  )
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id
  tags   = merge({ Name = "${var.project_name}-database-rt" }, var.tags)
}

resource "aws_route_table_association" "database" {
  count = length(var.database_subnets)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

