variable "name" { type = string }
variable "cluster_arn" { type = string }
variable "cluster_name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "target_group_arn" { type = string }
variable "container_image" { type = string }
variable "container_port" { type = number }
variable "cpu" { type = number }
variable "memory" { type = number }
variable "asg_min_capacity" { type = number }
variable "asg_max_capacity" { type = number }
variable "asg_cpu_target" { type = number }
variable "tags" {
	type    = map(string)
	default = {}
}
