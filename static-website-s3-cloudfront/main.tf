resource "aws_s3_bucket" "s3Bucket" {
  bucket = "${var.s3Bucketname}"

  tags = {
    Name        = "${var.name}"
    Environment = "${var.environment}"
  }
}


resource "aws_s3_bucket_website_configuration" "s3BucketWebsite" {
  bucket = aws_s3_bucket.s3Bucket.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}


resource "aws_s3_bucket_cors_configuration" "s3BucketCors" {
  bucket = aws_s3_bucket.s3Bucket.bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET","HEAD","DELETE","PUT", "POST"]
    allowed_origins = ["https://${var.domain}"]
    max_age_seconds = 3000
  }

}


resource "aws_s3_bucket_acl" "example_bucket_acl" {
  bucket = aws_s3_bucket.s3Bucket.bucket
  acl    = "public"
}






















output "s3BucketWebsiteEndpoint" {
  value = aws_s3_bucket_website_configuration.s3BucketWebsite.website_endpoint
}