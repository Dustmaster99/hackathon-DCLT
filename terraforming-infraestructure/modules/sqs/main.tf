resource "aws_sqs_queue" "dead_letter" {
  count = var.create_dead_letter_queue ? 1 : 0

  name                      = "${var.queue_name}-dlq"
  message_retention_seconds = var.dead_letter_message_retention_seconds
  sqs_managed_sse_enabled   = true

  tags = merge(
    {
      Name = "${var.queue_name}-dlq"
      Type = "dead-letter"
    },
    var.tags
  )
}

resource "aws_sqs_queue" "this" {
  name                       = var.queue_name
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = var.create_dead_letter_queue ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = merge(
    {
      Name = var.queue_name
      Type = "donation-events"
    },
    var.tags
  )
}

resource "aws_sqs_queue_redrive_allow_policy" "this" {
  count = var.create_dead_letter_queue ? 1 : 0

  queue_url = aws_sqs_queue.dead_letter[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

