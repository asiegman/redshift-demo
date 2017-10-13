provider "aws" {
  region = "us-east-1"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

variable "ChargeCode" {
  type = "string"
  description = "Billing Charge Code"
  default = "dev"
}

resource "aws_cloudformation_stack" "redshift" {
  name = "dev-redshift"

  parameters = {
    ClusterName = "devredshift"
    ChargeCode = "${var.ChargeCode}"
    ClusterType = "multi-node"
    NumberOfNodes = 2
    NodeType = "ds2.xlarge"
    MasterUserPassword = "TotallyInsecurePassword123"
  }

  template_body = "${file("${path.module}/../cf-redshift.yaml")}"
  timeout_in_minutes = 30
  capabilities = ["CAPABILITY_NAMED_IAM"]
  on_failure = "DO_NOTHING"

  tags {
    ChargeCode = "${var.ChargeCode}"
  }
}
