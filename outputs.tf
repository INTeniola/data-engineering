output "aws_iot_endpoint" {
  value = data.aws_iot_endpoint.endpoint.endpoint_address
}

output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.api_deployment.invoke_url}/energy/device/{device_id}"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.data_storage.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.energy_data.name
}

# Get IoT endpoint
data "aws_iot_endpoint" "endpoint" {
  endpoint_type = "iot:Data-ATS"
}
