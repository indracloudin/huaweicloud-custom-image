variable "hcs_access_key" {
  type        = string
  default     = "${env("HCS_ACCESS_KEY")}"
  description = "Huawei Cloud Access Key"
}

variable "hcs_secret_key" {
  type        = string
  default     = "${env("HCS_SECRET_KEY")}"
  description = "Huawei Cloud Secret Key"
}

variable "hcs_region" {
  type        = string
  default     = "ap-southeast-4"
  description = "Huawei Cloud region"
}

variable "image_name" {
  type        = string
  default     = "ubuntu-nginx-webserver-golden-image"
  description = "Base name of the resulting image"
}

variable "enterprise_project_id" {
  type        = string
  default     = ""
  description = "Huawei Cloud Enterprise Project ID (leave empty for default project)"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  image_name_with_date = "${var.image_name}_${local.timestamp}"
}

source "huaweicloud-ecs" "ubuntu" {
  access_key     = var.hcs_access_key
  secret_key     = var.hcs_secret_key
  region         = var.hcs_region
  enterprise_project_id = var.enterprise_project_id

  source_image   = var.source_image_id  # Or appropriate Ubuntu image ID
  image_name     = local.image_name_with_date
  image_description = "Ubuntu 20.04 with NGINX, log rotation, and health checks"

  flavor         = "s7n.small.1"  # Small instance for building
  ssh_username   = "root"  # Or ubuntu depending on image

  # Network configuration
  vpc_id             = "${var.vpc_id}"           # Define variable if needed
  subnets            = ["${var.subnet_id}"]       # Define variable if needed
  security_group_ids = ["${var.security_group_id}"]  # Define variable if needed

  # Cleanup settings
  shutdown_behavior = "terminate"

  # Boot commands if needed
  boot_commands = []
}

build {
  name = "ubuntu-nginx-webserver"
  sources = [
    "source.hcs-euleros.ubuntu"
  ]

  # Provisioning scripts
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "apt-get update",
      "apt-get install -y nginx wget curl vim htop logrotate"
    ]
  }

  # Copy custom configurations
  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/"
  }

  # Run configuration script
  provisioner "shell" {
    inline = [
      "chmod +x /tmp/scripts/setup-nginx.sh",
      "chmod +x /tmp/scripts/health-check.sh",
      "bash /tmp/scripts/setup-nginx.sh",
      "bash /tmp/scripts/health-check.sh",
      "rm -rf /tmp/scripts"
    ]
  }

  # Clean up before creating image
  provisioner "shell" {
    inline = [
      "apt-get clean",
      "rm -rf /tmp/*",
      "rm -rf /root/.bash_history",
      "history -c",
      "unset HISTFILE"
    ]
  }
}