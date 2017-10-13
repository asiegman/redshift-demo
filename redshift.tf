# This is a straight port of the cloudformation yaml, to show it can be
# done in both terraform and cloudformation.
#
# I've made

provider "aws" {
  region = "us-east-1"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

variable "ClusterName" {
  type = "string"
  description = "A name for uniquely identified resources (S3, Redshift, etc)"
  default = "fox"
}

variable "ChargeCode" {
  type = "string"
  description = "Charge Code tag to apply to resources for billing purposes"
  default = "dev"
}

variable "DatabaseName" {
  type = "string"
  description = "The name of the first database to be created when the cluster is created"
  default = "dev"
}

variable "ClusterType" {
  type = "string"
  description = "The type of cluster: [single-node|multi-node]"
  default = "single-node"
}

variable "NumberOfNodes" {
  type = "string"
  description = "The number of nodes.  Should be 1 for a single-node cluster, and greater than 1 for a multi-node cluster."
  default = "1"
}

variable "NodeType" {
  type = "string"
  description = "Node type to be provisioned: [ds2.xlarge|ds2.8xlarge|dc1.large|dc1.8xlarge]"
  default = "ds2.xlarge"
}

variable "MasterUsername" {
  type = "string"
  description = "The master user account for the redshift cluster"
  default = "defaultuser"
}

variable "MasterUserPassword" {
  type = "string"
  description = "The password for the master user account on the redshift cluster"
}

variable "InboundTraffic" {
  type = "string"
  description = "Allow inbound traffic to the cluster from this CIDR range"
  default = "0.0.0.0/0"
}

variable "PortNumber" {
  type = "string"
  description = "tcp port the redshift cluster will listen on"
  default = "5439"
}



#Resources:

resource "aws_s3_bucket" "RedshiftS3Bucket" {
  bucket = "${var.ClusterName}-cluster-bucket"
  acl = "private"

  tags {
    ChargeCode = "${var.ChargeCode}"
  }
}

resource "aws_iam_role" "RedshiftIAMRole" {
  name = "${var.ClusterName}RedshiftRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "RedshiftIAMPolicyDocument" {
  statement {
    actions = [
      "s3:*",
    ]

    resources = [
      "${aws_s3_bucket.RedshiftS3Bucket.arn}",
      "${aws_s3_bucket.RedshiftS3Bucket.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "RedshiftIAMPolicy" {
  name = "${var.ClusterName}RedshiftPolicy"
  path = "/"
  policy = "${data.aws_iam_policy_document.RedshiftIAMPolicyDocument.json}"
}

resource "aws_iam_role_policy_attachment" "RedshiftPolicyAttachment" {
    role       = "${aws_iam_role.RedshiftIAMRole.name}"
    policy_arn = "${aws_iam_policy.RedshiftIAMPolicy.arn}"
}

resource "aws_redshift_cluster" "RedshiftCluster" {
  cluster_identifier = "${lower(var.ClusterName)}"
  database_name = "${var.DatabaseName}"
  master_username = "${var.MasterUsername}"
  master_password = "${var.MasterUserPassword}"
  node_type = "${var.NodeType}"
  number_of_nodes = "${var.ClusterType == "multi-node" ? var.NumberOfNodes : 1}"
  cluster_type = "${var.ClusterType}"
  port = "${var.PortNumber}"
  publicly_accessible = true
  depends_on = ["aws_internet_gateway.gw"]
  cluster_parameter_group_name = "${aws_redshift_parameter_group.RedshiftClusterParameterGroup.id}"
  cluster_subnet_group_name = "${aws_redshift_subnet_group.RedshiftSubnetGroup.id}"

  vpc_security_group_ids = [
    "${aws_security_group.redshift_in.id}"
  ]

  iam_roles = [
    "${aws_iam_role.RedshiftIAMRole.arn}",
  ]

  tags {
    ChargeCode = "${var.ChargeCode}"
  }
}

resource "aws_redshift_parameter_group" "RedshiftClusterParameterGroup" {
  name   = "${var.ClusterName}-cluster-parameter-group"
  family = "redshift-1.0"

  parameter {
    name  = "enable_user_activity_logging"
    value = "true"
  }
}

resource "aws_redshift_subnet_group" "RedshiftSubnetGroup" {
  name       = "${var.ClusterName}-redshift-subnet-group"
  subnet_ids = ["${aws_subnet.PublicSubnet.id}", ]

  tags {
    ChargeCode = "${var.ChargeCode}"
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags {
    ChargeCode = "${var.ChargeCode}"
  }
}

resource "aws_subnet" "PublicSubnet" {
  cidr_block = "10.0.0.0/24"
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.ClusterName}-public-net-1"
    ChargeCode = "${var.ChargeCode}"
  }
}

resource "aws_security_group" "redshift_in" {
  name        = "redshift_in"
  description = "Allow inbound traffic to redshift port"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = "${var.PortNumber}"
    to_port     = "${var.PortNumber}"
    protocol    = "tcp"
    cidr_blocks = ["${var.InboundTraffic}"]
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    ChargeCode = "${var.ChargeCode}"
  }
}


  # AttachGateway:
  #   Type: AWS::EC2::VPCGatewayAttachment
  #   Properties:
  #     VpcId: !Ref VPC
  #     InternetGatewayId: !Ref myInternetGateway

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "main"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id = "${aws_subnet.PublicSubnet.id}"
  route_table_id = "${aws_route_table.r.id}"
}

#####

output "ClusterEndpoint" {
  value = "${aws_redshift_cluster.RedshiftCluster.endpoint}"
}

output "S3BucketARN" {
  value = "${aws_s3_bucket.RedshiftS3Bucket.arn}"
}

# You'll need the ARN of the IAM Role for loading data to/from S3
output  "RedshiftIAMRoleARN" {
  value = "${aws_iam_role.RedshiftIAMRole.arn}"
}

