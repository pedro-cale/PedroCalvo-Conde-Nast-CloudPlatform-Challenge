terraform {
    backend "s3" {
        bucket         = "cn-challenge-tfstates"
        dynamodb_table = "cn-challenge-tflocks"
        region         = "us-west-2"
    }
}