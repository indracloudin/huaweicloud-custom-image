# Huawei Cloud Custom Images

This repository contains Packer templates and automation scripts for building custom, production-ready images on Huawei Cloud ECS (Elastic Cloud Server) instances. The project includes both security-hardened operating systems and optimized web server configurations.

## Project Structure

This repository is organized into two main subprojects:

### 1. OS-Hardened (`os-hardened/`)
Contains Packer templates to build hardened Linux images based on CIS (Center for Internet Security) benchmarks for Huawei Cloud ECS instances. These images implement security best practices to provide a secure foundation for your applications.

### 2. Web Server (`webserver/`)
Contains Packer templates to build golden images with NGINX web server for Huawei Cloud ECS instances. These images are pre-configured with optimized settings for production web applications.

## Features

### OS-Hardened Images
- **Kernel Hardening**: ASLR, core dump restrictions, disabled unused filesystems
- **Authentication & Authorization**: Strong password policies, account lockout mechanisms, SSH hardening
- **Network Security**: Firewall configuration, secure SSH settings, network protections
- **Logging & Monitoring**: Auditd, centralized logging, file integrity monitoring
- **Compliance**: Implements CIS Red Hat Enterprise Linux 7 and Ubuntu 18.04 LTS benchmarks

### Web Server Images
- **NGINX Web Server**: Pre-configured with optimized settings
- **Health Checks**: Built-in health check endpoints and monitoring
- **Log Rotation**: Automatic rotation and compression of web server logs
- **Security Headers**: Basic security headers enabled by default
- **Performance Optimized**: Configured for production use

## Prerequisites

1. Install Packer from https://www.packer.io/downloads
2. Huawei Cloud account with appropriate permissions
3. Access and Secret keys for Huawei Cloud
4. Git for version control

## Setup Environment Variables

```bash
export HCS_ACCESS_KEY="your-access-key"
export HCS_SECRET_KEY="your-secret-key"
```

## Building Images

### OS-Hardened Images

#### For Hardened CentOS:
```bash
cd os-hardened
packer build \
  -var "hcs_region=cn-north-4" \
  -var "vpc_id=your-vpc-id" \
  -var "subnet_id=your-subnet-id" \
  -var "security_group_id=your-security-group-id" \
  centos-cis-hardened.pkr.hcl
```

#### For Hardened Ubuntu:
```bash
cd os-hardened
packer build \
  -var "hcs_region=cn-north-4" \
  -var "vpc_id=your-vpc-id" \
  -var "subnet_id=your-subnet-id" \
  -var "security_group_id=your-security-group-id" \
  ubuntu-cis-hardened.pkr.hcl
```

### Web Server Images

#### For CentOS with NGINX:
```bash
cd webserver
packer build -var-file=variables.pkrvars.hcl centos-nginx-huawei.pkr.hcl
```

#### For Ubuntu with NGINX:
```bash
cd webserver
packer build -var-file=variables.pkrvars.hcl ubuntu-nginx-huawei.pkr.hcl
```

## Automated CI/CD with Jenkins

Both subprojects include Jenkins pipeline automation for continuous building of images.

### Prerequisites for Jenkins

1. Jenkins server with Pipeline plugin
2. Docker installed on Jenkins agents (if using Docker-based builds)
3. Huawei Cloud credentials stored in Jenkins credential store
4. Packer installed on Jenkins agents
5. Security scanning tools (for hardened images)

### Jenkins Setup

1. Store Huawei Cloud credentials in Jenkins:
   - Add `hcs-access-key` credential (username/password or secret text)
   - Add `hcs-secret-key` credential (secret text)

2. Create a new Pipeline job in Jenkins and configure it to use the `Jenkinsfile` in the respective subdirectories

3. Configure build parameters as defined in the Jenkinsfiles

### Using the Jenkins Pipeline

#### For OS-Hardened Images:
1. **Validate Parameters** - Validates input parameters and sets image name with timestamp
2. **Checkout Code** - Gets the latest code from repository
3. **Validate Packer Template** - Validates the Packer configuration
4. **Prepare Hardening Configuration** - Adjusts hardening based on selected level
5. **Build Hardened Image** - Builds the hardened image using Packer
6. **Security Verification** - Runs additional security checks on the image
7. **Cleanup** - Cleans up temporary files

#### For Web Server Images:
1. **Validate Parameters** - Validates input parameters
2. **Checkout Code** - Gets the latest code from repository
3. **Validate Packer Template** - Validates the Packer configuration
4. **Build Image** - Builds the golden image using Packer
5. **Verify Image** - Verifies the image was created successfully

### Jenkins Docker Agent

For containerized builds, use the provided Dockerfiles:

```bash
# Build the Jenkins agent image for OS-Hardened
cd os-hardened
docker build -f Dockerfile.jenkins -t huawei-cloud-hardened-jenkins-agent .

# Build the Jenkins agent image for Web Server
cd webserver
docker build -f Dockerfile.jenkins -t huawei-cloud-webserver-jenkins-agent .
```

### Pipeline Parameters

Common parameters for both pipelines:
- `IMAGE_TYPE`: Select 'centos' or 'ubuntu' for the base OS
- `IMAGE_NAME`: Custom name for the image (optional)
- `VPC_ID`: VPC ID for the build environment
- `SUBNET_ID`: Subnet ID for the build environment
- `SECURITY_GROUP_ID`: Security Group ID for the build environment
- `REGION`: Huawei Cloud region to build the image in

Additional parameters for OS-Hardened:
- `HARDENING_LEVEL`: Select 'minimal', 'standard', or 'strict' hardening level

## Security Compliance

The OS-Hardened images implement recommendations from:
- CIS Red Hat Enterprise Linux 7 Benchmark v2.2.0
- CIS Ubuntu Linux 18.04 LTS Benchmark v2.0.1

The system undergoes a security audit using Lynis during the build process to verify hardening measures.

## Post-Deployment Recommendations

### For OS-Hardened Images:
1. **Change Default Credentials**: Update any default passwords immediately
2. **Network Configuration**: Configure security groups and network ACLs appropriately
3. **Centralized Logging**: Set up log forwarding to your SIEM if required
4. **Vulnerability Scanning**: Perform a security scan after deployment
5. **Custom Applications**: Apply security hardening to any additional software installed

### For Web Server Images:
1. **Update Content**: Replace default welcome page with your application
2. **SSL/TLS Configuration**: Implement HTTPS with valid certificates
3. **Monitoring**: Integrate with your monitoring solution
4. **Backup Strategy**: Implement backup procedures for your web content
5. **Security Updates**: Establish a process for applying security patches

## Customization

### OS-Hardened Images
You can customize the hardening by modifying:
- `os-hardened/scripts/cis-hardening.sh` - Core CIS hardening configurations
- `os-hardened/scripts/security-config.sh` - Additional security settings
- Variables in the `.pkr.hcl` files

### Web Server Images
You can customize the image by modifying:
- `webserver/scripts/setup-nginx.sh` - NGINX configuration
- `webserver/scripts/health-check.sh` - Health check logic
- Variables in the `.pkr.hcl` files
- HTML content in the provisioning scripts

## Troubleshooting

### General Issues
- If build fails during security audit, check the Lynis report at `/tmp/lynis-report.txt` (for hardened images)
- Verify that your Huawei Cloud credentials have permissions to create images
- Ensure network settings (VPC, subnet, security group) are correctly specified
- Check that the source image IDs are available in your region
- For Jenkins pipeline issues, check the build logs for detailed error messages

### OS-Hardened Specific Issues
- If using strict hardening, verify that applications are compatible with enhanced security settings
- Check that security scanning tools are properly installed and configured

### Web Server Specific Issues
- If health checks fail, verify the health check endpoints are accessible
- Check NGINX configuration for syntax errors
- Verify log rotation settings are working properly

### Jenkins Agent Troubleshooting

#### Agent Unable to Connect to Jenkins Master

If your Huawei Cloud Jenkins agent is unable to connect to the Jenkins master at `http://172.30.0.49:8080`, follow these detailed troubleshooting steps:

##### 1. **Verify Master Accessibility**
   - From the agent machine, test connectivity to the Jenkins master:
   ```bash
   ping 172.30.0.49
   telnet 172.30.0.49 8080
   curl -I http://172.30.0.49:8080
   ```
   - Ensure the Jenkins master is running and accessible

##### 2. **Check JNLP Port Configuration**
   - In Jenkins master: `Manage Jenkins` → `Configure Global Security` → `Agents`
   - Verify that "TCP port for JNLP agents" is set (typically 50000)
   - If set to "Random", fix it to a specific port and update firewall rules

##### 3. **Verify Agent Configuration**
   - Ensure the agent name matches exactly between Jenkins master and agent configuration
   - Check that the secret token or credentials are correct
   - Verify the JNLP URL is correct: `http://172.30.0.49:8080/computer/huawei-cloud-agent/slave-agent.jnlp`

##### 4. **Firewall and Security Groups**
   - Ensure port 8080 (HTTP) and port 50000 (JNLP) are open between agent and master
   - Check Huawei Cloud security groups for both the master and agent instances
   - Verify local firewall settings on both machines (iptables, ufw, etc.)

##### 5. **Test Manual Connection**
   - On the agent machine, download the JNLP file manually:
   ```bash
   java -jar agent.jar -jnlpUrl http://172.30.0.49:8080/computer/huawei-cloud-agent/slave-agent.jnlp -secret [AGENT_SECRET] -workDir "/tmp/jenkins"
   ```
   - Replace `[AGENT_SECRET]` with the actual secret from the agent configuration page

##### 6. **Docker-Specific Issues**
   - If using Docker, ensure the container can reach the host network:
   ```bash
   docker run -d --name huawei-cloud-agent --add-host jenkins-master:172.30.0.49 huawei-cloud-hardened-jenkins-agent
   ```
   - Or use host networking mode if appropriate:
   ```bash
   docker run -d --name huawei-cloud-agent --network host huawei-cloud-jenkins-agent
   ```

##### 7. **Check Jenkins Master Logs**
   - View Jenkins master logs at `Manage Jenkins` → `System Log`
   - Look for connection attempts and error messages
   - Check for authentication failures or network errors

##### 8. **Agent Container Logs**
   - If using Docker, check container logs:
   ```bash
   docker logs huawei-cloud-agent
   ```
   - Look for connection errors, authentication failures, or network timeouts

##### 9. **Java Version Compatibility**
   - Ensure the Java version on the agent is compatible with the Jenkins master
   - Check that the agent has the correct Java runtime installed

##### 10. **Restart Services**
   - Restart the Jenkins master service
   - Restart the agent container/service
   - Clear any cached connection information

##### 11. **Security Configuration**
   - In Jenkins master: `Manage Jenkins` → `Configure Global Security`
   - Ensure "Agents" section allows inbound connections
   - Check that CSRF protection settings are not blocking connections

##### 12. **Network DNS Resolution**
   - If using hostnames instead of IPs, ensure DNS resolution works
   - Add entries to `/etc/hosts` if needed for testing

## Contributing

Contributions to improve the security, functionality, or documentation of these images are welcome. Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support with these images:
- Open an issue in this repository for bugs or feature requests
- Check the troubleshooting section above for common issues
- Consult the official Huawei Cloud documentation for platform-specific questions