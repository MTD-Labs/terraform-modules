locals {
  has_nginx_template       = endswith(var.nginx_template_path, var.none) != true
  env_file                 = endswith(var.env_file, var.none) != true
  service_repo             = endswith(var.service_repo, var.none) != true
  has_valid_suffix         = anytrue([for suffix in var.valid_suffixes_supervisor : endswith(var.proxy_pass, suffix)])
  has_valid_prefix         = anytrue([for prefix in var.valid_prefixes_supervisor : startswith(var.proxy_pass, prefix)])
  has_valid_accounts_admin = anytrue([for suffix in var.valid_suffixes_supervisor : endswith(var.proxy_pass_accounts_admin, suffix)])
}


resource "null_resource" "clone_repo" {
  count = local.service_repo ? 1 : 0

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOF
      if [ ! -d "${var.microservice_catalog_path}/${var.service_repo}" ]; then
        if [ -d "${var.microservice_catalog_path}/${var.service_repo}" ] && [ -d "${var.microservice_catalog_path}/${var.service_repo}/.git" ]; then
            echo "Repository ${var.service_repo} already cloned. Skipping..."
        else
            git clone --branch ${var.clone_branch} "${var.github_base}/${var.service_repo}" "${var.microservice_catalog_path}/${var.service_repo}"
        fi
      fi
    EOF
  }
}

data "template_file" "env" {
  template = file(var.env_template_path)

  vars = {
    username          = var.username
    proxy_pass_proxy  = var.proxy_pass_proxy
    proxy_pass_public = var.proxy_pass_public
    protocol          = var.protocol
    domain            = var.domain
  }
}

data "external" "update_env" {
  program = ["python3", "${path.module}/update_env.py"]

  query = {
    original_env_content = data.template_file.env.rendered
    env_vars_to_merge    = jsonencode(var.envs)
  }
}

resource "local_file" "env_file" {
  count      = local.env_file ? 1 : 0
  content  = data.external.update_env.result["result"]
  filename = var.env_file
  depends_on = [resource.null_resource.clone_repo]
}


data "template_file" "supervisor" {
  template = file(var.supervisor_template_path)

  vars = {
    service_name = var.service_name
    service_repo = var.service_repo
  }
}

resource "local_file" "supervisor_file" {
  count      = !local.has_valid_suffix && !local.has_valid_prefix ? 1 : 0
  content    = data.template_file.supervisor.rendered
  filename   = var.supervisor_file
  depends_on = [resource.null_resource.clone_repo]

}
data "template_file" "nginx" {
  template = file(var.nginx_template_path)

  vars = {
    service_name                = var.service_name
    server_host                 = var.server_host
    proxy_pass                  = var.proxy_pass
    proxy_pass_proxy            = var.proxy_pass_proxy
    proxy_pass_public           = var.proxy_pass_public
    proxy_pass_accounts_admin   = var.proxy_pass_accounts_admin
    domain                      = var.domain
    protocol                    = var.protocol
    proxy_header_accounts_admin = local.has_valid_accounts_admin ? var.proxy_pass_accounts_admin : var.proxy_pass_default
    service_repo                = var.service_repo
    proxy_header                = local.has_valid_suffix ? var.proxy_pass : var.proxy_pass_default
    locales_path                = var.locales_path
    styles_path                 = var.styles_path
  }
}
resource "local_file" "nginx_file" {
  count      = local.has_nginx_template ? 1 : 0
  content    = data.template_file.nginx.rendered
  filename   = var.nginx_file
  depends_on = [resource.null_resource.clone_repo]

}
data "template_file" "migration_version" {
  template = file(var.migration_version_template_path)

  vars = {
    migration_version = var.migration_version
  }
}

resource "local_file" "migration_version_file" {
  count      = var.migration_version_file != null ? 1 : 0
  content    = data.template_file.migration_version.rendered
  filename   = var.migration_version_file
  depends_on = [resource.null_resource.clone_repo]
}
