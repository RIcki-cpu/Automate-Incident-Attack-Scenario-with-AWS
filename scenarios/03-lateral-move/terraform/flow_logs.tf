# --- VPC Flow Logs: the detection side of this scenario --------------------
# This scenario's attack is a NETWORK event (an SSH connection from the web
# host to the internal host), so the right telescope is VPC Flow Logs, not
# CloudTrail. Flow Logs record metadata about every network flow on the
# VPC's interfaces (source/dest IP, port, protocol, ACCEPT/REJECT) — they
# do NOT see packet contents, but they see exactly the thing we care about:
# "host A opened a connection to host B on port 22."
#
# Flow Logs are delivered to CloudWatch Logs here, so the detection step
# can query them with CloudWatch Logs Insights (a SQL-ish query language) —
# the standard tool for this, and a deliberate contrast with scenarios 1
# and 2, which parsed CloudTrail JSON from S3 with jq.

resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/vpc/${var.scenario_name}"
  retention_in_days = 1 # lab-short; we only need it for the exercise window

  tags = {
    Name = "${var.scenario_name}-flow-logs"
  }
}

# Flow Logs can't write to CloudWatch Logs on their own — they assume this
# IAM role to do it. The trust policy lets ONLY the VPC Flow Logs service
# assume it (name stays within the lateral-move-* prefix the deploy policy
# allows).
resource "aws_iam_role" "flow_logs" {
  name = "${var.scenario_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# The permissions the Flow Logs service needs to create log streams and
# write records into the log group above. This is standard, documented
# boilerplate for CloudWatch-Logs-delivered Flow Logs.
resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.scenario_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}

# The Flow Log itself: capture ALL traffic (accepted and rejected) across
# the whole VPC, delivered to the log group via the role above.
resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  # For a cloud-watch-logs destination, `log_destination` must be the log
  # group's ARN (not its name) — using .name here fails at apply.
  log_destination          = aws_cloudwatch_log_group.flow.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn
  max_aggregation_interval = 60 # smallest window (1 min) so the attack shows up fast

  tags = {
    Name = "${var.scenario_name}-vpc-flow-log"
  }
}
