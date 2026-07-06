output "vpc_id" {
  description = "ID of the VPC"
  value = aws_vpc.main.id
}

output "public_subnets" {
  description = "List of public subnets"
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "List of private subnets"
  value = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway used by the private subnets"
  value = aws_nat_gateway.nat.id
}