## Use this code to store TF state in GCS bucket
## repalce bucket with the GCS bucket name you created
## unblcok this code when at step 5.2
/*
terraform {
  backend "gcs" {
    bucket = "YOUR_BUCKET_NAME"
    prefix = "terraform/state"
  }
}
*/