#!/bin/bash
# cis-hardening.sh - Apply CIS hardening benchmarks to the system
# This script applies security configurations based on CIS Linux benchmarks

set -e

echo "Starting CIS hardening process..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "Cannot detect OS. Exiting."
    exit 1
fi

echo "Detected OS: $OS version $VER"

# Function to apply CentOS-specific hardening
apply_centos_hardening() {
    echo "Applying CentOS-specific hardening..."
    
    # 1.1.1 Disable unused filesystems
    cat > /etc/modprobe.d/CIS.conf << 'EOF'
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
EOF

    # 1.3.1 Ensure AIDE is installed and configured
    aide --init
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    echo "0 5 * * * root /usr/sbin/aide --check" >> /etc/crontab

    # 1.4.1 Configure bootloader
    if [ -f /boot/grub2/grub.cfg ]; then
        chmod 600 /boot/grub2/grub.cfg
    fi

    # 1.5.1 Configure additional console sessions
    echo "TMOUT=600" >> /etc/profile.d/timeout.sh
    echo "readonly TMOUT" >> /etc/profile.d/timeout.sh
    chmod +x /etc/profile.d/timeout.sh

    # 1.5.3 Set password creation requirements
    if ! grep -q "minlen" /etc/security/pwquality.conf; then
        echo "minlen = 14" >> /etc/security/pwquality.conf
    fi
    if ! grep -q "dcredit" /etc/security/pwquality.conf; then
        echo "dcredit = -1" >> /etc/security/pwquality.conf
    fi
    if ! grep -q "ocredit" /etc/security/pwquality.conf; then
        echo "ocredit = -1" >> /etc/security/pwquality.conf
    fi

    # 1.5.4 Set lockout policy
    echo "authconfig --enablefaillock --disablefaillock_serviceaccount --faillock_maxtry=5 --faillock_unlock_time=900 --update" >> /etc/rc.local

    # 3.1 Set daemon umask
    sed -i 's/umask.*/umask 027/' /etc/init.d/functions

    # 3.3 Configure SSH
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 4/g' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/g' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/g' /etc/ssh/sshd_config
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding no/g' /etc/ssh/sshd_config
    sed -i 's/#PrintLastLog yes/PrintLastLog yes/g' /etc/ssh/sshd_config

    # 3.4 Configure privilege escalation (sudo)
    echo "Defaults requiretty" >> /etc/sudoers.d/cis
    echo "Defaults logfile=/var/log/sudo.log" >> /etc/sudoers.d/cis
    echo "Defaults log_input,log_output" >> /etc/sudoers.d/cis
    chmod 440 /etc/sudoers.d/cis

    # 3.5 Configure cron
    touch /etc/cron.deny
    chmod 600 /etc/cron.deny
    chown root:root /etc/cron.deny

    # 3.6 Configure system file permissions
    chmod 644 /etc/passwd
    chmod 644 /etc/group
    chmod 600 /etc/shadow
    chmod 600 /etc/gshadow
    chmod 644 /etc/passwd-
    chmod 644 /etc/group-
    chmod 600 /etc/shadow-
    chmod 600 /etc/gshadow-

    # Enable and start security services
    systemctl enable auditd
    systemctl start auditd
    systemctl enable rsyslog
    systemctl start rsyslog
    systemctl enable fail2ban
    systemctl start fail2ban
    systemctl enable firewalld
    systemctl start firewalld
}

# Function to apply Ubuntu-specific hardening
apply_ubuntu_hardening() {
    echo "Applying Ubuntu-specific hardening..."
    
    # 1.1.1 Disable unused filesystems
    cat > /etc/modprobe.d/CIS.conf << 'EOF'
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install vfat /bin/true
EOF

    # 1.3.1 Ensure AIDE is installed and configured
    aideinit
    cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    echo "0 5 * * * root /usr/bin/aide --check" >> /etc/crontab

    # 1.4.1 Configure bootloader
    if [ -f /boot/grub/grub.cfg ]; then
        chmod 600 /boot/grub/grub.cfg
    fi

    # 1.5.1 Configure additional console sessions
    echo "TMOUT=600" >> /etc/profile.d/timeout.sh
    echo "readonly TMOUT" >> /etc/profile.d/timeout.sh
    chmod +x /etc/profile.d/timeout.sh

    # 1.5.3 Set password creation requirements
    if [ -f /etc/pam.d/common-password ]; then
        sed -i 's/.*pam_pwquality.so.*/password requisite pam_pwquality.so retry=3 minlen=14 dcredit=-1 ocredit=-1/g' /etc/pam.d/common-password
    fi

    # 1.5.4 Set lockout policy
    if [ -f /etc/pam.d/common-auth ]; then
        echo "auth required pam_tally2.so onerr=fail audit silent deny=5 unlock_time=900" >> /etc/pam.d/common-auth
    fi

    # 3.1 Set daemon umask
    sed -i 's/umask.*/umask 027/' /lib/init/vars.sh

    # 3.3 Configure SSH
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 4/g' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/g' /etc/ssh/sshd_config
    sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/g' /etc/ssh/sshd_config
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding no/g' /etc/ssh/sshd_config
    sed -i 's/#PrintLastLog yes/PrintLastLog yes/g' /etc/ssh/sshd_config

    # 3.4 Configure privilege escalation (sudo)
    echo "Defaults secure_path=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" >> /etc/sudoers.d/cis
    echo "Defaults timestamp_timeout=15" >> /etc/sudoers.d/cis
    chmod 440 /etc/sudoers.d/cis

    # 3.5 Configure cron
    touch /etc/cron.deny
    chmod 600 /etc/cron.deny
    chown root:root /etc/cron.deny

    # 3.6 Configure system file permissions
    chmod 644 /etc/passwd
    chmod 644 /etc/group
    chmod 600 /etc/shadow
    chmod 600 /etc/gshadow
    chmod 644 /etc/passwd-
    chmod 644 /etc/group-
    chmod 600 /etc/shadow-
    chmod 600 /etc/gshadow-

    # Enable and start security services
    systemctl enable auditd
    systemctl start auditd
    systemctl enable rsyslog
    systemctl start rsyslog
    systemctl enable fail2ban
    systemctl start fail2ban
    systemctl enable ufw
    systemctl start ufw
}

# Apply OS-specific hardening
if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    apply_centos_hardening
elif [[ "$OS" == *"Ubuntu"* ]]; then
    apply_ubuntu_hardening
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Common hardening steps for both OS types
echo "Applying common hardening steps..."

# 2.2.1 Configure time synchronization (NTP)
if command -v chrony &> /dev/null; then
    systemctl enable chronyd
    systemctl start chronyd
elif command -v ntpd &> /dev/null; then
    systemctl enable ntpd
    systemctl start ntpd
fi

# 3.2 Configure warning banners
echo "Authorized uses only. All activity may be monitored and reported." > /etc/motd
echo "Authorized uses only. All activity may be monitored and reported." > /etc/issue
echo "Authorized uses only. All activity may be monitored and reported." > /etc/issue.net

# 4.1 Configure logging
# Ensure rsyslog is configured properly
if [ -f /etc/rsyslog.conf ]; then
    sed -i 's/#$ModLoad imtcp/$ModLoad imtcp/g' /etc/rsyslog.conf
    sed -i 's/#$InputTCPServerRun/$InputTCPServerRun/g' /etc/rsyslog.conf
fi

# 5.1 Configure access control
# Set up basic firewall rules
if command -v firewall-cmd &> /dev/null; then
    # For CentOS/RHEL with firewalld
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload
elif command -v ufw &> /dev/null; then
    # For Ubuntu with UFW
    ufw allow ssh
    ufw --force enable
fi

# 6.1 Configure system accounts
# Lock system accounts
for user in $(awk -F: '($3 < 1000) {print $1 }' /etc/passwd); do
    if [ $user != "root" ] && [ $user != "sync" ] && [ $user != "shutdown" ] && [ $user != "halt" ]; then
        usermod -L $user
        if [ $user != "nobody" ]; then
            usermod -s /usr/sbin/nologin $user
        fi
    fi
done

# Restart services to apply changes
systemctl restart sshd
systemctl restart rsyslog

echo "CIS hardening completed successfully!"