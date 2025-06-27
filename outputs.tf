output "instance1_name" {
  description = "This contains instance1 name."
  value       = google_compute_instance.vm_instance1.name
}

output "instance2_name" {
  description = "This contains instance2 name."
  value       = google_compute_instance.vm_instance2.name
}

output "disk_self_links" {
  value = google_compute_disk.standard_disks[*].self_link  # Outputs a list of all disk self_links
}

output "web_server_ips" {
    description = "The www VM names."
  value       = ({
    for _,vm in google_compute_instance.web_instances
    : vm.name => vm.network_interface[0].network_ip
  })

}