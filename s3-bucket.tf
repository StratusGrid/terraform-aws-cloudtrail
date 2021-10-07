resource "aws_s3_bucket" "cloudtrail" {
  acl    = "log-delivery-write"
  bucket = local.associated_resource_name

  lifecycle_rule {
    id      = "log"
    enabled = true

    transition {
      days          = var.transition_to_glacier
      storage_class = "GLACIER"
    }

    expiration {
      days = var.expiration
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  logging {
    target_bucket = var.log_bucket
    target_prefix = "s3/${local.associated_resource_name}/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.cloudtrail.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = merge(var.input_tags, {})
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "cloudtrail_s3" {
  statement {
    actions = [
      "s3:GetBucketAcl",
    ]
    principals {
      identifiers = [
        "cloudtrail.amazonaws.com",
      ]
      type = "Service"
    }
    resources = [
      aws_s3_bucket.cloudtrail.arn,
    ]
    sid = "CloudTrail Acl Check"
  }

  statement {
    actions = [
      "s3:PutObject",
    ]
    condition {
      test = "StringEquals"
      values = [
        "bucket-owner-full-control",
      ]
      variable = "s3:x-amz-acl"
    }
    principals {
      identifiers = [
        "cloudtrail.amazonaws.com",
      ]
      type = "Service"
    }
    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/*",
    ]
    sid = "CloudTrail Write"
  }

  statement {
    actions = [
      "s3:*",
    ]
    condition {
      test = "Bool"
      values = [
        "false",
      ]
      variable = "aws:SecureTransport"
    }
    effect = "Deny"
    principals {
      identifiers = [
        "*",
      ]
      type = "AWS"
    }
    resources = [
      aws_s3_bucket.cloudtrail.arn,
      "${aws_s3_bucket.cloudtrail.arn}/*",
    ]
    sid = "DenyUnsecuredTransport"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_s3.json
}

