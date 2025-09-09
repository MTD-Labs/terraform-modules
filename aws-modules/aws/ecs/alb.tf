locals {
  containers_map = { for i, container in var.containers : tostring(i) => container }

  # keep only containers that actually have paths
  load_balanced_container_keys = [
    for i, container in local.containers_map :
    i if length(try(container.path, [])) > 0
  ]

  # optional helper: only if you really need this list elsewhere
  load_balanced_containers = flatten([
    for key, container in local.containers_map : [
      for p in try(container.path, []) : {
        name           = container.name
        path           = p
        port           = container.port
        priority       = try(container.priority, null)
        health_check   = container.health_check
        service_domain = try(container.service_domain, "")
        key            = key
      } if length(p) > 0 && length(try(container.service_domain, "")) > 0
    ]
  ])

  load_balanced_container_keys_map = { for idx, _ in var.containers : idx => idx }
}


resource "aws_alb_listener_rule" "https_listener_rule" {
  for_each = {
    for idx, container in local.containers_map :
    idx => container
    if length(try(container.path, [])) > 0
  }

  listener_arn = var.alb_listener_arn

  # Use provided priority if set; otherwise generate a stable fallback
  priority = try(each.value.priority, 100 + tonumber(each.key))

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
    for_each = length(try(each.value.service_domain, "")) > 0 ? [1] : []
    content {
      host_header {
        values = [each.value.service_domain]
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
    if length(try(container.path, [])) > 0
  }

  name                 = each.value["name"]
  port                 = each.value["port"]
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 5
  target_type          = "ip"

  dynamic "health_check" {
    for_each = length(try(each.value.health_check, {})) == 0 ? [] : [1]
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
