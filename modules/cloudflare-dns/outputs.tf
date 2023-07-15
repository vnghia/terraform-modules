output "domain" {
  description = "Map between record key and its domain"
  value = merge(
    { for record_key, record in local.ip_records : record_key => record.domain },
    { for zone_name, zone in var.ip_records : "${zone.key != null ? zone.key : zone_name}-@" => zone_name }
  )
}

output "record_id" {
  description = "Map between record key and its id on cloudflare (if enable ddns)"
  value = {
    for record_key, record in local.ip_records : record_key => cloudflare_record.this[record_key].id if record.enable_ddns
  }
}

output "dns_edit_token" {
  description = "DNS edit token"
  value       = length(cloudflare_api_token.dns_edit) > 0 ? cloudflare_api_token.dns_edit[0].value : null
  sensitive   = true
}

output "zone_read_token" {
  description = "Zone read token"
  value       = length(cloudflare_api_token.zone_read) > 0 ? cloudflare_api_token.zone_read[0].value : null
  sensitive   = true
}
