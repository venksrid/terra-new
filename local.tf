locals {
  bucket_name             = "testbucket0011100"
  destination_bucket_name = "${local.bucket_name}-replica"
  origin_region           = "us-east-1"
  replica_region          = "us-west-2"

  s3 = {

  }
}
