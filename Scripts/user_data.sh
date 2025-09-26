#!/bin/bash
set -e

# ----------------------------------------------------------------------
# 1. Install Dependencies
# ----------------------------------------------------------------------
apt-get update -y
apt-get install -y awscli openjdk-21-jdk maven git

# ----------------------------------------------------------------------
# 2. Setup and Build Application
# ----------------------------------------------------------------------
mkdir -p /opt/app
cd /opt/app
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops.git src || (cd src && git pull)
cd src
mvn clean package -DskipTests
cp target/*.jar /opt/app/app.jar

# ----------------------------------------------------------------------
# 3. Setup Systemd Service for Application
# ----------------------------------------------------------------------
mkdir -p /var/log/app

# IMPORTANT: Redirecting application output to a log file for later upload.
cat >/etc/systemd/system/parcel-app.service <<SERVICE
[Unit]
Description=Parcel App
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/java -jar /opt/app/app.jar --server.port=80 > /var/log/app/app.log 2>&1
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable parcel-app
systemctl start parcel-app

# ----------------------------------------------------------------------
# 4. Create Shutdown Script for Log Upload
# ----------------------------------------------------------------------

cat <<'EOF' > /usr/local/bin/upload-logs.sh
#!/bin/bash
set -x
exec >> /var/log/upload-logs-debug.log 2>&1

# Terraform will inject the bucket name into this variable.
LOG_BUCKET_NAME="${bucket_name}"
LOG_DIR="/var/log"

# Getting runtime data (instance ID, timestamp) with proper escaping.
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "[$TIMESTAMP] Starting log upload from $INSTANCE_ID to $LOG_BUCKET_NAME"

# Uploading logs to S3. Using a simple naming convention.
aws s3 cp "$LOG_DIR/app/app.log" "s3://$LOG_BUCKET_NAME/app/logs/$INSTANCE_ID-app-$TIMESTAMP.log" || true
aws s3 cp "$LOG_DIR/cloud-init.log" "s3://$LOG_BUCKET_NAME/system-logs/$INSTANCE_ID-cloud-init-$TIMESTAMP.log" || true
aws s3 cp "$LOG_DIR/syslog" "s3://$LOG_BUCKET_NAME/system-logs/$INSTANCE_ID-syslog-$TIMESTAMP.log" || true

echo "[$TIMESTAMP] Upload finished"
EOF

chmod +x /usr/local/bin/upload-logs.sh

# ----------------------------------------------------------------------
# 5. Create Systemd Service for Shutdown Hook
# ----------------------------------------------------------------------

cat <<EOF > /etc/systemd/system/upload-logs.service
[Unit]
Description=Upload logs to S3 on shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/upload-logs.sh
RemainAfterExit=true

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

systemctl daemon-reload
systemctl enable upload-logs.service