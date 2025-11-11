/**
 * # Fortigate 802.1x configuration
 *
 * This terraform module configures the RADIUS servers and groups on a FortiGate appliance
 */
terraform {
  required_providers {
    fortios = {
      source  = "fortinetdev/fortios"
    }
  }
}

locals {
  vdom_radius_yaml      = {
    for vdom in var.vdoms : vdom => yamldecode(file("${var.config_path}/${vdom}/radius.yaml")) if fileexists("${var.config_path}/${vdom}/radius.yaml")
  }
  radius_servers_yaml   = { for vdom in var.vdoms : vdom => try(local.vdom_radius_yaml[vdom].radius_servers, []) }
  radius_groups_yaml    = { for vdom in var.vdoms : vdom => try(local.vdom_radius_yaml[vdom].radius_groups, []) }

  radius_servers        = flatten([
    for vdom in var.vdoms : [
      for name, server in local.radius_servers_yaml[vdom] : [ merge(server, { vdom = vdom, name = name }) ]
    ]
  ])
  radius_groups         = flatten([
    for vdom in var.vdoms : [
      for name, group in local.radius_groups_yaml[vdom] : [ merge(group, { vdom = vdom, name = name }) ]
    ]
  ])
}

resource fortios_user_radius radius {
  for_each            = { for radius_server in local.radius_servers : radius_server.name => radius_server }

  name                = each.value.name
  server              = each.value.primary.ip
  secret              = each.value.primary.secret

  secondary_server    = try(each.value.secondary.ip, null)
  secondary_secret    = try(each.value.secondary.secret, null)

  tertiary_server     = try(each.value.tertiary.ip, null)
  tertiary_secret     = try(each.value.tertiary.secret, null)

  timeout             = try(each.value.timeout, null)
  source_ip_interface = try(each.value.source_ip_interface, null)
  source_ip           = try(each.value.source_ip, null)

  vdomparam           = each.value.vdom
}

resource fortios_user_group groups {
  for_each            = { for radius_group in local.radius_groups : radius_group.name => radius_group }

  name                = each.value.name

  dynamic member {
    for_each          = { for member in each.value.members : member => member }
    content {
      name            = member.value
    }
  }
}
