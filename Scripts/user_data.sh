#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# 1) Basic updates
apt-get update -y
apt-get upgrade -y

# 2) Tools
apt-get install -y curl gnupg2 software-properties-common unzip git wget

# 3) Install Java 21 + Maven
# Try apt install openjdk-21-jdk (if available). If not, install Amazon Corretto 21.
if apt-cache policy openjdk-21-jdk | grep -q 'Candidate:' ; then
  apt-get install -y openjdk-21-jdk maven
else
  # Install Amazon Corretto 21 (x64)
  # Download Corretto 21 tar and use alternatives
  CORRETTO_URL="https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.tar.gz"
  mkdir -p /opt/java
  curl -L "$CORRETTO_URL" -o /tmp/corretto21.tar.gz
  tar -xzf /tmp/corretto21.tar.gz -C /opt/java
  CORRETTO_DIR=$(ls -1 /opt/java | head -n1)
  update-alternatives --install /usr/bin/java java /opt/java/${CORRETTO_DIR}/bin/java 20000
  update-alternatives --install /usr/bin/javac javac /opt/java/${CORRETTO_DIR}/bin/javac 20000
  # Install maven from apt
  apt-get install -y maven
fi

# Verify java
java -version || true

# 4) Prepare application directory
mkdir -p /opt/app
chown ubuntu:ubuntu /opt/app

# 5) Clone the GitHub repo (public)
# If you prefer to use local JAR instead of git, skip this clone and copy parcel.jar into /opt/app
su - ubuntu -c "git clone https://github.com/Trainings-TechEazy/test-repo-for-devops.git /opt/app || (cd /opt/app && git pull)"

# 6) Build with maven (skip tests to speed up)
cd /opt/app || exit 1
su - ubuntu -c "cd /opt/app && mvn clean package -DskipTests"

# 7) Find built JAR (adjust if your artifactId or version differs)
JAR_FILE=$(ls /opt/app/target/*.jar | grep -v 'original' | head -n1)
if [ -z "$JAR_FILE" ]; then
  echo "ERROR: built JAR not found in /opt/app/target"
  exit 1
fi
echo "Found JAR: $JAR_FILE"
cp "$JAR_FILE" /opt/app/app.jar
chown root:root /opt/app/app.jar
chmod 755 /opt/app/app.jar

# 8) Create systemd service so the application runs on boot and binds to port 80
cat >/etc/systemd/system/parcel-app.service <<'SERVICE'
[Unit]
Description=Parcel Java App (techeazy)
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/app
ExecStart=/usr/bin/java -jar /opt/app/app.jar --server.port=80
Restart=on-failure
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE

# 9) Start service
systemctl daemon-reload
systemctl enable parcel-app.service
systemctl start parcel-app.service

# 10) Allow some time and check status (logs are viewable via journalctl)
sleep 5
systemctl status parcel-app.service --no-pager

# 11) Write a small health check file with the public IP (cloud-init sets metadata later) - optional
echo "Bootstrap finished at $(date -u)" >/var/tmp/bootstrap_finished
