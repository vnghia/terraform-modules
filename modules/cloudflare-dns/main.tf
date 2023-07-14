data "cloudflare_zone" "this" {
  zone_id = var.zone_id
}

locals {
  root_domain = data.cloudflare_zone.this.name

  ip_records = { for record in flatten([for ip_name, ip in var.ip_records : [
    for record_name, record in ip.records : merge({
      key   = "${ip_name}-${record.key != null ? record.key : record_name}"
      name  = record_name
      value = ip.address

      domain      = "${record_name == "@" ? "" : "${record_name}."}${local.root_domain}"
      proxied     = record.proxied != null ? record.proxied : ip.proxied
      enable_ddns = record.enable_ddns != null ? record.enable_ddns : ip.enable_ddns
    }, record.additional_properties)
  ]]) : record.key => record }

  records = { for record in var.records : "${record.name}:${record.type}:${record.value}" => record }
}

resource "cloudflare_record" "this" {
  for_each = merge(local.ip_records, local.records)

  zone_id = var.zone_id
  type    = lookup(each.value, "type", can(cidrnetmask("${each.value.value}/32")) ? "A" : "AAAA")

  name  = each.value.name
  value = each.value.value

  proxied         = lookup(each.value, "proxied", false)
  allow_overwrite = lookup(each.value, "allow_overwrite", null)
  comment         = lookup(each.value, "comment", each.key)
  priority        = lookup(each.value, "priority", null)
  ttl             = lookup(each.value, "ttl", null)
}

data "cloudflare_api_token_permission_groups" "all" {}

resource "cloudflare_api_token" "dns_edit" {
  count = (var.enable_ddns || var.enable_acme_dns_challenge) ? 1 : 0

  name = "dns-edit-${local.root_domain}"
  policy {
    permission_groups = [data.cloudflare_api_token_permission_groups.all.zone["DNS Write"]]
    resources         = { "com.cloudflare.api.account.zone.${var.zone_id}" = "*" }
  }
}

resource "cloudflare_api_token" "zone_read" {
  count = var.enable_acme_dns_challenge ? 1 : 0

  name = "zone-read-${local.root_domain}"
  policy {
    permission_groups = [data.cloudflare_api_token_permission_groups.all.zone["Zone Read"]]
    resources         = { "com.cloudflare.api.account.zone.${var.zone_id}" = "*" }
  }
}
