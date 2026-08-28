# --- CloudTrail: the detection side of this scenario -----------------------
# Unlike Scenario 1, this trail needs NO extra event_selector block.
# sts:AssumeRole is a "management event" (a control-plane API call), and
# management events are captured by include_management_events = true
# automatically — no special activation step. That's a real contrast with
# Scenario 1: S3 object reads are "data events," which are OFF by default
# and had to be turned on explicitly for that scenario's bucket. Whether
# you need a data-event selector at all depends entirely on which AWS
# service/action you're trying to observe.

resource "aws_s3_bucket" "trail_logs" {
  bucket        = "${var.scenario_name}-trail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${var.scenario_name}-trail-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "trail_logs" {
  bucket                  = aws_s3_bucket.trail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Same boilerplate CloudTrail-bucket-policy shape as Scenario 1 — see that
# scenario's cloudtrail.tf for the line-by-line explanation of each
# statement (AWS requires the trail's log bucket to explicitly trust the
# CloudTrail service to check its ACL and write logs under a specific
# path); not repeated in full detail here to avoid duplicating the same
# commentary twice in the repo.
data "aws_iam_policy_document" "trail_logs_policy" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail_logs.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id
  policy = data.aws_iam_policy_document.trail_logs_policy.json
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.scenario_name}-trail"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  include_global_service_events = true # IAM/STS are global services
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  # No event_selector block needed — the default (all management events,
  # no data events) already captures sts:AssumeRole. See the file header.

  depends_on = [aws_s3_bucket_policy.trail_logs]

  tags = {
    Name = "${var.scenario_name}-trail"
  }
}
