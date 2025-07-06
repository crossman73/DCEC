# NAS Docker Environment Setup Guide

## Introduction
This guide provides step-by-step instructions for setting up a NAS Docker environment. It covers the installation of Docker, configuration of services, and management of the environment.

## Prerequisites
- A NAS device with SSH access.
- Basic knowledge of command-line operations.
- Ensure that your NAS has sufficient resources (CPU, RAM, and storage) to run Docker containers.

## Step 1: Access Your NAS
1. Open a terminal on your local machine.
2. SSH into your NAS device:
   ```
   ssh username@your_nas_ip
   ```

## Step 2: Clone the Repository
Clone the repository containing the setup scripts and configuration files:
```
git clone https://your_repository_url/nas-docker-setup.git
cd nas-docker-setup
```

## Step 3: Run the Setup Script
Execute the setup script to configure the NAS Docker environment:
```
bash scripts/nas-setup-complete.sh
```
- This script will create the necessary directory structure, install Docker if not already installed, and set up configuration files.

## Step 4: Copy Configuration Files
After running the setup script, copy your `docker-compose.yml` and `.env` files to the base directory:
```
cp docker/docker-compose.yml /volume1/docker/dev/
cp .env /volume1/docker/dev/
```

## Step 5: Start Docker Services
You can start the Docker services using the following command:
```
cd /volume1/docker/dev
docker-compose up -d
```

## Step 6: Perform Health Checks
After starting the services, run health checks to ensure everything is operational:
```
bash scripts/health-check.sh
```

## Step 7: Access Services
Once the services are running, you can access them via the following URLs (replace `192.168.0.5` with your NAS IP):
- n8n: http://192.168.0.5:31001
- Gitea: http://192.168.0.5:3000
- VS Code: http://192.168.0.5:8484
- Portainer: http://192.168.0.5:9000

## Step 8: Management Scripts
You can manage your Docker environment using the provided scripts:
- Start services: `bash scripts/start.sh`
- Stop services: `bash scripts/stop.sh`
- Restart services: `bash scripts/restart.sh`
- Check status: `bash scripts/status.sh`
- View logs: `bash scripts/logs.sh <service_name>`
- Backup: `bash scripts/backup.sh`

## Conclusion
Your NAS Docker environment is now set up and ready for use. For troubleshooting tips, refer to the `docs/troubleshooting.md` file. For further information on accessing services, check `docs/service-urls.md`.