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

# Shutdown script to upload logs
mkdir -p /opt/scripts
cat >/opt/scripts/upload-logs.sh <<'EOF'
#!/bin/bash
BUCKET_NAME="${BUCKET_NAME}"
aws s3 cp /var/log/cloud-init.log s3://$BUCKET_NAME/system/cloud-init.log
aws s3 cp /opt/app/target/*.log s3://$BUCKET_NAME/app/logs/ || true
EOF





chmod +x /opt/scripts/upload-logs.sh

# Hook script at shutdown
cat >/etc/systemd/system/upload-logs.service <<EOF
[Unit]
Description=Upload Logs to S3 on Shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/opt/scripts/upload-logs.sh

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

systemctl enable upload-logs.service
