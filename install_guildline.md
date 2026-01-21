# Hướng Dẫn Cài Đặt Hệ Thống Big Data

## 🎯 Yêu Cầu Hệ Thống

Hệ thống được thiết kế để xử lý **500,000 - 1,000,000 bản ghi/ngày** với các đặc điểm:
- **Peak throughput**: ~100k records/hour (~28 records/second)
- **Average throughput**: ~42k records/hour (~12 records/second)
- **Data size**: ~2GB/ngày (với 1M records × 2KB/record)
- **Storage**: ~60GB/tháng, ~720GB/năm

## 💻 Yêu Cầu Server

### Option 1: Single Node (Development/Testing)

#### Minimum Requirements
- **CPU**: 8 cores (16 threads)
- **RAM**: 32GB
- **Storage**: 500GB SSD
- **Network**: 1Gbps
- **OS**: Ubuntu 20.04 LTS / CentOS 7+

#### Recommended Requirements
- **CPU**: 16 cores (32 threads)
- **RAM**: 64GB
- **Storage**: 1TB SSD + 2TB HDD
- **Network**: 10Gbps
- **OS**: Ubuntu 22.04 LTS

### Option 2: Cluster (Production)

#### Master Node
- **CPU**: 16 cores (32 threads)
- **RAM**: 64GB
- **Storage**: 500GB SSD
- **Network**: 10Gbps
- **Số lượng**: 1 node

#### Worker Nodes
- **CPU**: 16 cores (32 threads)
- **RAM**: 64GB
- **Storage**: 2TB SSD + 4TB HDD
- **Network**: 10Gbps
- **Số lượng**: 2-3 nodes

#### Total Cluster
- **Total CPU**: 48-64 cores
- **Total RAM**: 192-256GB
- **Total Storage**: 6-12TB

## 📦 Cài Đặt Các Công Nghệ

### 1. Java (JDK 8 hoặc 11)

```bash
# Ubuntu
sudo apt update
sudo apt install openjdk-11-jdk -y

# CentOS
sudo yum install java-11-openjdk-devel -y

# Verify
java -version
```

**Yêu cầu**: JDK 8 hoặc 11 (không dùng JDK 17+ vì một số tools chưa hỗ trợ)

### 2. Hadoop (HDFS)

#### Download và Cài Đặt

```bash
# Download Hadoop 3.3.4
cd /opt
sudo wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.4/hadoop-3.3.4.tar.gz
sudo tar -xzf hadoop-3.3.4.tar.gz
sudo mv hadoop-3.3.4 hadoop
sudo chown -R $USER:$USER /opt/hadoop
```

#### Cấu Hình

**core-site.xml**:
```xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
```

**hdfs-site.xml**:
```xml
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>/opt/hadoop/data/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/opt/hadoop/data/datanode</value>
    </property>
</configuration>
```

**mapred-site.xml**:
```xml
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>
```

**yarn-site.xml**:
```xml
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
```

**hadoop-env.sh**:
```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
```

#### Khởi Động

```bash
# Format namenode (chỉ lần đầu)
hdfs namenode -format

# Start HDFS
start-dfs.sh

# Start YARN
start-yarn.sh

# Verify
jps
# Should see: NameNode, DataNode, ResourceManager, NodeManager
```

### 3. HBase

#### Download và Cài Đặt

```bash
# Download HBase 2.5.0
cd /opt
sudo wget https://archive.apache.org/dist/hbase/2.5.0/hbase-2.5.0-bin.tar.gz
sudo tar -xzf hbase-2.5.0-bin.tar.gz
sudo mv hbase-2.5.0 hbase
sudo chown -R $USER:$USER /opt/hbase
```

#### Cấu Hình

**hbase-site.xml**:
```xml
<configuration>
    <property>
        <name>hbase.rootdir</name>
        <value>hdfs://localhost:9000/hbase</value>
    </property>
    <property>
        <name>hbase.cluster.distributed</name>
        <value>false</value>
    </property>
    <property>
        <name>hbase.zookeeper.quorum</name>
        <value>localhost</value>
    </property>
</configuration>
```

**hbase-env.sh**:
```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HBASE_HOME=/opt/hbase
export HBASE_MANAGES_ZK=true
```

#### Khởi Động

```bash
# Start HBase
/opt/hbase/bin/start-hbase.sh

# Verify
/opt/hbase/bin/hbase shell
# In HBase shell: list
```

### 4. Zookeeper (Nếu dùng cluster)

```bash
# Download Zookeeper 3.7.1
cd /opt
sudo wget https://archive.apache.org/dist/zookeeper/zookeeper-3.7.1/apache-zookeeper-3.7.1-bin.tar.gz
sudo tar -xzf apache-zookeeper-3.7.1-bin.tar.gz
sudo mv apache-zookeeper-3.7.1-bin zookeeper
sudo chown -R $USER:$USER /opt/zookeeper

# Cấu hình
cd /opt/zookeeper/conf
cp zoo_sample.cfg zoo.cfg

# Edit zoo.cfg
# dataDir=/opt/zookeeper/data
# clientPort=2181

# Start
/opt/zookeeper/bin/zkServer.sh start
```

### 5. Kafka

#### Download và Cài Đặt

```bash
# Download Kafka 2.13-3.5.0
cd /opt
sudo wget https://archive.apache.org/dist/kafka/3.5.0/kafka_2.13-3.5.0.tgz
sudo tar -xzf kafka_2.13-3.5.0.tgz
sudo mv kafka_2.13-3.5.0 kafka
sudo chown -R $USER:$USER /opt/kafka
```

#### Cấu Hình

**server.properties**:
```properties
broker.id=0
listeners=PLAINTEXT://localhost:9092
log.dirs=/opt/kafka/data
num.network.threads=8
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
num.partitions=12
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
```

#### Khởi Động

```bash
# Start Zookeeper (nếu chưa có)
/opt/kafka/bin/zookeeper-server-start.sh -daemon /opt/kafka/config/zookeeper.properties

# Start Kafka
/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties

# Verify
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092
```

### 6. Spark

#### Download và Cài Đặt

```bash
# Download Spark 3.5.0
cd /opt
sudo wget https://archive.apache.org/dist/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz
sudo tar -xzf spark-3.5.0-bin-hadoop3.tgz
sudo mv spark-3.5.0-bin-hadoop3 spark
sudo chown -R $USER:$USER /opt/spark
```

#### Cấu Hình

**spark-defaults.conf**:
```properties
spark.master                     yarn
spark.executor.memory            4g
spark.executor.cores             4
spark.driver.memory              2g
spark.driver.cores                2
spark.sql.shuffle.partitions     200
spark.sql.streaming.checkpointLocation /checkpoint
spark.streaming.backpressure.enabled true
spark.streaming.kafka.maxRatePerPartition 1000
```

**spark-env.sh**:
```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export SPARK_HOME=/opt/spark
export SPARK_CONF_DIR=$SPARK_HOME/conf
```

#### Verify

```bash
# Test Spark
/opt/spark/bin/spark-submit --version
```

### 7. NiFi

#### Download và Cài Đặt

```bash
# Download NiFi 1.23.0
cd /opt
sudo wget https://archive.apache.org/dist/nifi/1.23.0/nifi-1.23.0-bin.tar.gz
sudo tar -xzf nifi-1.23.0-bin.tar.gz
sudo mv nifi-1.23.0 nifi
sudo chown -R $USER:$USER /opt/nifi
```

#### Cấu Hình

**nifi.properties** (chỉnh sửa các dòng quan trọng):
```properties
nifi.web.http.host=0.0.0.0
nifi.web.http.port=8080
nifi.flowfile.repository.directory=./flowfile_repository
nifi.content.repository.directory.default=./content_repository
nifi.database.directory=./database_repository
nifi.state.management.configuration.file=./conf/state-management.xml
```

#### Khởi Động

```bash
# Start NiFi
/opt/nifi/bin/nifi.sh start

# Access UI: http://localhost:8080/nifi
```

### 8. MySQL

#### Cài Đặt

```bash
# Ubuntu
sudo apt update
sudo apt install mysql-server -y

# CentOS
sudo yum install mysql-server -y
```

#### Cấu Hình

```sql
-- Tạo database
CREATE DATABASE traffic_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Tạo user
CREATE USER 'traffic_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON traffic_db.* TO 'traffic_user'@'localhost';
FLUSH PRIVILEGES;
```

**my.cnf** (tối ưu cho workload):
```ini
[mysqld]
innodb_buffer_pool_size = 8G
innodb_log_file_size = 512M
max_connections = 200
query_cache_size = 256M
query_cache_type = 1
```

### 9. Apache Superset

#### Cài Đặt với Docker (Khuyến nghị)

```bash
# Clone Superset
git clone https://github.com/apache/superset.git
cd superset

# Start với Docker Compose
docker-compose up -d
```

#### Hoặc Cài Đặt Manual

```bash
# Tạo virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install apache-superset

# Initialize database
superset db upgrade

# Create admin user
export FLASK_APP=superset
superset fab create-admin

# Initialize
superset init

# Start
superset run -p 8088 --with-threads --reload --host=0.0.0.0
```

## 🔧 Environment Variables

Thêm vào `~/.bashrc` hoặc `~/.zshrc`:

```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export HBASE_HOME=/opt/hbase
export KAFKA_HOME=/opt/kafka
export SPARK_HOME=/opt/spark
export NIFI_HOME=/opt/nifi
export ZOOKEEPER_HOME=/opt/zookeeper

export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export PATH=$PATH:$HBASE_HOME/bin
export PATH=$PATH:$KAFKA_HOME/bin
export PATH=$PATH:$SPARK_HOME/bin
export PATH=$PATH:$NIFI_HOME/bin
export PATH=$PATH:$ZOOKEEPER_HOME/bin
```

## 📊 Resource Allocation

### Single Node Setup

| Component | CPU Cores | RAM | Disk |
|-----------|-----------|-----|------|
| HDFS NameNode | 2 | 4GB | 50GB |
| HDFS DataNode | 2 | 4GB | 200GB |
| HBase | 4 | 8GB | 100GB |
| Kafka | 2 | 4GB | 50GB |
| Spark Driver | 2 | 4GB | - |
| Spark Executor | 4 | 8GB | - |
| NiFi | 2 | 4GB | 20GB |
| MySQL | 2 | 4GB | 50GB |
| Superset | 1 | 2GB | 10GB |
| **Total** | **21** | **42GB** | **480GB** |

### Cluster Setup (3 nodes)

| Component | Node | CPU Cores | RAM | Disk |
|-----------|------|-----------|-----|------|
| NameNode | Master | 4 | 8GB | 100GB |
| DataNode | All | 2 | 4GB | 500GB |
| HBase Master | Master | 4 | 8GB | 100GB |
| HBase RegionServer | Workers | 4 | 8GB | 500GB |
| Kafka Broker | All | 2 | 4GB | 200GB |
| Spark Master | Master | 2 | 4GB | - |
| Spark Worker | Workers | 4 | 8GB | - |

## 🚀 Startup Script

Tạo script để khởi động tất cả services:

```bash
#!/bin/bash
# start_all.sh

echo "Starting Hadoop..."
start-dfs.sh
start-yarn.sh

echo "Starting HBase..."
/opt/hbase/bin/start-hbase.sh

echo "Starting Zookeeper..."
/opt/zookeeper/bin/zkServer.sh start

echo "Starting Kafka..."
/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties

echo "Starting NiFi..."
/opt/nifi/bin/nifi.sh start

echo "Starting MySQL..."
sudo systemctl start mysql

echo "All services started!"
```

## ✅ Verification

### Kiểm Tra Tất Cả Services

```bash
# Check Java
java -version

# Check HDFS
hdfs dfsadmin -report

# Check HBase
echo "list" | /opt/hbase/bin/hbase shell

# Check Kafka
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Check Spark
/opt/spark/bin/spark-submit --version

# Check NiFi
curl http://localhost:8080/nifi

# Check MySQL
mysql -u traffic_user -p -e "SHOW DATABASES;"

# Check Superset
curl http://localhost:8088
```

## 📌 Lưu Ý

1. **Firewall**: Mở các ports cần thiết:
   - HDFS: 9000, 50070, 50075
   - HBase: 16000, 16010
   - Kafka: 9092
   - NiFi: 8080
   - MySQL: 3306
   - Superset: 8088

2. **SELinux**: Tắt hoặc cấu hình phù hợp (CentOS)

3. **Swap**: Tắt swap để tối ưu performance

4. **Time Sync**: Đảm bảo tất cả nodes đồng bộ thời gian (NTP)

5. **Disk I/O**: Sử dụng SSD cho HDFS và HBase data directories

## 🎯 Kết Quả

Sau khi cài đặt xong, hệ thống có thể:
- Xử lý 500k-1M bản ghi/ngày
- Lưu trữ dữ liệu lịch sử
- Phân tích real-time và batch
- Trực quan hóa với Superset

