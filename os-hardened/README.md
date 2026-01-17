# Huawei Cloud Hardened Linux Images (CIS Benchmarks)

This project contains Packer templates to build hardened Linux images based on CIS (Center for Internet Security) benchmarks for Huawei Cloud ECS instances.

## Overview

These images are built with security best practices in mind, implementing configurations from the CIS Linux benchmarks to provide a secure foundation for your applications.

## Security Features

### Kernel Hardening
- Address Space Layout Randomization (ASLR) enabled
- Core dump restrictions
- Disabled unused filesystems
- IP forwarding disabled
- ICMP redirect protections

### Authentication & Authorization
- Strong password policies (minimum 14 characters, complexity requirements)
- Account lockout after failed attempts (5 attempts, 15 minute lockout)
- SSH hardening with strong ciphers and protocols
- Root login disabled via SSH
- Session timeouts enforced

### Network Security
- Firewall enabled (UFW for Ubuntu, Firewalld for CentOS)
- Secure SSH configuration
- TCP SYN cookies enabled
- Reverse Path Filtering enabled
- Broadcast ICMP requests ignored

### Logging & Monitoring
- Auditd configured with comprehensive rules
- Centralized logging with rsyslog
- File integrity monitoring with AIDE
- Intrusion prevention with Fail2Ban

### Additional Security Measures
- Automatic security updates
- Process accounting
- Secure system file permissions
- Warning banners configured
- System accounts locked where appropriate

## Prerequisites

1. Install Packer from https://www.packer.io/downloads
2. Huawei Cloud account with appropriate permissions
3. Access and Secret keys for Huawei Cloud

## Setup Environment Variables

```bash
export HCS_ACCESS_KEY="your-access-key"
export HCS_SECRET_KEY="your-secret-key"
```

## Building the Hardened Image

### For Hardened CentOS:
```bash
cd huawei-cloud-hardened
packer build \
  -var "hcs_region=cn-north-4" \
  -var "vpc_id=your-vpc-id" \
  -var "subnet_id=your-subnet-id" \
  -var "security_group_id=your-security-group-id" \
  centos-cis-hardened.pkr.hcl
```

### For Hardened Ubuntu:
```bash
cd huawei-cloud-hardened
packer build \
  -var "hcs_region=cn-north-4" \
  -var "vpc_id=your-vpc-id" \
  -var "subnet_id=your-subnet-id" \
  -var "security_group_id=your-security-group-id" \
  ubuntu-cis-hardened.pkr.hcl
```

## Automated CI/CD with Jenkins

This project includes Jenkins pipeline automation for building hardened images continuously.

### Prerequisites for Jenkins

1. Jenkins server with Pipeline plugin
2. Docker installed on Jenkins agents (if using Docker-based builds)
3. Huawei Cloud credentials stored in Jenkins credential store
4. Packer installed on Jenkins agents
5. Security scanning tools (Lynis, AIDE) installed on Jenkins agents

### Jenkins Setup

1. Store Huawei Cloud credentials in Jenkins:
   - Add `hcs-access-key` credential (username/password or secret text)
   - Add `hcs-secret-key` credential (secret text)

2. Create a new Pipeline job in Jenkins and configure it to use the `Jenkinsfile` in this repository

3. Configure build parameters as defined in the Jenkinsfile:
   - `IMAGE_TYPE`: Select 'centos' or 'ubuntu' for the base OS
   - `HARDENING_LEVEL`: Select 'minimal', 'standard', or 'strict' hardening level
   - `IMAGE_NAME`: Custom name for the image (optional)
   - `VPC_ID`: VPC ID for the build environment
   - `SUBNET_ID`: Subnet ID for the build environment
   - `SECURITY_GROUP_ID`: Security Group ID for the build environment
   - `REGION`: Huawei Cloud region to build the image in

### Using the Jenkins Pipeline

The pipeline includes the following stages:
1. **Validate Parameters** - Validates input parameters and sets image name with timestamp
2. **Checkout Code** - Gets the latest code from repository
3. **Validate Packer Template** - Validates the Packer configuration
4. **Prepare Hardening Configuration** - Adjusts hardening based on selected level
5. **Build Hardened Image** - Builds the hardened image using Packer
6. **Security Verification** - Runs additional security checks on the image
7. **Cleanup** - Cleans up temporary files

### Jenkins Docker Agent

For containerized builds, use the provided Dockerfile:

```bash
# Build the Jenkins agent image
docker build -f Dockerfile.jenkins -t huawei-cloud-hardened-jenkins-agent .

# Run the Jenkins agent
docker run -d --name hardened-jenkins-agent huawei-cloud-hardened-jenkins-agent
```

### Hardening Levels

The pipeline supports three levels of hardening:

- **Minimal**: Basic security hardening with minimal service disruptions
- **Standard**: Full CIS benchmark compliance (default)
- **Strict**: Enhanced security settings with additional restrictions

## Security Compliance

This build implements recommendations from:
- CIS Red Hat Enterprise Linux 7 Benchmark v2.2.0
- CIS Ubuntu Linux 18.04 LTS Benchmark v2.0.1

The system undergoes a security audit using Lynis during the build process to verify hardening measures.

## Post-Deployment Recommendations

1. **Change Default Credentials**: Update any default passwords immediately
2. **Network Configuration**: Configure security groups and network ACLs appropriately
3. **Centralized Logging**: Set up log forwarding to your SIEM if required
4. **Vulnerability Scanning**: Perform a security scan after deployment
5. **Custom Applications**: Apply security hardening to any additional software installed

## Security Checklist

A security checklist is created at `/root/security-checklist.txt` in the final image with:
- System information
- Enabled security features
- Post-deployment recommendations
- Audit status

## Customization

You can customize the hardening by modifying:
- `scripts/cis-hardening.sh` - Core CIS hardening configurations
- `scripts/security-config.sh` - Additional security settings
- Variables in the `.pkr.hcl` files

## Troubleshooting

- If build fails during security audit, check the Lynis report at `/tmp/lynis-report.txt`
- Verify that your Huawei Cloud credentials have permissions to create images
- Ensure network settings (VPC, subnet, security group) are correctly specified
- Check that the source image IDs are available in your region
- For Jenkins pipeline issues, check the build logs for detailed error messages
- If using strict hardening, verify that applications are compatible with enhanced security settings

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
   docker run -d --name huawei-cloud-agent --add-host jenkins-master:172.30.0.49 huawei-cloud-hardened-jenkins-agent
   ```
   - Or use host networking mode if appropriate:
   ```bash
   docker run -d --name huawei-cloud-agent --network host huawei-cloud-hardened-jenkins-agent
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