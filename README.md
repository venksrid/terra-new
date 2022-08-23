# S3 bucket replication configuration.


Terraform Import S3 Bucket

terraform init 

terraform import module.s3_bucket.aws_s3_bucket.this bucket_name

terraform plan
terraform apply


## Enable replication sync

aws s3api put-bucket-replication --bucket <bucket_name> --replication-configuration  file://replication.json



