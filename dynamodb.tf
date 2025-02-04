resource "aws_dynamodb_table" "table_example" {
  name           = "table-example"
  billing_mode   = "PROVISIONED"
  hash_key       = "college"
  range_key      = "campus"

  attribute {
    name = "college"
    type = "S" # String type for partition key
  }

  attribute {
    name = "campus"
    type = "S" # String type for sort key
  }

  # Provisioned throughput settings
  read_capacity  = 5
  write_capacity = 5

  tags = {
    "Name" = "DynamoDB table-example"
  }
}

resource "aws_dynamodb_table_item" "example_item" {
  table_name = aws_dynamodb_table.table_example.name

  hash_key  = "college"
  range_key = "campus"

  item = <<ITEM
{
  "college": {"S": "sheridan"},
  "campus": {"S": "trafalgar"}
}
ITEM
}
