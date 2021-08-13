# //////////////////////////////
# VARIABLES
# //////////////////////////////
variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "ssh_key_name" {}

variable "region" {
  default = "us-east-1"
}

# //////////////////////////////
# PROVIDERS
# //////////////////////////////
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

# # SECURITY_GROUP
resource "aws_security_group" "sg-instance" {
  name = "sg"
  vpc_id = "vpc-58892322"

  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# //////////////////////////////
# DATA
# //////////////////////////////
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# RDS
resource "aws_db_instance" "default" {
  allocated_storage                   = 10
  engine                              = "postgres"
  engine_version                      = "9.6.22"
  instance_class                      = "db.t3.micro"
  name                                = "mydb"
  username                            = "foo"
  password                            = "foobarbaz"
  skip_final_snapshot                 = true
  apply_immediately                   = true
  publicly_accessible                 = true
  iam_database_authentication_enabled = true
  vpc_security_group_ids              = [aws_security_group.sg-instance.id]
}

resource "aws_iam_policy" "policy" {
  name        = "test_policy"
  path        = "/"
  description = "My test policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({ 
    "Version": "2012-10-17", 
    "Statement": [ 
      { 
        "Effect": "Allow", 
        "Action": [ 
          "rds-db:connect" 
        ], 
        "Resource": [
          "arn:aws:rds-db:us-east-1:638648895128:dbuser:db-5VGFFRB5RPJJY2MIKHIMXRWOII/foo" 
        ] 
      } 
    ] 
  })
}

resource "aws_iam_role" "example" {
    assume_role_policy    = jsonencode(
        {
            Statement = [
                {
                    Action    = "sts:AssumeRole"
                    Effect    = "Allow"
                    Principal = {
                        Service = "ec2.amazonaws.com"
                    }
                },
            ]
            Version   = "2012-10-17"
        }
    )
    description           = "Allows EC2 instances to call AWS services on your behalf."
    force_detach_policies = false
    managed_policy_arns   = [
        aws_iam_policy.policy.arn,
    ]
    max_session_duration  = 3600
    name                  = "test_role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

    inline_policy {}
}

resource "aws_iam_instance_profile" "xxx_instance_profile" {
  name  = "xxx_instance_profile"
  role = aws_iam_role.example.name
}

resource "aws_instance" "bastion-instance" {
  ami                     = data.aws_ami.aws-linux.id
  instance_type           = "t2.micro"
  # subnet_id               = aws_subnet.subnet1.id
  vpc_security_group_ids  = [aws_security_group.sg-instance.id]
  key_name                = var.ssh_key_name
  iam_instance_profile    = aws_iam_instance_profile.xxx_instance_profile.name
}

output "address" {
  value = aws_db_instance.default.endpoint
}