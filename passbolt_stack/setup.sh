#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Passbolt setup...${NC}"

# Generate SSL certificates
echo -e "${YELLOW}Generating SSL certificates...${NC}"
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/private.key \
  -out ssl/certificate.crt \
  -subj "/C=FR/ST=Paris/L=Paris/O=YourCompany/CN=passbolt.your-domain.com"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate SSL certificates${NC}"
    exit 1
fi

echo -e "${GREEN}SSL certificates generated successfully${NC}"

# Start containers
echo -e "${YELLOW}Starting Docker containers...${NC}"
docker compose up -d

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start containers${NC}"
    exit 1
fi

echo -e "${GREEN}Containers started successfully${NC}"

# Wait for containers to be ready
echo -e "${YELLOW}Waiting for containers to be ready (30 seconds)...${NC}"
sleep 30

# Check if database is ready
echo -e "${YELLOW}Checking database connection...${NC}"
db_ready=0
for i in {1..10}; do
    if docker exec passbolt_db mysqladmin ping -uroot -pyour_secure_root_db_password --silent; then
        db_ready=1
        break
    fi
    echo -e "${YELLOW}Waiting for database to be ready... (attempt $i/10)${NC}"
    sleep 10
done

if [ $db_ready -eq 0 ]; then
    echo -e "${RED}Database is not ready after multiple attempts${NC}"
    exit 1
fi

echo -e "${GREEN}Database is ready${NC}"

# Initialize Passbolt
echo -e "${YELLOW}Initializing Passbolt...${NC}"
docker exec -it passbolt_app su -m -c "/usr/bin/php /usr/share/php/passbolt/bin/cake passbolt install --no-admin" -s /bin/sh www-data

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to initialize Passbolt${NC}"
    exit 1
fi

echo -e "${GREEN}Passbolt initialized successfully${NC}"

# Create admin user
echo -e "${YELLOW}Creating admin user...${NC}"
docker exec -it passbolt_app su -m -c "/usr/bin/php /usr/share/php/passbolt/bin/cake passbolt register_user \
  --username admin \
  --first-name Admin \
  --last-name User \
  --email your_email@gmail.com" -s /bin/sh www-data

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create admin user${NC}"
    exit 1
fi

echo -e "${GREEN}Admin user created successfully${NC}"

# Test email configuration
echo -e "${YELLOW}Testing email configuration...${NC}"
docker exec -it passbolt_app su -m -c "/usr/bin/php /usr/share/php/passbolt/bin/cake passbolt send_test_email --recipient=your_email@gmail.com" -s /bin/sh www-data

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Email test sent successfully! Check your inbox.${NC}"
else
    echo -e "${RED}Email test failed. Check your SMTP configuration.${NC}"
fi

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}Passbolt setup completed successfully!${NC}"
echo -e "${GREEN}Access your instance at: https://passbolt.your-domain.com${NC}"
echo -e "${YELLOW}Check your email for the admin registration link.${NC}"
echo -e "${GREEN}=================================================${NC}"