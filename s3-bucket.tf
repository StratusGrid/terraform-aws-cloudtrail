resource "aws_s3_bucket" "cloudtrail" {
  acl    = "log-delivery-write"
  bucket = local.associated_resource_name

  versioning {
    mfa_delete = var.enable_mfa_delete_cloudtrail_bucket
  }

  tags = merge(local.common_tags, {})
}

resource "aws_s3_bucket_acl" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_logging" "cloudtrail" {
  bucket        = aws_s3_bucket.cloudtrail.id
  target_bucket = var.log_bucket
  target_prefix = "s3/${local.associated_resource_name}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.bucket
  rule {
    id = "log"

    expiration {
      days = var.expiration
    }

    status = "Enabled"

    transition {
      days          = var.transition_to_glacier
      storage_class = "GLACIER"
    }
  }
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
