#!/bin/bash
# setup-nginx.sh - Script to configure NGINX, log rotation and basic web server

set -e

echo "Starting NGINX setup..."

# Detect the OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "Cannot detect OS. Exiting."
    exit 1
fi

# Install NGINX based on OS
if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    # CentOS/RHEL
    yum update -y
    yum install -y nginx wget curl vim htop logrotate
    NGINX_USER="nginx"
elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    # Ubuntu/Debian
    apt-get update
    apt-get install -y nginx wget curl vim htop logrotate
    NGINX_USER="www-data"
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Enable and start NGINX service
systemctl enable nginx
systemctl start nginx

# Create a basic index.html file
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to NGINX Web Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f0f0f0; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; }
        .status { color: #27ae60; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to NGINX Web Server</h1>
        <p>This is a <span class="status">healthy</span> web server instance built from the golden image.</p>
        <p>Server: $(hostname)</p>
        <p>Date: $(date)</p>
    </div>
</body>
</html>
EOF

# Configure NGINX default site
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    listen [::]:80;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Metrics endpoint
    location /metrics {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        allow 192.168.0.0/16;
        allow 172.16.0.0/12;
        deny all;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF

# For CentOS, the default site config might be in a different location
if [ -f /etc/nginx/nginx.conf ]; then
    # Create sites-available and sites-enabled directories if they don't exist
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled

    # Add include directive for sites-enabled if not already present
    if ! grep -q "sites-enabled" /etc/nginx/nginx.conf; then
        sed -i '/include \/etc\/nginx\/conf.d\/\*.conf;/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
    fi

    # Create symlink to enable the site (the default config was already created above)
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>/dev/null || true
fi

# Create directory for custom log rotation
mkdir -p /etc/logrotate.d/

# Create logrotate configuration for NGINX
cat > /etc/logrotate.d/nginx-custom << 'EOF'
/var/log/nginx/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 0640 nginx adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
            run-parts /etc/logrotate.d/httpd-prerolate; \
        fi \
    endscript
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
EOF

# Set proper permissions using the appropriate user for the OS
chown -R $NGINX_USER:$NGINX_USER /var/www/html/
chmod -R 755 /var/www/html/

# Test NGINX configuration
nginx -t

# Restart NGINX to apply changes
systemctl restart nginx

echo "NGINX setup completed successfully!"