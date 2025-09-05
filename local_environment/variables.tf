variable "config_path" {
  description = "Relative path to the config file"
  type        = string
  default     = "config.json"
}
variable "env_template_path" {
  description = "env template path"
  type        = string
  default     = null
}
variable "env_file" {
  description = "env template path"
  type        = string
  default     = null
}
variable "supervisor_template_path" {
  description = "supervisor template path"
  type        = string
  default     = "./terraform/config/templates/supervisord/supervisord.ini"
}
variable "migration_version_template_path" {
  description = "migration-version template path"
  type        = string
  default     = "./terraform/config/templates/.migration-version"
}
variable "supervisor_file" {
  description = "supervisor template path"
  type        = string
  default     = null
}
variable "migration_version_file" {
  description = "migration template path"
  type        = string
  default     = null
}
variable "nginx_template_path" {
  description = "nginx template path"
  type        = string
  default     = null
}
variable "nginx_file" {
  description = "nginx template path"
  type        = string
  default     = null
}
variable "microservice_catalog_path" {
  description = "Microservice Catalog Folder Path"
  type        = string
  default     = "data_volumes/microservice_catalog"
}
variable "clone_branch" {
  description = "Clone Branch"
  type        = string
  default     = "master"
}
variable "service_repo" {
  description = "Service Repo"
  type        = string
}
variable "github_base" {
  description = "GitHub org path"
  type        = string
  default     = "git@github.com:MTD-Labs"
}
variable "username" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = null
}
variable "migration_version" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = null
}
variable "service_name" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = null
}
variable "server_host" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = "remote"
}
variable "proxy_pass_default" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = "$host"
}
variable "proxy_pass" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = ""
}
variable "proxy_pass_accounts_admin" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = ""
}
variable "proxy_pass_public" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = ""
}
variable "proxy_pass_proxy" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = ""
}
variable "none" {
  description = "A string of variables to none to the template"
  type        = string
  default     = "none"
}
variable "domain" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = "trendex.dev"
}
variable "protocol" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = "https"
}
variable "locales_path" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = "https"
}
variable "styles_path" {
  description = "A string of variables to pass to the template"
  type        = string
  default     = "/styles"
}
variable "valid_suffixes_supervisor" {
  description = "List of valid suffixes for server_host"
  type        = list(string)
  default     = [".trendex.ai", "trendex.ai/"]
}
variable "valid_prefixes_supervisor" {
  description = "List of valid suffixes for server_host"
  type        = list(string)
  default     = ["host.docker.internal", "172.16.13", "172.16.12.2:9001"]
}
variable "envs" {
  type = map(string)
}
