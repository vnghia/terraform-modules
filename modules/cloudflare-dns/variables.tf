variable "account_id" {
  type        = string
  description = "Cloudflare account ID"
}

variable "ip_records" {
  type = map(object({
    key = optional(string)

    ips = map(object({
      address = string

      proxied     = bool
      enable_ddns = optional(bool, false)

      records = map(object({
        key = optional(string)

        proxied     = optional(bool)
        enable_ddns = optional(bool)

        additional_properties = optional(map(any))
      }))
    }))
  }))
  description = "List of IP addresses and DNS records point to it"
}

variable "records" {
  type = map(list(map(any)))
}

variable "enable_acme_dns_challenge" {
  type        = bool
  description = "Generate token for acme DNS challange"
  default     = false
}

variable "enable_ddns" {
  type        = bool
  description = "Generate token for dynamic DNS editing"
  default     = false
}
