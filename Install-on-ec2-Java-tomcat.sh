#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "--- Starting System Update and Dependency Install ---"
sudo apt update -y && sudo apt upgrade -y
sudo apt install ruby wget default-jdk -y

# --- Section 1: AWS CodeDeploy Agent ---
echo "--- Installing AWS CodeDeploy Agent ---"
cd /home/ubuntu
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo service codedeploy-agent start

# --- Section 2: Apache Tomcat Setup ---
echo "--- Configuring Apache Tomcat ---"

# Create tomcat user if it doesn't exist
if ! id "tomcat" &>/dev/null; then
    sudo useradd -m -d /opt/tomcat -U -s /bin/false tomcat
fi

# Download and Extract Tomcat
wget https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.24/bin/apache-tomcat-10.1.24.tar.gz -O /tmp/tomcat-10.tar.gz
sudo mkdir -p /opt/tomcat
sudo tar -xzvf /tmp/tomcat-10.tar.gz --strip-components=1 -C /opt/tomcat
sudo chown -R tomcat:tomcat /opt/tomcat

# Create Systemd Service File
echo "--- Creating Tomcat Systemd Service ---"
sudo bash -c 'cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment=JAVA_HOME=/usr/lib/jvm/default-java
Environment=CATALINA_PID=/opt/tomcat/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

ExecReload=/bin/kill \$MAINPID
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF'

# --- Section 3: Finalize and Start ---
echo "--- Starting Services ---"
sudo systemctl daemon-reload
sudo systemctl enable --now tomcat

echo "--- Status Check ---"
sudo service codedeploy-agent status --no-pager
sudo systemctl status tomcat --no-pager

echo "Setup Complete!"