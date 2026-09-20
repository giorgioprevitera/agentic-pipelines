variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "agentic-devops"
}

variable "container_port" {
  type    = number
  default = 8080
}
