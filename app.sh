#!/bin/bash

# Check if a package is installed
is_package_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

# Install Red Hat specific packages
install_redhat_packages() {
  sudo yum update -y
  sudo yum install -y wget unzip

  if ! is_package_installed "java-11-openjdk-devel"; then
    sudo yum install -y java-11-openjdk-devel
    echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" >> ~/.bashrc
  fi

  if ! is_package_installed "java-1.8.0-openjdk-devel"; then
    sudo yum install -y java-1.8.0-openjdk-devel
    echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk" >> ~/.bashrc
  fi

  if ! is_package_installed "java-17-openjdk-devel"; then
    sudo yum install -y java-17-openjdk-devel
    echo "export SONAR_JAVA_PATH=/usr/lib/jvm/java-17-openjdk" >> ~/.bashrc
  fi

  source ~/.bashrc

  if ! is_package_installed "git"; then
    sudo yum install -y git
  fi

  if [ ! -d ~/github ]; then
    mkdir ~/github
    cd ~/github && git config --global credential.helper 'cache --timeout=3600' && git clone https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/movvamanoj/movvaweb.git
  fi

  if ! is_package_installed "maven"; then
    sudo yum install -y maven
  fi

  if ! is_package_installed "firewalld"; then
    sudo yum install -y firewalld
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
    sudo systemctl daemon-reload
  fi

  if ! sudo firewall-cmd --list-ports | grep -q "8080/tcp"; then
    sudo firewall-cmd --permanent --zone=public --add-port=8080/tcp
  fi

  if ! sudo firewall-cmd --list-ports | grep -q "8888/tcp"; then
    sudo firewall-cmd --permanent --zone=public --add-port=8888/tcp
  fi

  if ! sudo firewall-cmd --list-ports | grep -q "9000/tcp"; then
    sudo firewall-cmd --permanent --zone=public --add-port=9000/tcp
  fi

  if ! sudo firewall-cmd --list-ports | grep -q "9001/tcp"; then
    sudo firewall-cmd --permanent --zone=public --add-port=9001/tcp
  fi

  sudo firewall-cmd --reload

  if ! is_package_installed "yum-utils"; then
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
  fi

  if ! is_package_installed "docker-ce"; then
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    sudo systemctl start docker
    sudo systemctl enable docker
  fi

  docker version

  if ! is_package_installed "jenkins"; then
    sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
    sudo yum install -y jenkins
    sudo chown -R jenkins:jenkins /var/lib/jenkins
    sudo chmod -R 755 /var/lib/jenkins
    sudo usermod -aG docker jenkins
    sudo chown jenkins:jenkins /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar
    sudo chmod 755 /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar
    sudo systemctl daemon-reload
    sudo systemctl start jenkins
    sudo systemctl enable jenkins

    echo "Waiting for Jenkins to start..."
    while ! sudo systemctl is-active --quiet jenkins; do
      sleep 5
    done

    jenkins_version=$(sudo systemctl status jenkins | grep -oP 'Jenkins Continuous Integration Server, version \K(\d+\.\d+\.\d+)')
    echo "Jenkins version: $jenkins_version"

    jenkins_password=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)

    sudo java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ install-plugin --all

    sudo java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ -auth admin:${JENKINS_PASSWORD} create-user ${JENKINS_USERNAME} ${JENKINS_PASSWORD} --full-name ${JENKINS_FULL_NAME} --email ${JENKINS_EMAIL}

    sudo java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ restart

    sleep 30

    echo "Jenkins installed successfully."
  fi
}

# Main script execution
if [[ -f /etc/redhat-release ]]; then
  install_redhat_packages
else
  echo "Unsupported operating system."
  exit 1
fi
