# Multi-Tier Enterprise Application Deployment

![Vagrant](https://img.shields.io/badge/Infrastructure-Vagrant-1563FF?style=for-the-badge&logo=vagrant&logoColor=white)
![VirtualBox](https://img.shields.io/badge/Hypervisor-VirtualBox-2196F3?style=for-the-badge&logo=virtualbox&logoColor=white)
![Nginx](https://img.shields.io/badge/Proxy-Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)
![Tomcat](https://img.shields.io/badge/Server-Apache%20Tomcat-F8DC75?style=for-the-badge&logo=apache-tomcat&logoColor=black)
![MariaDB](https://img.shields.io/badge/Database-MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![RabbitMQ](https://img.shields.io/badge/Messaging-RabbitMQ-FF6600?style=for-the-badge&logo=rabbitmq&logoColor=white)

## Project Overview

This project simulates a real-world, on-premise enterprise environment by deploying a complex, multi-tier Java application across a distributed cluster of Virtual Machines. 

The architecture decouples services into dedicated nodes to ensure scalability and isolation. The infrastructure is provisioned using **Vagrant**, allowing for reproducible, single-command deployment of the entire stack.

## Architecture & Services

The stack consists of 5 dedicated Virtual Machines, networked via a private subnet (`192.168.56.0/24`).

| VM Name | IP Address      | OS Distribution   | Role & Service                  |
|:--------|:----------------|:------------------|:--------------------------------|
| **web01** | `192.168.56.11` | Ubuntu 22.04 LTS  | **Reverse Proxy (Nginx):** Handles client requests and routes traffic to the application server. |
| **app01** | `192.168.56.12` | CentOS Stream 9   | **Application Server (Tomcat):** Hosts the Java WAR artifact and executes business logic. |
| **rmq01** | `192.168.56.13` | CentOS Stream 9   | **Message Broker (RabbitMQ):** Manages asynchronous task queues and background jobs. |
| **mc01** | `192.168.56.14` | CentOS Stream 9   | **Caching (Memcached):** Stores frequently accessed data to reduce database load. |
| **db01** | `192.168.56.15` | CentOS Stream 9   | **Database (MariaDB):** Relational database storage for persistent application data. |

## Infrastructure Automation with Vagrant

This project utilizes **Vagrant** as an Infrastructure-as-Code (IaC) tool to overcome the challenges of manual environment setup. 

### Why Vagrant?

1.  **Reproducibility:** The entire environment configuration is defined in a single `Vagrantfile`. This eliminates the "it works on my machine" problem, ensuring that the development environment is identical to the production-like simulation.
2.  **Automated Provisioning:** Instead of manually installing OSs and configuring networks for 5 different servers, Vagrant automates the VM creation, IP assignment, and resource allocation (RAM/CPU) dynamically.
3.  **Isolation:** Each service runs in its own isolated VM (Guest OS) on top of the host Hypervisor (VirtualBox). This prevents dependency conflicts and mimics a physical datacenter architecture.
4.  **Efficiency:** The environment can be brought up, destroyed, and rebuilt with simple CLI commands, significantly reducing the time required for infrastructure management.

## Prerequisites

* **VirtualBox**: Hypervisor for running the VMs.
* **Vagrant**: Tool for building and managing virtual machine environments.
* **Git**: Version control system.

## Getting Started

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/Dodo-hishmat/Multi-Tier-Java-Application-Using-Vagrant-Virtual-Machines/tree/main.git
    cd Multi-Tier-Java-Application-Using-Vagrant-Virtual-Machines
    ```

2.  **Provision the Infrastructure**
    Initialize and start all virtual nodes. This process will download the necessary Base Boxes (CentOS/Ubuntu) and configure the private network.
    ```bash
    vagrant up
    ```

3.  **Verify Status**
    Ensure all nodes are running.
    ```bash
    vagrant status
    ```

4.  **Access Nodes**
    To configure a specific service (e.g., the Database node), SSH into the instance:
    ```bash
    vagrant ssh db01
    ```

## Network Configuration Details

The application is configured to communicate internally using the following endpoints:

* **Database URL:** `jdbc:mysql://192.168.56.15:3306/appdb`
* **Memcached Host:** `192.168.56.14:11211`
* **RabbitMQ Host:** `192.168.56.13:5672`
* **Tomcat Application:** Accessible via Nginx at `http://192.168.56.11`

---
---

## Provisioning Guide (Step-by-Step)

Since the VMs are provisioned with a minimal OS, follow these manual steps to configure each tier.

### Step 1: Database Tier (db01)
**Role:** Stores persistent data (Users, Products).
* SSH into the node: `vagrant ssh db01`

```bash
# 1. Install & Start MariaDB
sudo dnf install mariadb-server -y
sudo systemctl start mariadb && sudo systemctl enable mariadb

# 2. Configure Database & User
# Creates 'appdb' and user 'appuser' with password '******'
sudo mysql -u root <<EOF
CREATE DATABASE appdb;
CREATE USER 'appuser'@'%' IDENTIFIED BY 'app123';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
EOF

# 3. Configure Firewall (Port 3306)
sudo dnf install firewalld -y && sudo systemctl start firewalld
sudo firewall-cmd --add-port=3306/tcp --permanent
sudo firewall-cmd --reload
exit
```
### Step 2: Cache Tier (mc01)
**Role:** Caches frequent database queries to reduce load.
* SSH into the node: vagrant ssh mc01

```bash
# 1. Install Memcached
sudo dnf install memcached -y

# 2. Allow Remote Connections
# Change listener from 127.0.0.1 to 0.0.0.0
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/sysconfig/memcached

# 3. Start Service & Firewall (Port 11211)
sudo systemctl start memcached && sudo systemctl enable memcached
sudo dnf install firewalld -y && sudo systemctl start firewalld
sudo firewall-cmd --add-port=11211/tcp --permanent
sudo firewall-cmd --reload
exit
```
### Step 3: Message Broker Tier (rmq01)
**Role**: Handles asynchronous messaging between services.
*SSH into the node: vagrant ssh rmq01

```bash
# 1. Install Repositories (Erlang & RabbitMQ)
curl -s [https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh](https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh) | sudo bash
curl -s [https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh](https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh) | sudo bash

# 2. Install & Start RabbitMQ
sudo dnf install rabbitmq-server -y
sudo systemctl start rabbitmq-server && sudo systemctl enable rabbitmq-server

# 3. Enable Dashboard & Remote Access
sudo rabbitmq-plugins enable rabbitmq_management
# Allow 'guest' user to login remotely
echo '[{rabbit, [{loopback_users, []}]}].' | sudo tee /etc/rabbitmq/rabbitmq.config
sudo systemctl restart rabbitmq-server

# 4. Configure Firewall (Ports 5672 & 15672)
sudo dnf install firewalld -y && sudo systemctl start firewalld
sudo firewall-cmd --add-port=5672/tcp --permanent
sudo firewall-cmd --add-port=15672/tcp --permanent
sudo firewall-cmd --reload
exit

```
### Step 4: Application Tier (app01)
**Role**: Runs the Java Application (Tomcat).
*SSH into the node: vagrant ssh app01
```bash
# A. Install Dependencies (Java 11, Maven, Git)
sudo dnf install java-11-openjdk-devel git maven mysql -y

# B. Install Apache Tomcat 9
cd /tmp
wget [https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz](https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz)
tar -xzvf apache-tomcat-9.0.75.tar.gz
# Setup Installation Directory
sudo rm -rf /usr/local/tomcat && sudo mkdir /usr/local/tomcat
sudo mv apache-tomcat-9.0.75/* /usr/local/tomcat/
# Create User & Fix Permissions
sudo useradd --home-dir /usr/local/tomcat --shell /sbin/nologin tomcat
sudo chown -R tomcat:tomcat /usr/local/tomcat
sudo chmod +x /usr/local/tomcat/bin/*.sh

# C. Build & Deploy
cd ~
git clone [https://github.com/abdelrahmanonline4/sourcecodeseniorwr.git](https://github.com/abdelrahmanonline4/sourcecodeseniorwr.git)
cd sourcecodeseniorwr

# Update application.properties with our VM IPs
sed -i 's/jdbc.url=.*/jdbc.url=jdbc:mysql:\/\/192.168.56.15:3306\/appdb?useUnicode=true\&characterEncoding=utf8\&useSSL=false/' src/main/resources/application.properties
sed -i 's/memcached.active.host=.*/memcached.active.host=192.168.56.14/' src/main/resources/application.properties
sed -i 's/rabbitmq.address=.*/rabbitmq.address=192.168.56.13/' src/main/resources/application.properties

# Build Artifact
mvn install

# Deploy to Tomcat (ROOT.war)
sudo systemctl stop tomcat
sudo rm -rf /usr/local/tomcat/webapps/ROOT*
sudo cp target/*.war /usr/local/tomcat/webapps/ROOT.war
sudo systemctl start tomcat

# D. Seed Database (Fixes Login Issue)
# Inject initial data to create 'admin_vp' user
mysql -u appuser -papp123 -h 192.168.56.15 appdb < src/main/resources/db_backup.sql
exit

```
## Step 5: Web Tier (web01)
**Role**: Reverse Proxy & SSL Termination.
*SSH into the node: vagrant ssh web01

```bash
# 1. Install Nginx
sudo apt update && sudo apt install nginx -y

# 2. Create Self-Signed Certificate
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=EG/ST=Cairo/L=Cairo/O=DevOps/OU=IT/CN=192.168.56.11"

# 3. Configure Nginx (Reverse Proxy)
# (Overwrite /etc/nginx/sites-available/default with the proxy config)
# Ensure to set proxy_pass to [http://192.168.56.12:8080](http://192.168.56.12:8080)

# 4. Restart Nginx
sudo systemctl restart nginx
exit
```
---
## Access Information

Once the deployment is complete, you can access the application and services via the following endpoints:

| Service | URL / Credentials | Description |
|:---|:---|:---|
| **Web Application** | **`https://192.168.56.11`** | Main Entry Point (Nginx with SSL) |
| **App Credentials** | User: `*******`<br>Pass: `********` | Admin Dashboard Login |
| **RabbitMQ Console** | `http://192.168.56.13:15672` | Message Broker Dashboard |
| **RabbitMQ Creds** | User: `*****`<br>Pass: `*****` | Default Credentials |
| **Tomcat Direct** | `http://192.168.56.12:8080` | Backend Server (Direct Access) |

---

## Troubleshooting
* Tomcat 203/EXEC Error: Caused by missing executable permissions. Solved by running chmod +x /usr/local/tomcat/bin/*.sh.

* Login Failed / Invalid: Caused by empty database tables. Solved by injecting db_backup.sql from the source code into MariaDB.

* Browser Privacy Warning: Caused by the self-signed SSL certificate. It is safe to click "Advanced -> Proceed" for this local lab.
