data "cloudflare_zone" "this" {
  for_each = toset(sort(concat(keys(var.ip_records), keys(var.records))))

  account_id = var.account_id
  name       = each.value
}

locals {
  zone_id_map = { for zone in data.cloudflare_zone.this : zone.name => zone.id }

  ip_records = { for record in flatten(
    [for zone_name, zone in var.ip_records :
      [for ip_name, ip in zone.ips :
        [for record_name, record in ip.records : merge({
          zone_name = zone_name

          key   = "${ip_name}-${zone.key != null ? zone.key : zone_name}-${record.key != null ? record.key : record_name}"
          name  = record_name
          value = ip.address

          domain      = "${record_name == "@" ? "" : "${record_name}."}${zone_name}"
          proxied     = record.proxied != null ? record.proxied : ip.proxied
          enable_ddns = record.enable_ddns != null ? record.enable_ddns : ip.enable_ddns
          }, record.additional_properties)
        ]
      ]
    ]
  ) : record.key => record }

  records = { for record in flatten(
    [for zone_name, records in var.records :
      [for record in records : merge({
        key       = "${zone_name}:${record.name}:${record.type != null ? record.type : "ip"}:${record.value}"
        zone_name = zone_name
        }, record)
      ]
    ]
  ) : record.key => record }

  token_suffix = join("-", keys(local.zone_id_map))
  token_permission_resources = {
    for zone_name, zone_id in local.zone_id_map : "com.cloudflare.api.account.zone.${zone_id}" => "*"
  }
}

resource "cloudflare_record" "this" {
  for_each = merge(local.ip_records, local.records)

  zone_id = local.zone_id_map[each.value.zone_name]
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

  name = "dns-edit-${local.token_suffix}"
  policy {
    permission_groups = [data.cloudflare_api_token_permission_groups.all.zone["DNS Write"]]
    resources         = local.token_permission_resources
  }
}

resource "cloudflare_api_token" "zone_read" {
  count = var.enable_acme_dns_challenge ? 1 : 0

  name = "zone-read-${local.token_suffix}"
  policy {
    permission_groups = [data.cloudflare_api_token_permission_groups.all.zone["Zone Read"]]
    resources         = local.token_permission_resources
  }
}
