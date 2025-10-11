# Contributing to Home Server Lab

First off, thank you for considering contributing to Home Server Lab! 🎉 It's people like you that make this project a great resource for the self-hosting community.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Getting Started](#getting-started)
- [Adding New Services](#adding-new-services)
- [Service Standards](#service-standards)
- [Documentation Guidelines](#documentation-guidelines)
- [Testing Guidelines](#testing-guidelines)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)
- [Community](#community)

## 🤝 Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](./CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## 🚀 How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples to demonstrate the steps**
- **Describe the behavior you observed and what behavior you expected**
- **Include details about your configuration and environment**

**Bug Report Template:**
```markdown
**Environment:**
- OS: [e.g., Raspberry Pi OS, Ubuntu 20.04]
- Hardware: [e.g., Raspberry Pi 4 4GB]
- Docker version: [e.g., 20.10.21]
- Service: [e.g., Seafile, Netdata]

**Describe the bug:**
A clear and concise description of what the bug is.

**To Reproduce:**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior:**
A clear and concise description of what you expected to happen.

**Logs:**
```
Include relevant logs from `docker compose logs` or system logs
```

**Additional context:**
Add any other context about the problem here.
```

### 💡 Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested enhancement**
- **Explain why this enhancement would be useful**
- **List some other projects where this enhancement exists** (if applicable)

### 🔧 Adding New Services

We're always looking to expand our collection of self-hosted services! Before adding a new service:

1. **Check if the service is already planned** in our issues
2. **Ensure the service is actively maintained** by its developers
3. **Verify it works well on ARM64** (Raspberry Pi compatibility)
4. **Confirm it's genuinely useful** for home lab environments

## 🏗️ Getting Started

### Prerequisites

- Git installed on your system
- Docker and Docker Compose installed
- Basic understanding of containerization
- Familiarity with YAML and shell scripting

### Development Setup

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/Home-Server-Lab.git
   cd Home-Server-Lab
   ```
3. **Create a new branch** for your feature:
   ```bash
   git checkout -b feature/service-name
   # or
   git checkout -b fix/issue-description
   ```

### Testing Environment

- Test on actual hardware when possible (Raspberry Pi recommended)
- Use virtual machines for initial development
- Test resource consumption and performance
- Verify services work after system reboot

## 📦 Adding New Services

### Service Structure

Each service must follow this standardized structure:

```
service-name/
├── README.md              # Comprehensive service documentation
├── docker-compose.yml     # Main container configuration
├── .env.example          # Configuration template with examples
├── setup.sh              # Automated deployment script
├── .gitignore            # Exclude sensitive data and logs
└── data/                 # Persistent data directory (created by setup)
```

### Step-by-Step Process

1. **Create service directory:**
   ```bash
   mkdir service-name
   cd service-name
   ```

2. **Create docker-compose.yml:**
   - Use official Docker images when available
   - Implement proper health checks
   - Use bind mounts for data persistence
   - Configure resource limits
   - Use internal networks for security

3. **Create .env.example:**
   - Include all configurable parameters
   - Provide sensible defaults
   - Add security warnings for sensitive values
   - Document each variable clearly

4. **Write setup.sh script:**
   - Check for prerequisites
   - Validate configuration
   - Create necessary directories
   - Pull images and start services
   - Provide post-deployment instructions

5. **Create comprehensive README.md** (see Documentation Guidelines)

6. **Create .gitignore:**
   - Exclude `.env` files
   - Exclude `data/` directories
   - Exclude logs and temporary files

### Example Service Template

```yaml
# docker-compose.yml
services:
  service-name:
    image: official/service-name:latest
    container_name: service-name
    restart: unless-stopped
    ports:
      - "${SERVICE_PORT:-8080}:8080"
    volumes:
      - ./data:/app/data
      - ./config:/app/config
    environment:
      - ENV_VAR=${ENV_VAR:-default_value}
    networks:
      - service-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    mem_limit: 512m
    cpus: 0.5

networks:
  service-net:
    driver: bridge
```

## 📏 Service Standards

### Configuration Requirements

- **Environment Variables**: All configuration through `.env` files
- **Data Persistence**: Use bind mounts to `./data/` directory
- **Resource Limits**: Set appropriate memory and CPU limits
- **Health Checks**: Implement proper health check endpoints
- **Security**: No hardcoded passwords or secrets
- **Networking**: Use internal Docker networks when possible

### Performance Requirements

- **ARM64 Compatibility**: Must work on Raspberry Pi 4
- **Resource Efficiency**: Optimize for single-board computers
- **Startup Time**: Services should start within 2 minutes
- **Memory Usage**: Document expected memory consumption
- **Storage**: Minimize disk space requirements

### Security Requirements

- **No Root Privileges**: Avoid running containers as root when possible
- **Secret Management**: Sensitive data only in `.env` files
- **Network Security**: Minimal exposed ports
- **Update Policy**: Use specific version tags, not `latest`
- **Vulnerability Scanning**: Check for known security issues

## 📚 Documentation Guidelines

### README.md Structure

Each service README must include:

```markdown
# Service Name

Brief description of what the service does.

## 🎯 Overview
- Key features
- Use cases
- Benefits

## 🚀 Quick Start
1. Configuration steps
2. Deployment command
3. Access information

## 📋 Configuration
- Environment variables table
- Configuration examples
- Security notes

## 🔧 Management
- Common operations
- Backup procedures
- Troubleshooting

## 🔗 Resources
- Official documentation
- Community resources
```

### Writing Style

- **Clear and Concise**: Use simple, direct language
- **Actionable**: Provide step-by-step instructions
- **Complete**: Include all necessary information
- **Consistent**: Follow established patterns and terminology
- **User-Focused**: Write from the user's perspective

### Code Examples

- **Test All Examples**: Ensure code examples actually work
- **Use Realistic Data**: Provide practical, real-world examples
- **Explain Context**: Add comments explaining complex configurations
- **Format Consistently**: Use proper markdown formatting

## 🧪 Testing Guidelines

### Required Testing

1. **Fresh Installation**: Test on clean system
2. **Configuration Validation**: Test with various configurations
3. **Restart Resilience**: Ensure services survive system reboot
4. **Resource Monitoring**: Monitor CPU, memory, and disk usage
5. **Functionality Testing**: Verify all advertised features work

### Testing Checklist

- [ ] Service starts successfully
- [ ] Web interface accessible (if applicable)
- [ ] Health checks pass
- [ ] Data persists after restart
- [ ] Resource usage within expected limits
- [ ] No errors in logs during normal operation
- [ ] Backup/restore procedures work
- [ ] Documentation is accurate and complete

### Performance Benchmarks

Document the following for each service:

- **Startup Time**: Time from `docker compose up` to healthy
- **Memory Usage**: RAM consumption during normal operation  
- **CPU Usage**: Average CPU utilization
- **Disk Usage**: Storage requirements for application and data
- **Network Usage**: Bandwidth requirements (if significant)

## 📝 Submitting Changes

### Pull Request Process

1. **Update Documentation**: Ensure README and other docs are updated
2. **Test Thoroughly**: Complete all testing requirements
3. **Follow Conventions**: Adhere to established patterns and standards
4. **Describe Changes**: Provide clear description of what was changed and why
5. **Reference Issues**: Link to relevant issues or discussions

### Pull Request Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Service Information
- **Service Name**: 
- **Official Image**: 
- **Resource Requirements**: 
- **Tested On**: [Hardware/OS]

## Testing
- [ ] Fresh installation tested
- [ ] Service starts successfully
- [ ] Web interface accessible
- [ ] Data persistence verified
- [ ] Documentation updated
- [ ] Resource usage documented

## Screenshots (if applicable)
Add screenshots to help explain your changes.

## Additional Notes
Any additional information about the changes.
```

### Commit Message Format

Use clear, descriptive commit messages:

```
type(scope): subject

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Maintenance tasks

**Examples:**
```
feat(seafile): add Seafile Pro configuration with SeaDoc

- Add official Seafile Pro Docker setup
- Include document editing capabilities
- Optimize for Raspberry Pi deployment
- Add comprehensive documentation

Closes #123
```

## 🎨 Style Guidelines

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include error handling with `set -e`
- Add descriptive comments
- Use consistent indentation (2 spaces)
- Validate prerequisites before execution

### Docker Compose

- Use version 3.8+ syntax
- Order sections consistently: services, networks, volumes
- Use environment variables for configuration
- Include resource limits
- Add health checks where applicable

### Documentation

- Use consistent markdown formatting
- Include table of contents for long documents
- Use emoji sparingly and consistently
- Keep line length reasonable (80-120 characters)
- Use relative links for internal references

## 🌟 Recognition

Contributors will be recognized in several ways:

- **Contributors List**: Added to repository contributors
- **Release Notes**: Mentioned in release announcements
- **Special Thanks**: Featured in project documentation
- **Community Badges**: Discord/forum recognition (when available)

## 💬 Community

### Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Documentation**: Check existing docs first
- **Community Forums**: r/selfhosted, r/homelab

### Mentorship

New contributors are welcome! If you're new to:

- **Docker/Containerization**: We can provide guidance
- **Self-Hosting**: Community members are happy to help
- **Open Source**: We'll help you learn the process

Don't hesitate to ask questions in issues or discussions.

## 📞 Contact

- **Maintainer**: [@Thre4dripper](https://github.com/Thre4dripper)
- **Issues**: [GitHub Issues](https://github.com/Thre4dripper/Home-Server-Lab/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Thre4dripper/Home-Server-Lab/discussions)

---

Thank you for contributing to Home Server Lab! Together, we're building an amazing resource for the self-hosting community. 🚀

*"The best way to predict the future is to create it."* - Peter Drucker
