output "my_ip" {
  value       = local.cleaned_ip
  description = "The public IP address of the machine executing Terraform."
}
