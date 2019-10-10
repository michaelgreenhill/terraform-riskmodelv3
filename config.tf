provider "aws" {
  profile = "default"
  region  = "ap-southeast-2"
}

variable "ec2_ip" {
  type    = string
  default = "10.0.0.36"
}

variable "ec2_instance_type" {
  type    = string
  default = "r5.2xlarge"
}

variable "ebs_vol_size" {
  type    = number
  default = 256
}

variable "lambda_template" {
  type    = string
  default = "AWS/Lambda/lambda_function.py"
}

variable "lambda_archive" {
  type    = string
  default = "AWS/lambda_function.zip"
}

variable "lambda_function_name" {
  type    = string
  default = "DeployRiskModelV3AlphaBuilder"
}

variable "s3_bucket" {
  type    = "string"
  default = "my-test-bucket"
}

data "aws_ami" "debian_stretch" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-stretch-hvm-x86_64-gp2-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["379101102735"] # debian
}

resource "aws_vpc" "mim-vpc2" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name    = "mim-vpc2 (Risk Model v3)"
    billing = "riskmodel-v3"
  }
}

resource "aws_subnet" "mim-vlan1600-2" {
  cidr_block = "10.0.0.32/27"
  vpc_id     = "${aws_vpc.mim-vpc2.id}"

  tags = {
    Name    = "mim-vlan1600-2"
    billing = "riskmodel-v3"
  }
}

resource "aws_iam_policy" "ECR-RiskModel-ReadOnly" {
  name        = "ECR-RiskModel-ReadOnly"
  path        = "/"
  description = "Grants access to EC2 Container Registry"

  policy = "${file("AWS/IAM/Policy-ECR-RiskModel-ReadOnly.json")}"
}

resource "aws_iam_policy" "CloudWatchLogs-Create" {
  name        = "CloudWatchLogs-Create"
  path        = "/"
  description = "Policy used by EC2 instances to create CloudWatch Logs groups"

  policy = "${file("AWS/IAM/Policy-CloudWatchLogs-Create.json")}"
}

resource "aws_iam_policy" "Athena-RiskModelv3-ReadExecute" {
  name        = "Athena-RiskModelv3-ReadExecute"
  path        = "/"
  description = "Grants access to Athena"
  policy      = "${file("AWS/IAM/Policy-Athena-RiskModelv3-ReadExecute.json")}"
}

resource "aws_iam_policy" "S3-RiskModelV3-ReadWrite" {
  name        = "S3-RiskModelV3-ReadWrite"
  path        = "/"
  description = "Read and write permissions for the my-test-bucket bucket, limited to objects in the v3 prefix only. "
  policy      = "${file("AWS/IAM/Policy-S3-RiskModelV3-ReadWrite.json")}"
}

resource "aws_iam_policy" "Lambda-RiskModelV3" {
  name        = "Lambda-RiskModelV3"
  path        = "/"
  description = "Permissions delegated to Lambda to launch an EC2 instance"
  policy      = "${file("AWS/IAM/Policy-Lambda-RiskModelV3.json")}"
}

resource "aws_iam_role" "RiskModelv3-EC2" {
  name               = "RiskModelv3-EC2"
  assume_role_policy = "${file("AWS/IAM/Role-RiskModelv3-EC2.json")}"
}

resource "aws_iam_role" "RiskModelv3-Lambda" {
  name               = "RiskModelv3-Lambda"
  assume_role_policy = "${file("AWS/IAM/Role-RiskModelv3-Lambda.json")}"
}

resource "aws_iam_role_policy_attachment" "attach-pol-1" {
  role       = "${aws_iam_role.RiskModelv3-EC2.name}"
  policy_arn = "${aws_iam_policy.ECR-RiskModel-ReadOnly.arn}"
}

resource "aws_iam_role_policy_attachment" "attach-pol-2" {
  role       = "${aws_iam_role.RiskModelv3-EC2.name}"
  policy_arn = "${aws_iam_policy.CloudWatchLogs-Create.arn}"
}

resource "aws_iam_role_policy_attachment" "attach-pol-3" {
  role       = "${aws_iam_role.RiskModelv3-EC2.name}"
  policy_arn = "${aws_iam_policy.Athena-RiskModelv3-ReadExecute.arn}"
}

resource "aws_iam_role_policy_attachment" "attach-pol-4" {
  role       = "${aws_iam_role.RiskModelv3-EC2.name}"
  policy_arn = "${aws_iam_policy.S3-RiskModelV3-ReadWrite.arn}"
}

resource "aws_iam_role_policy_attachment" "attach-pol-5" {
  role       = "${aws_iam_role.RiskModelv3-Lambda.name}"
  policy_arn = "${aws_iam_policy.Lambda-RiskModelV3.arn}"
}

resource "aws_security_group" "mim-riskmodel-v3-alpha-builder" {
  name        = "mim-riskmodel-v3-alpha-builder"
  description = "Security group for mim-riskmodel-v3-alpha-builder"
  vpc_id      = "${aws_vpc.mim-vpc2.id}"

  tags = {
    Name    = "mim-riskmodel-v3-alpha-builder"
    billing = "riskmodel-v3"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "192.168.1.0/24", "192.168.10.0/24"]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5140
    to_port     = 5140
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5140
    to_port     = 5140
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "michael.greenhill"
  public_key = "ssh-rsa my super secret public key michael.greenhill @ aws"
}

# Take the Python template and populate placeholders with real values
data "template_file" "riskmodel-v3-alpha-lambda-template" {
  template = "${file("AWS/Lambda/lambda_function.tpl")}"
  vars = {
    ami              = "${data.aws_ami.debian_stretch.id}"
    ec2_ip           = var.ec2_ip
    ec2_type         = var.ec2_instance_type
    ebs_size         = var.ebs_vol_size
    sg               = "${aws_security_group.mim-riskmodel-v3-alpha-builder.id}"
    subnet           = "${aws_subnet.mim-vlan1600-2.id}"
    cloud-init       = "${file("AWS/cloud-init.sh")}"
    role             = "${aws_iam_role.RiskModelv3-EC2.name}"
    key_name         = "${aws_key_pair.deployer.key_name}"
    root_device_name = "${data.aws_ami.debian_stretch.root_device_name}"
  }
}

# Output the rendered template to file
resource "local_file" "rendered_output" {
  content  = "${data.template_file.riskmodel-v3-alpha-lambda-template.rendered}"
  filename = "${path.module}/${var.lambda_template}"

  # Ensure this processes after the template string has been generated
  depends_on = [
    data.template_file.riskmodel-v3-alpha-lambda-template
  ]
}

# Create a ZIP file of the Python Lambda function
data "archive_file" "lambda_archive" {
  type        = "zip"
  source_file = "${path.module}/${var.lambda_template}"
  output_path = "${path.module}/${var.lambda_archive}"

  # Ensure this processes after the template file has been written to disk
  depends_on = [
    local_file.rendered_output
  ]
}

# Yeet the Lambda function up to AWS
resource "aws_lambda_function" "deploy_mim-riskmodel-v3-alpha-builder" {
  filename         = "${path.module}/${var.lambda_archive}"
  function_name    = "${var.lambda_function_name}"
  role             = "${aws_iam_role.RiskModelv3-Lambda.arn}"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = "${filebase64sha256("${path.module}/${var.lambda_archive}")}"

  runtime = "python3.7"

  # Ensure this processes after the updated Lambda archive has been creawted
  depends_on = [
    data.archive_file.lambda_archive
  ]
}

# Set the S3 event to trigger the Lambda function
resource "aws_s3_bucket_notification" "InitRiskModelV3AlphaBuilder" {
  bucket = var.s3_bucket
  lambda_function {
    lambda_function_arn = "${aws_lambda_function.deploy_mim-riskmodel-v3-alpha-builder.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "v3/alpha/parquet"
    filter_suffix       = "export_complete.txt"
  }
}

data "aws_ecs_cluster" "mim-risk-model-v3-alpha-fargate" {
  cluster_name = "mim-risk-model-v3-alpha"
}

data "aws_ecs_cluster" "mim-risk-model-v3-alpha-ec2" {
  cluster_name = "mim-risk-model-v3-alpha-ec2"
}

data "aws_ecs_task_definition" "risk-model-v3-worker-alpha-fargate" {
  task_definition = "risk-model-v3-worker-alpha"
}

data "aws_ecs_task_definition" "risk-model-v3-worker-alpha-ec2" {
  task_definition = "risk-model-v3-worker-alpha-ec2"
}
