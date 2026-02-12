output "broker_endpoint" {
  description = "The RabbitMQ primary AMQP endpoint"
  # Since RabbitMQ in Amazon MQ usually provides a list, we take the first one
  value = aws_mq_broker.rabbitmq.instances[0].endpoints[0]
}