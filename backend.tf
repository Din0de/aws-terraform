# File that backs up info to buckets

terraform {
  backend "s3" {
    bucket = "tf-dk-2025"
    key    = "key/tf-dk-2025"
    region = "us-east-1"
  }
}
