output "db_endpoint" {
  description = "The DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.docdb.endpoint
}