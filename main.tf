provider "aws" {
  region = local.origin_region

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

provider "aws" {
  region = local.replica_region

  alias = "replica"

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

resource "aws_iam_role" "this" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid = "statement1"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this.arn]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${local.bucket_name}/*",
    ]
    condition {
      test = "StringEquals"
      values = [
        "STANDARD_IA",
      ]
      variable = "s3:x-amz-storage-class"
    }
  }

  statement {
    sid    = "Stmt1618417100081"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:DeleteBucket",
    ]
    resources = [
      "arn:aws:s3:::${local.bucket_name}",
    ]
  }
}

data "aws_iam_policy_document" "bucket_policy_dest" {
  statement {
    sid = "statement1"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this.arn]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${local.destination_bucket_name}/*",
    ]
    condition {
      test = "StringEquals"
      values = [
        "STANDARD_IA",
      ]
      variable = "s3:x-amz-storage-class"
    }

  }

  statement {
    sid    = "Stmt1618417100081"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:DeleteBucket",
    ]
    resources = [
      "arn:aws:s3:::${local.destination_bucket_name}",
    ]
  }
}

resource "random_pet" "this" {
  length = 2
}


data "aws_iam_policy_document" "kms" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this.arn]
    }

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${local.bucket_name}",
    ]
  }
}

resource "aws_kms_key" "replica" {
 provider = aws.replica

 description             = "S3 bucket replication KMS key"
 deletion_window_in_days = 30
}


module "replica_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.3.0"

  providers = {
    aws = aws.replica
  }

  bucket = local.destination_bucket_name
  acl    = "aws-exec-read"

  # Bucket policies
  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.bucket_policy_dest.json
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.3.0"

  bucket = local.bucket_name

  acl = "aws-exec-read" #private public-read public-read-write authenticated-read aws-exec-read log-delivery-write
  # object_ownership = "BucketOwnerFullControl" # BucketOwnerFullControl BucketOwnerRead BucketOwnerWrite BucketOwnerReadWrite

  # Bucket policies
  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.bucket_policy.json
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  versioning = {
    enabled = true
  }

  replication_configuration = {
    role = aws_iam_role.replication.arn

    rules = [
      {
        id       = "Enable-replication-Dest"
        status   = true
        priority = 10

        delete_marker_replication = true
        # existing_object_replication = "Enabled"

        destination = {
          bucket        = "arn:aws:s3:::${local.destination_bucket_name}"
          storage_class = "STANDARD_IA"

          # replica_kms_key_id = aws_kms_key.replica.arn
          account_id = data.aws_caller_identity.current.account_id

          access_control_translation = {
            owner = "Destination"
          }

          replication_time = {
            status  = "Enabled"
            minutes = 15
          }

          metrics = {
            status  = "Enabled"
            minutes = 15
          }

          source_selection_criteria = {
            replica_modifications = {
              status = "Enabled"
            }
            sse_kms_encrypted_objects = {
              enabled = false
            }
          }

          # filter = {
          #   prefix = "*"
          #   tags = {
          #     ReplicateMe = "Yes"
          #   }
          # }
        }
      },
    ]

  }
  depends_on = [module.replica_bucket]
}

#data "template_file" "replication_dest" {
#  template = "${file("replication.json")}"
#  vars = {
#    bucketarn = "${module.replica_bucket.s3_bucket_arn}"
#    rolearn = "${aws_iam_role.replication.arn}"
#  }
#}

#resource "null_resource" "awsdestrepl" {
#  provisioner "local-exec" {
#    command = "aws s3api put-bucket-replication --bucket ${local.bucket_name} --replication-configuration ${data.template_file.replication_dest.rendered}"
#  }
#  depends_on = [module.replica_bucket]

#}
