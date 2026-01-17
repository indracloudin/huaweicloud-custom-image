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
  default     = "cn-north-4"
  description = "Huawei Cloud region"
}

variable "image_name" {
  type        = string
  default     = "ubuntu-cis-hardened-golden-image"
  description = "Base name of the resulting hardened image"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  image_name_with_date = "${var.image_name}_${local.timestamp}"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the build environment"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the build environment"
}

variable "security_group_id" {
  type        = string
  description = "Security Group ID for the build environment"
}

variable "enterprise_project_id" {
  type        = string
  default     = ""
  description = "Huawei Cloud Enterprise Project ID (leave empty for default project)"
}

source "hcs-euleros" "ubuntu-hardened" {
  access_key     = var.hcs_access_key
  secret_key     = var.hcs_secret_key
  region         = var.hcs_region
  enterprise_project_id = var.enterprise_project_id

  source_image   = "Ubuntu_20.04_server_64bit"  # Or appropriate Ubuntu image ID
  image_name     = local.image_name_with_date
  image_description = "Ubuntu 20.04 hardened according to CIS benchmarks"

  flavor         = "s6.small.1"  # Small instance for building
  ssh_username   = "root"  # Or ubuntu depending on image

  # Network configuration
  vpc_id         = var.vpc_id
  subnet_id      = var.subnet_id
  security_group_ids = [var.security_group_id]

  # Cleanup settings
  shutdown_behavior = "terminate"

  # Boot commands if needed
  boot_commands = []
}

build {
  name = "ubuntu-cis-hardened"
  sources = [
    "source.hcs-euleros.ubuntu-hardened"
  ]

  # Initial updates and security packages installation
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "apt-get update",
      "apt-get upgrade -y",
      "apt-get install -y auditd audispd-plugins aide openssh-server tcpd sudo unattended-upgrades rsyslog logrotate fail2ban ufw needrestart",
      "apt-get install -y lynis debsums"  # Security auditing tools
    ]
  }

  # Copy hardening scripts and configurations
  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/"
  }

  # Apply CIS hardening
  provisioner "shell" {
    inline = [
      "chmod +x /tmp/scripts/cis-hardening.sh",
      "chmod +x /tmp/scripts/security-config.sh",
      "bash /tmp/scripts/cis-hardening.sh",
      "bash /tmp/scripts/security-config.sh",
      "rm -rf /tmp/scripts"
    ]
  }

  # Run security audit to verify hardening
  provisioner "shell" {
    inline = [
      "apt-get install -y lynis",
      "lynis audit system --auditor 'Packer Build' --no-colors > /tmp/lynis-report.txt",
      "echo 'Lynis security audit completed. Report saved to /tmp/lynis-report.txt'"
    ]
  }

  # Clean up before creating image
  provisioner "shell" {
    inline = [
      "apt-get clean",
      "rm -rf /tmp/*",
      "rm -rf /root/.bash_history",
      "history -c",
      "unset HISTFILE",
      "find /var/log -type f -delete",
      ">/var/log/audit/audit.log",
      ">/var/log/syslog",
      ">/var/log/auth.log",
      ">/var/log/kern.log"
    ]
  }
}