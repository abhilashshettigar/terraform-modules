resource "aws_s3_bucket" "env" {
  bucket = "${var.name}-env"
}
