variable "environment" {
    type = string
}

variable "component_version" {
    type = string
}

variable "aws_region" {
    type    = string
    default = "us-west-2"
}

variable "vpc_id" {
    type    = string
    default = "vpc-f433478c"
}

variable "aws_account" {
    type = string
}

variable "image_tag" {
    type = string
}   
