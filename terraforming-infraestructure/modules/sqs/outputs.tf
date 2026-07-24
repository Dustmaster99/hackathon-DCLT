output "queue_url" {
  description = "URL da fila SQS usada pelo donation-service."
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "ARN da fila SQS."
  value       = aws_sqs_queue.this.arn
}

output "queue_name" {
  description = "Nome da fila SQS."
  value       = aws_sqs_queue.this.name
}

output "dead_letter_queue_url" {
  description = "URL da dead-letter queue, quando criada."
  value       = try(aws_sqs_queue.dead_letter[0].url, null)
}

output "dead_letter_queue_arn" {
  description = "ARN da dead-letter queue, quando criada."
  value       = try(aws_sqs_queue.dead_letter[0].arn, null)
}

