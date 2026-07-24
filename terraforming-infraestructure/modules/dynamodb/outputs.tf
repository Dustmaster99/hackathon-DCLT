output "table_arn" {
  description = "ARN da tabela DynamoDB."
  value       = aws_dynamodb_table.this.arn
}

output "table_id" {
  description = "ID da tabela DynamoDB."
  value       = aws_dynamodb_table.this.id
}

output "table_name" {
  description = "Nome da tabela DynamoDB."
  value       = aws_dynamodb_table.this.name
}

output "table_stream_arn" {
  description = "ARN do stream da tabela, quando habilitado."
  value       = aws_dynamodb_table.this.stream_arn
}

