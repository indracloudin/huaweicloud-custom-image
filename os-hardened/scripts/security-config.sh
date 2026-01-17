#!/bin/bash
# security-config.sh - Additional security configurations for hardened image

set -e

echo "Starting additional security configurations..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "Cannot detect OS. Exiting."
    exit 1
fi

# Create security configuration directory
mkdir -p /etc/security.d/

# Kernel hardening parameters
cat > /etc/sysctl.d/99-cis-kernel-hardening.conf << 'EOF'
# 1.5.1 Ensure XD/NX support is enabled (already enabled by default on most modern kernels)
# This is hardware-dependent and enabled by default

# 1.5.2 Ensure address space layout randomization (ASLR) is enabled
kernel.randomize_va_space = 2

# 1.5.3 Ensure prelink is disabled (not installed by default)
# Package should not be installed

# 1.5.4 Ensure core dumps are restricted
fs.suid_dumpable = 0

# 3.1 Set daemon umask
# Already set in previous script

# 3.2.1 Disable IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# 3.2.2 Disable send packet redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# 3.3.1 Ensure source routed packets are not accepted
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# 3.3.2 Ensure ICMP redirects are not accepted
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# 3.3.3 Ensure secure ICMP redirects are not accepted
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# 3.3.4 Ensure suspicious packets are logged
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# 3.3.5 Ensure broadcast ICMP requests are ignored
net.ipv4.icmp_echo_ignore_broadcasts = 1

# 3.3.6 Ensure bogus ICMP responses are ignored
net.ipv4.icmp_ignore_bogus_error_responses = 1

# 3.3.7 Ensure Reverse Path Filtering is enabled
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# 3.3.8 Ensure TCP SYN Cookies is enabled
net.ipv4.tcp_syncookies = 1

# 3.3.9 Ensure IPv6 router advertisements are not accepted
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# 3.6.2 Ensure DCCP is disabled
net.ipv4.dccp.disable = 1

# 3.6.3 Ensure SCTP is disabled
net.ipv4.sctp.disable = 1

# 3.6.4 Ensure RDS is disabled
net.ipv4.rds.disable = 1

# 3.6.5 Ensure TIPC is disabled
net.ipv4.tipc.disable = 1
EOF

# Apply kernel parameters
sysctl -p /etc/sysctl.d/99-cis-kernel-hardening.conf

# Configure system limits
cat > /etc/security/limits.d/10-cis-security.conf << 'EOF'
# Prevent core dumps for all users
* hard core 0

# Limit number of processes
* soft nproc 30000
* hard nproc 30000

# Limit number of open files
* soft nofile 1024000
* hard nofile 1024000
EOF

# Configure login security
cat > /etc/security/access.conf << 'EOF'
# Allow local console access
+ : root : LOCAL
+ : wheel : LOCAL

# Deny remote root login
- : root : ALL

# Allow SSH access from specific networks (adjust as needed)
+ : ALL : 127.0.0.1
+ : ALL : 10.0.0.0/8
+ : ALL : 192.168.0.0/16
+ : ALL : 172.16.0.0/12

# Deny all other access
- : ALL : ALL
EOF

# Configure SSH security (additional settings)
cat > /etc/ssh/sshd_config.d/cis-security.conf << 'EOF'
# Additional SSH security settings
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Key exchange algorithms
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Cipher algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# MAC algorithms
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256,hmac-sha2-512,umac-128@openssh.com

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication
LoginGraceTime 60
PermitEmptyPasswords no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitUserEnvironment no

# X11 forwarding
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
TCPKeepAlive no
UsePrivilegeSeparation yes
MaxStartups 10:30:60
Banner /etc/issue.net
EOF

# For older systems that don't support sshd_config.d directory
if [ ! -d /etc/ssh/sshd_config.d ]; then
    # Append to main sshd_config file instead
    cat >> /etc/ssh/sshd_config << 'EOF'

# Additional SSH security settings
Protocol 2

# Key exchange algorithms
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Cipher algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# MAC algorithms
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256,hmac-sha2-512,umac-128@openssh.com

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication
LoginGraceTime 60
PermitEmptyPasswords no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitUserEnvironment no

# X11 forwarding
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
TCPKeepAlive no
UsePrivilegeSeparation yes
MaxStartups 10:30:60
Banner /etc/issue.net
EOF
fi

# Configure audit rules
cat > /etc/audit/rules.d/cis-audit.rules << 'EOF'
# Audit system rules following CIS guidelines

# Record events that modify date/time
-a always,exit -F arch=b64 -S adjtimex,settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# Record events that modify user/group information
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Record events that modify network configuration
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network -p wa -k system-locale

# Record events that modify mandatory access controls
-a always,exit -F arch=b64 -S mount,umount2 -k mounts
-a always,exit -F arch=b32 -S mount,umount2 -k mounts
-w /etc/fstab -p wa -k mounts
-w /etc/mtab -p wa -k mounts

# Record file deletion events
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -k delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -k delete

# Record events that modify system administration scope
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# Record system administrator actions
-w /var/log/sudo.log -p wa -k actions

# Record kernel module loading and unloading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modules
EOF

# Restart audit daemon to apply rules
if command -v systemctl &> /dev/null; then
    systemctl restart auditd
fi

# Configure automatic security updates
if [[ "$OS" == *"Ubuntu"* ]]; then
    # Configure unattended upgrades for Ubuntu
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Verbose "1";
EOF

    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {
    // List of packages to not update
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::OnlyOnACPower "false";
Unattended-Upgrade::SkipUpdatesOnMeteredConnection "false";
EOF

    # Enable unattended upgrades
    systemctl enable unattended-upgrades
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    # Configure automatic updates for CentOS/RHEL
    systemctl enable yum-cron
    systemctl start yum-cron
fi

# Set proper permissions on security-sensitive files
chmod 600 /etc/anacrontab
chmod 600 /etc/crontab
chmod 600 /etc/cron.d/
chmod 600 /etc/cron.daily/
chmod 600 /etc/cron.hourly/
chmod 600 /etc/cron.monthly/
chmod 600 /etc/cron.weekly/
chmod 644 /etc/hosts.allow
chmod 644 /etc/hosts.deny

# Create a security checklist file
cat > /root/security-checklist.txt << 'EOF'
CIS HARDENED SYSTEM CHECKLIST
=============================

System Information:
- OS: [TO BE FILLED]
- Kernel: $(uname -r)
- Hardened: Yes (CIS compliant)
- Build Date: $(date)

Security Features Enabled:
1. Kernel Hardening (ASLR, Core dumps restricted)
2. Network Security (IP Forwarding disabled, ICMP protection)
3. SSH Hardening (Strong ciphers, no root login)
4. Account Security (Password policies, lockout)
5. Logging and Auditing (Auditd, Rsyslog)
6. Firewall (UFW/Firewalld enabled)
7. Intrusion Prevention (Fail2Ban active)
8. File Integrity Monitoring (AIDE active)
9. Automatic Security Updates
10. Process Accounting (if enabled)

Recommended Post-Deployment Steps:
1. Change default passwords
2. Configure network ACLs/security groups appropriately
3. Set up centralized logging if required
4. Perform vulnerability scan
5. Document any customizations made

Security Audit Status:
- Lynis scan performed during build
- Manual verification recommended after deployment
EOF

# Update the checklist with actual system info
sed -i "s/\[TO BE FILLED\]/$(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')/" /root/security-checklist.txt

echo "Additional security configurations completed!"