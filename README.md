# terraform-riskmodelv3
Terraform project to build and deploy an AWS stack

## About
This Terraform project builds and deploys the following AWS resources: 
* IAM policies and roles
* VPC (inc. tags)
* VPC subnet (inc. tags)
* VPC security groups 
* Creates a Lambda function from a Python template file
* Creates an S3 event to trigger the above Lambda function when a specific file is created

## Why? 
When a specific file is added to an S3 bucket trigger a Lambda function to launch a new EC2 instance. This EC2 instance is pre-configured with a cloud-init script to install packages, pull files from the bucket, checks out a Git repo and executes a file. 
