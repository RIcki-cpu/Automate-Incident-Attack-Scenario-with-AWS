# --- CloudTrail: the detection side of this scenario -----------------------
# CloudTrail records API calls made against your AWS account. By default
# it only logs "management events" (e.g. CreateBucket, RunInstances) — it
# will NOT log someone reading an object out of S3 unless "data events"
# are turned on for that bucket specifically, which the event_selector
# block below does. Data events are what let us actually see the
# anonymous GetObject/ListBucket calls this scenario's attack step makes.
#
# CloudTrail can only deliver logs to an S3 bucket you own, so most of
# this file (everything except aws_cloudtrail.this at the bottom) is just
# building that destination bucket and granting the CloudTrail service
# permission to write into it.

resource "aws_s3_bucket" "trail_logs" {
  bucket        = "${var.scenario_name}-trail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${var.scenario_name}-trail-logs"
  }
}

# Unlike the data bucket in s3.tf, this bucket holds real log data about
# your account and should never be public — Block Public Access stays
# fully ON here.
resource "aws_s3_bucket_public_access_block" "trail_logs" {
  bucket                  = aws_s3_bucket.trail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Boilerplate AWS requires for any CloudTrail logging bucket: it lets the
# CloudTrail SERVICE (not a person) check the bucket's ACL and then write
# log files under a specific path (AWSLogs/<your-account-id>/...). This
# exact shape mirrors AWS's own documented CloudTrail bucket policy —
# it's not something you'd typically hand-design from scratch.
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

    # Without this condition, CloudTrail would still work, but you (the
    # bucket owner) might not automatically get full control over the log
    # files it writes. This guarantees you always do.
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

# The trail itself.
#   is_multi_region_trail = false -> only logs activity in var.aws_region,
#     which is all this single-region scenario needs (keeps cost/
#     complexity down).
#   include_global_service_events = true -> still capture account-wide
#     services like IAM even though this trail is single-region, since
#     IAM/STS calls matter for scenario 02 later.
#   event_selector -> "All" read_write_type + include_management_events
#     covers normal API activity; the nested data_resource block is what
#     specifically turns on S3 object-level logging, scoped to just the
#     data bucket (not every bucket in the account) to keep log volume
#     small on purpose.
resource "aws_cloudtrail" "this" {
  name                          = "${var.scenario_name}-trail"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.data.arn}/"] # trailing "/" = all objects in this bucket
    }
  }

  # The trail can't be created until the log bucket is actually willing
  # to accept CloudTrail's writes. s3_bucket_name above only references
  # the bucket itself, not its policy, so Terraform wouldn't otherwise
  # know to wait for aws_s3_bucket_policy.trail_logs first — this makes
  # that ordering explicit.
  depends_on = [aws_s3_bucket_policy.trail_logs]

  tags = {
    Name = "${var.scenario_name}-trail"
  }
}
