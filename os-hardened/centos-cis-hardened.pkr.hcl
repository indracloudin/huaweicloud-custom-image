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
  default     = "centos-cis-hardened-golden-image"
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

source "hcs-euleros" "centos-hardened" {
  access_key     = var.hcs_access_key
  secret_key     = var.hcs_secret_key
  region         = var.hcs_region
  enterprise_project_id = var.enterprise_project_id

  source_image   = "Standard_CentOS_7_latest"  # Or appropriate CentOS image ID
  image_name     = local.image_name_with_date
  image_description = "CentOS 7 hardened according to CIS benchmarks"

  flavor         = "s6.small.1"  # Small instance for building
  ssh_username   = "root"

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
  name = "centos-cis-hardened"
  sources = [
    "source.hcs-euleros.centos-hardened"
  ]

  # Initial updates and security packages installation
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "yum update -y",
      "yum install -y yum-utils yum-plugin-security yum-plugin-versionlock audit aide openssh-server tcp_wrappers sudo firewalld rsyslog logrotate fail2ban",
      "yum install -y epel-release",
      "yum install -y lynis debsums"  # Security auditing tools
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
      "yum install -y lynis",
      "lynis audit system --auditor 'Packer Build' --no-colors > /tmp/lynis-report.txt",
      "echo 'Lynis security audit completed. Report saved to /tmp/lynis-report.txt'"
    ]
  }

  # Clean up before creating image
  provisioner "shell" {
    inline = [
      "yum clean all",
      "rm -rf /tmp/*",
      "rm -rf /root/.history",
      "history -c",
      "cat /dev/null > /root/.bash_history",
      "unset HISTFILE",
      "find /var/log -type f -delete",
      ">/var/log/audit/audit.log",
      ">/var/log/messages",
      ">/var/log/secure",
      ">/var/log/maillog"
    ]
  }
}