# Upload bootstrap runner script to S3
resource "aws_s3_object" "bootstrap" {
  bucket       = var.bucket_name
  key          = "bootstrap.sh"
  source       = "${path.module}/../../bootstrap/bootstrap.sh"
  etag         = filemd5("${path.module}/../../bootstrap/bootstrap.sh")
  content_type = "text/x-shellscript"
}

# Upload scripts to S3
resource "aws_s3_object" "scripts" {
  for_each = fileset("${path.module}/../../bootstrap/scripts", "**/*")

  bucket = var.bucket_name
  key    = "scripts/${each.value}"
  source = "${path.module}/../../bootstrap/scripts/${each.value}"
  etag   = filemd5("${path.module}/../../bootstrap/scripts/${each.value}")

  content_type = endswith(each.value, ".sh") ? "text/x-shellscript" : "application/octet-stream"
}

# Upload ansible files to S3
resource "aws_s3_object" "ansible" {
  for_each = fileset("${path.module}/../../bootstrap/ansible", "**/*")

  bucket = var.bucket_name
  key    = "ansible/${each.value}"
  source = "${path.module}/../../bootstrap/ansible/${each.value}"
  etag   = filemd5("${path.module}/../../bootstrap/ansible/${each.value}")

  content_type = endswith(each.value, ".yml") ? "text/yaml" : (
    endswith(each.value, ".ini") ? "text/plain" : "application/octet-stream"
  )
}
