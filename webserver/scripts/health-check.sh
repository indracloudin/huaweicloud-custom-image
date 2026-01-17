#!/bin/bash
# health-check.sh - Health check script for web server monitoring

set -e

echo "Setting up health check scripts..."

# Create health check script directory
mkdir -p /opt/health-checks

# Create a comprehensive health check script
cat > /opt/health-checks/web-server-health.sh << 'EOF'
#!/bin/bash
# Comprehensive health check script for web server

DATE=$(date)
LOG_FILE="/var/log/health-check.log"

# Log the check
echo "$DATE - Running health check" >> $LOG_FILE

# Check if NGINX is running
if pgrep nginx > /dev/null; then
    echo "$DATE - NGINX: RUNNING" >> $LOG_FILE
    NGINX_STATUS=0
else
    echo "$DATE - NGINX: STOPPED" >> $LOG_FILE
    NGINX_STATUS=1
fi

# Check if NGINX is listening on port 80
if netstat -tuln | grep ":80 " > /dev/null; then
    echo "$DATE - Port 80: LISTENING" >> $LOG_FILE
    PORT_STATUS=0
else
    echo "$DATE - Port 80: NOT LISTENING" >> $LOG_FILE
    PORT_STATUS=1
fi

# Check disk space (warn if > 80%)
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -lt 80 ]; then
    echo "$DATE - Disk usage: ${DISK_USAGE}% (OK)" >> $LOG_FILE
    DISK_STATUS=0
else
    echo "$DATE - Disk usage: ${DISK_USAGE}% (WARNING)" >> $LOG_FILE
    DISK_STATUS=1
fi

# Check memory usage (warn if > 90%)
MEM_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
if [ $MEM_USAGE -lt 90 ]; then
    echo "$DATE - Memory usage: ${MEM_USAGE}% (OK)" >> $LOG_FILE
    MEM_STATUS=0
else
    echo "$DATE - Memory usage: ${MEM_USAGE}% (WARNING)" >> $LOG_FILE
    MEM_STATUS=1
fi

# Overall status
if [ $NGINX_STATUS -eq 0 ] && [ $PORT_STATUS -eq 0 ] && [ $DISK_STATUS -eq 0 ] && [ $MEM_STATUS -eq 0 ]; then
    echo "$DATE - OVERALL STATUS: HEALTHY" >> $LOG_FILE
    echo "healthy"
    exit 0
else
    echo "$DATE - OVERALL STATUS: UNHEALTHY" >> $LOG_FILE
    echo "unhealthy"
    exit 1
fi
EOF

# Make the health check script executable
chmod +x /opt/health-checks/web-server-health.sh

# Create a systemd service for health monitoring (optional)
cat > /etc/systemd/system/health-monitor.service << 'EOF'
[Unit]
Description=Web Server Health Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/health-checks/web-server-health.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create a systemd timer for periodic health checks (optional)
cat > /etc/systemd/system/health-monitor.timer << 'EOF'
[Unit]
Description=Run health check every 5 minutes
Requires=health-monitor.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# Enable the timer
systemctl enable health-monitor.timer

# Create a simple HTTP health check endpoint handler
cat > /var/www/html/health-check.php << 'EOF'
<?php
// Simple PHP health check endpoint (if PHP is installed)
header('Content-Type: application/json');

$health = array(
    'status' => 'healthy',
    'timestamp' => date('c'),
    'server' => gethostname(),
    'services' => array(
        'nginx' => is_process_running('nginx'),
        'disk_space' => check_disk_usage(),
        'memory' => check_memory_usage()
    )
);

http_response_code(200);
echo json_encode($health, JSON_PRETTY_PRINT);

function is_process_running($process_name) {
    $result = shell_exec("pgrep $process_name");
    return $result !== null && trim($result) !== '';
}

function check_disk_usage() {
    $disk_usage = disk_usage("/");
    return $disk_usage < 80;
}

function check_memory_usage() {
    $free_memory = shell_exec("free | awk 'NR==2{printf \"%.2f\", $3/$2 * 100}'");
    return floatval($free_memory) < 90;
}
?>
EOF

echo "Health check scripts setup completed!"