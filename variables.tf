variable "region" {
  default = "eu-north-1" #enter your aws region
}

variable "cluster_name" {
  default = "my-5EKS-cluster"
}

variable "availability_zones" {
  type = list(string)
  default = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

variable "private_subnets_cidrs" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets_cidrs" {
  type = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}
