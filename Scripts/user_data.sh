#!/bin/bash
set -e

apt-get update -y
apt-get install -y openjdk-21-jdk maven awscli git

# Setup app
mkdir -p /opt/app
cd /opt/app
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops.git src || (cd src && git pull)
cd src
mvn clean package -DskipTests
cp target/*.jar /opt/app/app.jar

# Systemd service for app
cat >/etc/systemd/system/parcel-app.service <<SERVICE
[Unit]
Description=Parcel App
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/java -jar /opt/app/app.jar --server.port=80
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

systemctl enable parcel-app
systemctl start parcel-app


# ---------- Upload logs on shutdown ----------
# Create shutdown log upload script
cat << 'EOF' > /usr/local/bin/upload-logs.sh
#!/bin/bash
BUCKET_NAME="${bucket_name}"          # Terraform replaces this
INSTANCE_ID=$$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=$$(date +%Y%m%d-%H%M%S)

echo "[$$TIMESTAMP] Uploading logs to $$BUCKET_NAME" >> /var/log/upload-logs-debug.log

aws s3 cp /var/log/cloud-init.log s3://$$BUCKET_NAME/system-logs/$$INSTANCE_ID_cloud-init_$$TIMESTAMP.log >> /var/log/upload-logs-debug.log 2>&1
aws s3 cp /var/log/syslog s3://$$BUCKET_NAME/system-logs/$$INSTANCE_ID_syslog_$$TIMESTAMP.log >> /var/log/upload-logs-debug.log 2>&1
aws s3 cp /var/log/app/app.log s3://$$BUCKET_NAME/app/logs/$$INSTANCE_ID_app_$$TIMESTAMP.log >> /var/log/upload-logs-debug.log 2>&1
EOF

chmod +x /usr/local/bin/upload-logs.sh

# Register systemd shutdown service
cat << EOF > /etc/systemd/system/upload-logs.service
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

systemctl enable upload-logs.service