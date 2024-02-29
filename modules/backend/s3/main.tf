##############################################
# STATE
##############################################

resource "aws_s3_bucket" "terraform_state" {
  # must be a globally-unique bucket name
  bucket = var.remote_state_bucket_name
  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning of the bucket.
# This makes error recovery a lot easier.
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt the contents of the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# buckets are private by default, but best to state it here, also
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.terraform_state.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}


# Dynamo DB key:value store for locking shared access
resource "aws_dynamodb_table" "terraform_locks" {
  name = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_iam_policy" "terraform_backend" {
  name        = var.backend_bucket_policy_name
  description = "Policy for Terraform backend to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.remote_state_bucket_name}"
        Condition = {
          StringLike = {
            "s3:prefix" = ["${var.bucket_key}/*"]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
          // Add "s3:DeleteObject" if you want to allow Terraform to delete objects as well
        ]
        Resource = "arn:aws:s3:::${var.remote_state_bucket_name}/${var.bucket_key}"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "terraform_backend_attach" {
  user       = "terraform"
  policy_arn = aws_iam_policy.terraform_backend.arn
}

resource "aws_iam_policy" "terraform_dynamodb" {
  name        = var.backend_db_policy_name
  description = "Policy for Terraform to access DynamoDB for state locking"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.dynamodb_table_name}"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "terraform_dynamodb_attach" {
  user       = "terraform"
  policy_arn = aws_iam_policy.terraform_dynamodb.arn
}