variable "vm_name" {
  type        = string
  description = "the common VM names prefix"
}
variable "region" {
  type        = string
  description = "the region where the resources live"
  default     = "us-central1"
}
variable "is_amd" {
    type = bool
    description = "Determines if the machine type is AMD or Intel"
}
variable "disk_count" {
    type = number
    description = "Total number of disks to be created"
}
variable "web_instances" {
  type = map(object({
    machine_type = string
  }))
  description = "map of Web instances and their configuration"
}
