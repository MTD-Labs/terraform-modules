locals {

  containers_map               = { for i, container in var.containers : tostring(i) => container }
  load_balanced_container_keys = [for i, container in local.containers_map : i if container.path != ""]
  load_balanced_containers = flatten([
    for key, container in local.containers_map : [
      for path in container.path : {
        name           = container.name
        path           = path
        port           = container.port
        priority       = container.priority
        health_check   = container.health_check
        service_domain = container.service_domain
        key            = key # Keep original key
      } if length(path) > 0 && length(container.service_domain) > 0
    ]
  ])

  # Ensure mapping aligns with the original container keys
  load_balanced_container_keys_map = {
    for idx, container in var.containers : idx => idx
  }

  ### compact() would be better, but it only works with list of strings, while we have list of objects
  ### https://github.com/hashicorp/terraform/issues/28264
  ### leaving this non-working code just for reference to understand what's going on in lines above
  #
  # load_balanced_containers = compact([
  #   for container in var.containers :
  #   container.path != "" ? {
  #     name         = container.name
  #     path         = container.path
  #     port         = container.port
  #     health_check = container.health_check
  #   } : null
  # ])
}

resource "aws_alb_listener_rule" "https_listener_rule" {
  for_each = {
    for idx, container in local.containers_map :
    idx => container
    if length(container.path) > 0
  }

  listener_arn = var.alb_listener_arn
  priority     = each.value["priority"]

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.service_target_group[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path
    }
  }

  dynamic "condition" {
    for_each = length(each.value.service_domain) > 0 ? [1] : []
    content {
      host_header {
        values = [each.value.service_domain]
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.domain_name) > 0 ? [1] : []
    content {
      host_header {
        values = [
          var.domain_name,
          "*.${var.domain_name}",
        ]
      }
    }
  }

  tags = merge({
    Name = each.value["name"]
  }, local.common_tags)
}

resource "aws_alb_target_group" "service_target_group" {
  for_each = {
    for idx, container in local.containers_map :
    idx => container
    if length(container.path) > 0
  }

  # name                 = "${each.value["name"]}-${each.key}"
  name                 = each.value["name"]
  port                 = each.value["port"]
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 5
  target_type          = "ip"

  dynamic "health_check" {
    for_each = length(each.value.health_check) == 0 ? [] : [1]
    content {
      healthy_threshold   = lookup(each.value.health_check, "healthy_threshold", 2)
      unhealthy_threshold = lookup(each.value.health_check, "unhealthy_threshold", 2)
      interval            = lookup(each.value.health_check, "interval", 60)
      matcher             = lookup(each.value.health_check, "matcher", "200")
      path                = lookup(each.value.health_check, "path", "/")
      port                = lookup(each.value.health_check, "port", "traffic-port")
      protocol            = lookup(each.value.health_check, "protocol", "HTTP")
      timeout             = lookup(each.value.health_check, "timeout", 30)
    }
  }

  tags = merge({
    Name = each.value["name"]
  }, local.common_tags)

  lifecycle {
    create_before_destroy = true
  }

}