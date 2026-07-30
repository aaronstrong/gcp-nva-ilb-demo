output "my_ip" {
  value       = local.cleaned_ip
  description = "The public IP address of the machine executing Terraform."
}

output "shared_host_vpc_info" {
  value = module.shared_vpc
}

output "cloud_router_info" {
  value = google_compute_router.cloud_router
}