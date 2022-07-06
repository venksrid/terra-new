locals {
  bucket_name             = "testbucket-987"  # "origin-s3-bucket-${random_pet.this.id}"
  destination_bucket_name = "replica-${local.bucket_name}-${random_pet.this.id}"
  origin_region           = "us-east-1"
  replica_region          = "us-west-2"

  s3 = {
    
  }
}
