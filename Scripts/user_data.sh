#!/bin/bash
set -e

# Install dependencies
apt-get update -y
apt-get install -y awscli openjdk-21-jdk maven git

# Setup app
mkdir -p /opt/app
cd /opt/app
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops.git src || (cd src && git pull)
cd src
mvn clean package -DskipTests
cp target/*.jar /opt/app/app.jar

# Setup App log
mkdir -p /var/log/app
nohup java -jar /opt/app/app.jar > /var/log/app/app.log 2>&1 &

chmod +r /opt/app/target/techeazy-devops-0.0.1-SNAPSHOT.jar

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


# Create log upload script
cat <<EOF > /usr/local/bin/upload-logs.sh
#!/bin/bash
set -x
exec >> /var/log/upload-logs-debug.log 2>&1
LOG_DIR="/var/log"
BUCKET_NAME="${bucket_name}"

INSTANCE_ID=\$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
TIMESTAMP=\$(date +%Y%m%d-%H%M%S)

echo "[\$TIMESTAMP] Starting log upload"

aws s3 cp \$LOG_DIR/cloud-init.log s3://\${bucket_name}/system-logs/\$${INSTANCE_ID}_cloud-init_\$TIMESTAMP.log
aws s3 cp \$LOG_DIR/syslog s3://\${bucket_name}/system-logs/\$${INSTANCE_ID}_syslog_\$TIMESTAMP.log
aws s3 cp \$LOG_DIR/app/app.log s3://\${bucket_name}/app/logs/\$${INSTANCE_ID}_app_\$TIMESTAMP.log

echo "[\$TIMESTAMP] Upload finished"
EOF

chmod +x /usr/local/bin/upload-logs.sh


# Create systemd service for shutdown log upload
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
