# DEFINE DEFAULT VARIABLES HERE

# ============================================================
# VARIABLES
# ============================================================

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
}

variable "ami" {
  description = "Ubuntu AMI ID"
  type        = string
}

variable "key_name" {
  description = "AWS EC2 Key Pair Name"
  type        = string
}

variable "volume_size" {
  description = "Root EBS Volume Size in GB"
  type        = number
}

variable "region_name" {
  description = "AWS Region"
  type        = string
}

variable "server_name" {
  description = "EC2 Server Name"
  type        = string
}
