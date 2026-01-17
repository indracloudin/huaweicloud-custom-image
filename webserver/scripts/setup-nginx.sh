#!/bin/bash
# setup-nginx.sh - Script to configure NGINX, log rotation and basic web server

set -e

echo "Starting NGINX setup..."

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
    # Backup original config
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    
    # Modify nginx.conf to include our server block
    sed -i '/# Virtual Host configuration/d' /etc/nginx/nginx.conf
    sed -i '/include \/etc\/nginx\/conf.d\/\*.conf;/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
    
    # Create sites-enabled directory if it doesn't exist
    mkdir -p /etc/nginx/sites-enabled
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
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

# Set proper permissions
chown -R nginx:nginx /var/www/html/
chmod -R 755 /var/www/html/

# Test NGINX configuration
nginx -t

# Restart NGINX to apply changes
systemctl restart nginx

echo "NGINX setup completed successfully!"