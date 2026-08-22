# --- The vulnerable bucket -------------------------------------------------
# This bucket is the scenario's actual misconfiguration. The EC2 app in
# ec2.tf has its own tightly-scoped IAM role — the app is not the
# vulnerability. This bucket policy is. Two things both have to be true
# for an S3 bucket to end up genuinely public, and this file does both on
# purpose:
#   1. Block Public Access must be OFF (aws_s3_bucket_public_access_block
#      below) — since ~2023 AWS defaults this to ON for every new bucket,
#      specifically to prevent this exact scenario from happening by
#      accident.
#   2. A bucket policy (or ACL) must actually GRANT access to the public
#      (aws_s3_bucket_policy.data_public_read below).
# In a real incident, step 1 usually happens first and innocently (someone
# disables BPA to unblock an unrelated policy change) and step 2 follows
# later — by then nothing stops it.

resource "aws_s3_bucket" "data" {
  bucket        = "${var.scenario_name}-data-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # lets `terraform destroy` delete this bucket even
  # though it still holds an object (the decoy file below) — without
  # this, destroy would fail on a non-empty bucket.

  tags = {
    Name = "${var.scenario_name}-data-bucket"
    Note = "INTENTIONALLY MISCONFIGURED - lab use only, decoy data only"
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# An aws_iam_policy_document data source just renders a JSON IAM policy
# from HCL — it doesn't touch AWS by itself, it only produces the text
# used below. The `principals { type = "AWS", identifiers = ["*"] }`
# block is the actual "make it public" part: it means "any AWS principal,
# including a completely unauthenticated request."
data "aws_iam_policy_document" "public_read" {
  statement {
    sid     = "PublicReadGetObject"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.data.arn,
      "${aws_s3_bucket.data.arn}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

# This is what actually attaches the public-read policy rendered above to
# the bucket. `depends_on` forces Terraform to disable Block Public Access
# FIRST — without it, Terraform might try to attach this policy before
# BPA is off, and AWS would reject the attachment.
resource "aws_s3_bucket_policy" "data_public_read" {
  bucket = aws_s3_bucket.data.id
  policy = data.aws_iam_policy_document.public_read.json

  depends_on = [aws_s3_bucket_public_access_block.data]
}

# The thing an attacker "exfiltrates" in this scenario. Fake data only —
# never replace this with anything real, since the bucket is intentionally
# public for as long as this scenario stays deployed.
resource "aws_s3_object" "decoy_sensitive_file" {
  bucket       = aws_s3_bucket.data.id
  key          = "customer_exports/customers_2026.csv"
  content      = "id,name,email\n1,Ada Lovelace,ada@example.com\n2,Alan Turing,alan@example.com\n"
  content_type = "text/csv"
}
