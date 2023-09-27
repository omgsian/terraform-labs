# Configure the server ports
variable "server_ports" {
  description = "numbers of ports"
  type = list(object({
    name = string
    port = number
  }))
  default = [
    { name = "ssh", port = 22 },
    { name = "http", port = 80 },
    { name = "https", port = 443 },
    { name = "lb_port", port = 8080 },
  ]
}

variable "linux-ami" {
  description = "the ami for the ubuntu os used"
  type        = string
  default     = "ami-053b0d53c279acc90"
}
