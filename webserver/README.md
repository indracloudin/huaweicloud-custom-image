# Huawei Cloud Golden Image Builder

This project contains Packer templates to build golden images with NGINX web server for Huawei Cloud ECS instances.

## Prerequisites

1. Install Packer from https://www.packer.io/downloads
2. Huawei Cloud account with appropriate permissions
3. Access and Secret keys for Huawei Cloud

## Setup Environment Variables

```bash
export HCS_ACCESS_KEY="your-access-key"
export HCS_SECRET_KEY="your-secret-key"
```

## Building the Image

### For CentOS:
```bash
cd huawei-cloud-image
packer build -var-file=variables.pkrvars.hcl centos-nginx-huawei.pkr.hcl
```

### For Ubuntu:
```bash
cd huawei-cloud-image
packer build -var-file=variables.pkrvars.hcl ubuntu-nginx-huawei.pkr.hcl
```

## Features Included

1. **NGINX Web Server** - Pre-configured with optimized settings
2. **Log Rotation** - Automatic rotation of web server logs
3. **Health Checks** - Scripts and endpoints for monitoring
4. **Security Headers** - Basic security headers enabled
5. **Performance Optimized** - Configured for production use

## Configuration Details

### Web Server
- Default site configured at `/var/www/html/`
- Custom welcome page indicating healthy status
- Security headers enabled by default

### Health Checks
- HTTP endpoint at `/health` returning "healthy"
- Systemd timer running health checks every 5 minutes
- Comprehensive system health monitoring script
- Metrics endpoint at `/metrics` (restricted access)

### Log Rotation
- Daily rotation of NGINX logs
- 52 weeks of logs retained
- Compression of rotated logs
- Automatic NGINX signal handling after rotation

## Automated CI/CD with Jenkins

This project includes Jenkins pipeline automation for building golden images continuously.

### Prerequisites for Jenkins

1. Jenkins server with Pipeline plugin
2. Docker installed on Jenkins agents (if using Docker-based builds)
3. Huawei Cloud credentials stored in Jenkins credential store
4. Packer installed on Jenkins agents

### Jenkins Setup

1. Store Huawei Cloud credentials in Jenkins:
   - Add `hcs-access-key` credential (username/password or secret text)
   - Add `hcs-secret-key` credential (secret text)

2. Create a new Pipeline job in Jenkins and configure it to use the `Jenkinsfile` in this repository

3. Configure build parameters as defined in the Jenkinsfile

### Using the Jenkins Pipeline

The pipeline includes the following stages:
1. **Validate Parameters** - Validates input parameters
2. **Checkout Code** - Gets the latest code from repository
3. **Validate Packer Template** - Validates the Packer configuration
4. **Build Image** - Builds the golden image using Packer
5. **Verify Image** - Verifies the image was created successfully

### Jenkins Docker Agent

For containerized builds, use the provided Dockerfile:

```bash
# Build the Jenkins agent image
docker build -f Dockerfile.jenkins -t huawei-cloud-jenkins-agent .

# Run the Jenkins agent
docker run -d --name jenkins-agent huawei-cloud-jenkins-agent
```

### Pipeline Parameters

- `IMAGE_TYPE`: Select 'centos' or 'ubuntu' for the base OS
- `IMAGE_NAME`: Custom name for the image (optional)
- `VPC_ID`: VPC ID for the build environment
- `SUBNET_ID`: Subnet ID for the build environment
- `SECURITY_GROUP_ID`: Security Group ID for the build environment
- `REGION`: Huawei Cloud region to build the image in

## Deployment

Once the image is built:
1. The image will be available in Huawei Cloud Image Management
2. Use the image ID to launch ECS instances
3. All instances launched from this image will have NGINX pre-installed and configured
4. Health checks will be operational immediately

## Customization

You can customize the image by modifying:
- `scripts/setup-nginx.sh` - NGINX configuration
- `scripts/health-check.sh` - Health check logic
- Variables in the `.pkr.hcl` files
- HTML content in the provisioning scripts

## Troubleshooting

- If build fails due to network issues, retry the build
- Check that your Huawei Cloud credentials are valid
- Ensure the VPC, subnet, and security group IDs are correct
- Verify that you have permissions to create images in the specified region
- For Jenkins pipeline issues, check the build logs for detailed error messages

## Jenkins Agent Troubleshooting

### Agent Unable to Connect to Jenkins Master

If your Huawei Cloud Jenkins agent is unable to connect to the Jenkins master at `http://172.30.0.49:8080`, follow these detailed troubleshooting steps:

#### 1. **Verify Master Accessibility**
   - From the agent machine, test connectivity to the Jenkins master:
   ```bash
   ping 172.30.0.49
   telnet 172.30.0.49 8080
   curl -I http://172.30.0.49:8080
   ```
   - Ensure the Jenkins master is running and accessible

#### 2. **Check JNLP Port Configuration**
   - In Jenkins master: `Manage Jenkins` → `Configure Global Security` → `Agents`
   - Verify that "TCP port for JNLP agents" is set (typically 50000)
   - If set to "Random", fix it to a specific port and update firewall rules

#### 3. **Verify Agent Configuration**
   - Ensure the agent name matches exactly between Jenkins master and agent configuration
   - Check that the secret token or credentials are correct
   - Verify the JNLP URL is correct: `http://172.30.0.49:8080/computer/huawei-cloud-agent/slave-agent.jnlp`

#### 4. **Firewall and Security Groups**
   - Ensure port 8080 (HTTP) and port 50000 (JNLP) are open between agent and master
   - Check Huawei Cloud security groups for both the master and agent instances
   - Verify local firewall settings on both machines (iptables, ufw, etc.)

#### 5. **Test Manual Connection**
   - On the agent machine, download the JNLP file manually:
   ```bash
   java -jar agent.jar -jnlpUrl http://172.30.0.49:8080/computer/huawei-cloud-agent/slave-agent.jnlp -secret [AGENT_SECRET] -workDir "/tmp/jenkins"
   ```
   - Replace `[AGENT_SECRET]` with the actual secret from the agent configuration page

#### 6. **Docker-Specific Issues**
   - If using Docker, ensure the container can reach the host network:
   ```bash
   docker run -d --name huawei-cloud-agent --add-host jenkins-master:172.30.0.49 huawei-cloud-jenkins-agent
   ```
   - Or use host networking mode if appropriate:
   ```bash
   docker run -d --name huawei-cloud-agent --network host huawei-cloud-jenkins-agent
   ```

#### 7. **Check Jenkins Master Logs**
   - View Jenkins master logs at `Manage Jenkins` → `System Log`
   - Look for connection attempts and error messages
   - Check for authentication failures or network errors

#### 8. **Agent Container Logs**
   - If using Docker, check container logs:
   ```bash
   docker logs huawei-cloud-agent
   ```
   - Look for connection errors, authentication failures, or network timeouts

#### 9. **Java Version Compatibility**
   - Ensure the Java version on the agent is compatible with the Jenkins master
   - Check that the agent has the correct Java runtime installed

#### 10. **Restart Services**
   - Restart the Jenkins master service
   - Restart the agent container/service
   - Clear any cached connection information

#### 11. **Security Configuration**
   - In Jenkins master: `Manage Jenkins` → `Configure Global Security`
   - Ensure "Agents" section allows inbound connections
   - Check that CSRF protection settings are not blocking connections

#### 12. **Network DNS Resolution**
   - If using hostnames instead of IPs, ensure DNS resolution works
   - Add entries to `/etc/hosts` if needed for testing