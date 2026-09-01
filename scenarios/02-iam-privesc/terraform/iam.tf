# --- The two misconfigurations -------------------------------------------
# Like Scenario 1 (which needed BOTH Block Public Access off AND a public
# bucket policy before the bucket was actually public), this scenario
# needs TWO independent things to go wrong before privilege escalation is
# possible:
#
#   1. The "analyst" user below has a blanket sts:AssumeRole grant on
#      "*" (any role) — the genuinely common real convenience-grant
#      ("let people assume roles, we'll lock down trust policies
#      properly later"). It also has IAM read access, which is what lets
#      an attacker DISCOVER the vulnerable role rather than being handed
#      it.
#   2. The "broad_read" role's TRUST policy trusts this account's :root
#      ARN — which does NOT mean "only the root user." In AWS IAM, a
#      trust-policy Principal of "arn:aws:iam::<account>:root" means "any
#      authenticated principal in this account" (provided that principal
#      also has its own sts:AssumeRole permission — which the analyst
#      user does, from #1). This is one of the most common real IAM
#      findings; most cloud security scanners specifically flag "role
#      trusts account root."
#
# Neither misconfiguration alone is enough. The analyst's permission to
# CALL AssumeRole doesn't matter if broad_read's trust policy doesn't also
# allow it in — and vice versa. Both have to fail for the escalation to
# work, exactly like Scenario 1's two S3 locks.

# --- The starting foothold: a low-privilege user with a real access key --
# This represents "the attacker already has SOME real, low-privilege AWS
# credentials" — e.g. a leaked key for a service account — rather than
# rebuilding an EC2/SSH compromise step (that belongs to Scenario 3,
# lateral movement). No VPC or EC2 instance exists anywhere in this
# scenario: IAM privilege escalation is purely an identity-layer problem,
# so compute/networking resources would add nothing here but cost and
# clutter.
resource "aws_iam_user" "analyst" {
  name = "${var.scenario_name}-analyst"
}

# Terraform-managed access key for the analyst user. The secret is only
# ever available via `terraform output -raw` (see outputs.tf) — it is
# never printed by `terraform apply`/`plan`, never written to a file by
# this configuration, and must never be pasted into a commit or a chat.
resource "aws_iam_access_key" "analyst" {
  user = aws_iam_user.analyst.name
}

# The analyst's real permissions — deliberately shaped like a realistic
# over-permissioned service account, NOT like an identity hand-built to
# be escalated:
#
#   * AssumeAnyRole: sts:AssumeRole on "*". Scoping this to a single
#     scenario role would look artificial (an identity that exists only
#     to escalate). A real over-permissioned user has the blanket grant
#     — it can ATTEMPT to assume any role; whether that succeeds is then
#     decided entirely by each role's trust policy (which is exactly the
#     point of this scenario). This is Misconfiguration #1.
#   * EnumerateIam: read-only IAM enumeration. This is not the escalation
#     itself — it's what makes the attack realistic. It lets the attacker
#     list roles, read their trust policies, and thereby DISCOVER that
#     broad_read trusts the account root, instead of being handed the
#     role's ARN. IAM read access is itself a common over-grant precisely
#     because it enables this kind of reconnaissance.
resource "aws_iam_user_policy" "analyst_permissions" {
  name = "${var.scenario_name}-analyst-permissions"
  user = aws_iam_user.analyst.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeAnyRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "*"
      },
      {
        Sid    = "EnumerateIam"
        Effect = "Allow"
        Action = [
          "iam:ListRoles",
          "iam:GetRole",
          "iam:ListUsers",
        ]
        Resource = "*"
      },
    ]
  })
}

# --- The escalation target -------------------------------------------------
# Misconfiguration #2: the trust policy below. Written by someone who
# meant "let roles in this account assume this," it actually means "let
# ANY authenticated principal in this account assume this" — the analyst
# user included, even though nobody intended to grant it that.
resource "aws_iam_role" "broad_read" {
  name = "${var.scenario_name}-broad-read"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# The "prize": deliberately real (broad S3 read across the WHOLE account,
# not just this scenario's own resources — a genuine escalation from the
# analyst's near-zero starting permissions) but deliberately safe for a
# lab: read-only, nothing destructive, and nowhere near enough to touch
# the real deploy user (IaC_user) or its policy — a completely separate
# identity protected by its own explicit Deny (see
# iam/iac-user-policy.json). iam:ListUsers/ListRoles don't support
# resource-level scoping in AWS (list actions are account-wide by nature),
# so Resource "*" is expected here, not a laxness.
resource "aws_iam_role_policy" "broad_read_perms" {
  name = "${var.scenario_name}-broad-read-perms"
  role = aws_iam_role.broad_read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListAllMyBuckets",
        "iam:ListUsers",
        "iam:ListRoles",
      ]
      Resource = "*"
    }]
  })
}
