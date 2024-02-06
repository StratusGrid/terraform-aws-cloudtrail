data "aws_iam_policy_document" "cloudwatch_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      identifiers = [
        "cloudtrail.amazonaws.com",
      ]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "cloudwatch_logs" {
  count              = var.enable_cloudwatch_logs_for_cloudtrail ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role.json
  name               = local.associated_resource_name
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key -- Ignores warning on Log group not encrypted
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudwatch_logs_for_cloudtrail ? 1 : 0
  name              = local.associated_resource_name
  retention_in_days = 7
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "cloudwatch_logs_role" {
  count = var.enable_cloudwatch_logs_for_cloudtrail ? 1 : 0
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*",
    ]
    sid = "AWSCloudTrailLogging"
  }
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  count  = var.enable_cloudwatch_logs_for_cloudtrail ? 1 : 0
  name   = "cloudwatch-logs"
  policy = data.aws_iam_policy_document.cloudwatch_logs_role[0].json
  role   = aws_iam_role.cloudwatch_logs[0].id
}
