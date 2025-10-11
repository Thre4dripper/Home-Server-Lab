---
name: "LocalStack"
category: "🛠️ Development & DevOps"
purpose: "AWS Cloud Emulation"
description: "Easy-to-use test/mocking framework for developing Cloud applications locally"
icon: "☁️"
features:
  - "Local AWS services emulation"
  - "Development and testing platform"
  - "Cloud dashboard integration"
resource_usage: "~500MB RAM"
---

# LocalStack - AWS Cloud Emulation Platform

![LocalStack](https://localstack.cloud/images/localstack-readme-banner.svg)

LocalStack provides an easy-to-use test/mocking framework for developing Cloud applications. This setup includes both Community and Pro versions with cloud dashboard integration.

## 🚀 Quick Start

### LocalStack Pro (Recommended)
1. **Set up LocalStack Pro**:
   ```bash
   ./setup-pro.sh
   ```

### LocalStack Community
1. **Set up LocalStack Community**:
   ```bash
   ./setup-community.sh
   ```

2. **Access LocalStack**:
   - **LocalStack Gateway**: http://localhost:4566
   - **Cloud Dashboard**: https://app.localstack.cloud (Pro only)
   - **Health Check**: http://localhost:4566/_localstack/health

## ⚙️ Configuration

### Environment Variables (.env)

| Variable | Description | Default | Pro Only |
|----------|-------------|---------|----------|
| `LOCALSTACK_AUTH_TOKEN` | Authentication token for Pro features | Required for Pro | ✅ |
| `LOCALSTACK_WEB_UI` | Enable Web UI / Cloud Dashboard | `1` | ✅ |
| `DEBUG` | Enable debug logging | `0` | ❌ |
| `PERSISTENCE` | Enable data persistence across restarts | `1` | ✅ |

### Versions Available

- **`docker-compose.pro.yml`**: Pro version with all features
- **`docker-compose.community.yml`**: Community version (free)

## 📁 Directory Structure

```
localstack/
├── docker-compose.pro.yml         # Pro version
├── docker-compose.community.yml   # Community version
├── .env                          # Configuration
├── .env.example                  # Configuration template
├── setup-pro.sh                 # Pro setup script
├── setup-community.sh           # Community setup script
├── README.md                     # This file
└── volume/                       # LocalStack data (persistent)
```

## 🔧 Management

### Using Docker Compose

```bash
# Start LocalStack Pro
docker compose -f docker-compose.pro.yml up -d

# Start LocalStack Community
docker compose -f docker-compose.community.yml up -d

# Stop LocalStack
docker compose -f docker-compose.pro.yml down
# OR
docker compose -f docker-compose.community.yml down

# View logs
docker compose -f docker-compose.pro.yml logs -f

# Check status
docker compose -f docker-compose.pro.yml ps
```

### AWS CLI Configuration

Set up AWS CLI to use LocalStack:

```bash
# Configure AWS CLI
aws configure --profile localstack
# AWS Access Key ID: test
# AWS Secret Access Key: test
# Default region: us-east-1
# Default output format: json

# Use LocalStack endpoint
aws --profile localstack --endpoint-url=http://localhost:4566 s3 ls
```

## 🌟 Features

### Pro Features (Requires Auth Token)
- ✅ **Cloud Dashboard Integration** - Monitor your LocalStack instance
- ✅ **Data Persistence** - Survive container restarts
- ✅ **Advanced Services** - Full AWS service emulation
- ✅ **Team Collaboration** - Share configurations
- ✅ **Enhanced Performance** - Optimized for production workloads

### Community Features
- ✅ **Core AWS Services** - S3, Lambda, DynamoDB, etc.
- ✅ **Local Development** - Test AWS applications locally
- ✅ **CI/CD Integration** - Perfect for automated testing
- ✅ **Free & Open Source** - No limits for basic usage

## 🔒 Security Notes

- LocalStack runs on `127.0.0.1` (localhost only) for security
- Pro features require valid authentication token
- Data persisted in `./volume` directory
- No real AWS charges - everything is emulated locally

## 🛠️ Troubleshooting

### Common Issues

1. **Auth Token Error**:
   ```bash
   # Get token from: https://app.localstack.cloud
   # Add to .env: LOCALSTACK_AUTH_TOKEN=ls-xxx...
   ```

2. **Port Conflicts**:
   ```bash
   # Check what's using port 4566
   lsof -i :4566
   ```

3. **Container Issues**:
   ```bash
   # Reset completely
   docker compose down
   sudo rm -rf volume/*
   docker compose up -d
   ```

### Health Check

```bash
# Check LocalStack health
curl http://localhost:4566/_localstack/health

# Check available services
curl http://localhost:4566/_localstack/health | jq .services
```

## 📚 Documentation

- **LocalStack Docs**: https://docs.localstack.cloud
- **AWS CLI Reference**: https://docs.aws.amazon.com/cli/
- **LocalStack Pro**: https://localstack.cloud/pricing
- **Community Support**: https://github.com/localstack/localstack

## 🤝 Integration

This LocalStack setup integrates with the Home Server Lab ecosystem:

- **Service Discovery**: Accessible at `localhost:4566`
- **Persistence**: Data stored in `./volume`
- **Logging**: Centralized with other services
- **Monitoring**: Health checks and status reporting