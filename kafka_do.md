# Apache Kafka - Chi Tiết Triển Khai

## 🎯 Mục Tiêu

Tạo message queue làm backbone cho hệ thống streaming, đảm bảo decoupling, fault tolerance và high throughput cho 500k-1 triệu bản ghi/ngày.

## 📊 Topics Cần Tạo

### 1. traffic_violation_raw
- **Mục đích**: Lưu dữ liệu thô từ NiFi (backup)
- **Partitions**: 6 partitions
- **Replication Factor**: 2 (nếu cluster) hoặc 1 (single node)
- **Retention**: 7 ngày
- **Compression**: `snappy` hoặc `lz4`

### 2. traffic_violation_clean
- **Mục đích**: Dữ liệu đã làm sạch từ NiFi → Spark Streaming
- **Partitions**: 12 partitions (theo region)
- **Replication Factor**: 2
- **Retention**: 3 ngày
- **Compression**: `snappy`

### 3. traffic_violation_processed
- **Mục đích**: Kết quả xử lý từ Spark Streaming → HBase
- **Partitions**: 6 partitions
- **Replication Factor**: 2
- **Retention**: 1 ngày
- **Compression**: `snappy`

### 4. traffic_volume_metrics
- **Mục đích**: Metrics về lưu lượng giao thông từ Spark Streaming
- **Partitions**: 4 partitions
- **Replication Factor**: 2
- **Retention**: 7 ngày
- **Compression**: `snappy`

## 🔧 Cấu Hình Chi Tiết

### Topic: traffic_violation_clean

```properties
# Topic Configuration
num.partitions=12
replication.factor=2
min.insync.replicas=1

# Retention
log.retention.hours=72
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

# Compression
compression.type=snappy

# Performance
num.network.threads=8
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
```

### Partition Strategy

Partition key được tính từ Camera ID để đảm bảo dữ liệu cùng region vào cùng partition:

```python
# Partition function (sử dụng trong NiFi hoặc Producer)
def get_partition(camera_id, num_partitions):
    # Extract region code (VD: BDG từ BDG_CAM_001)
    region = camera_id.split('_')[0]
    # Hash region code
    return hash(region) % num_partitions
```

**Mapping Region → Partition**:
- `BDG` (Bình Dương) → Partition 0, 1
- `DTP` (Đồng Tháp) → Partition 2, 3
- `TVH` (Thừa Thiên Huế) → Partition 4, 5
- `BKN` (Bắc Kạn) → Partition 6, 7
- Các region khác → Partition 8-11

## 📈 Throughput Tính Toán

### Giả Định
- 500k-1 triệu bản ghi/ngày
- Peak: 100k bản ghi/giờ (giờ cao điểm)
- Average: ~42k bản ghi/giờ
- Kích thước mỗi bản ghi: ~2KB (JSON)

### Tính Toán
- **Peak throughput**: 100k records/hour = ~28 records/second
- **Average throughput**: 42k records/hour = ~12 records/second
- **Data rate**: 28 records/sec × 2KB = ~56 KB/sec (peak)
- **Daily data**: 1M records × 2KB = ~2 GB/ngày

### Kafka Capacity
- Với 12 partitions, mỗi partition xử lý ~2-3 records/second
- Dễ dàng đáp ứng yêu cầu

## 🔐 Consumer Groups

### 1. spark-streaming-consumer
- **Topic**: `traffic_violation_clean`
- **Purpose**: Spark Streaming đọc dữ liệu để xử lý real-time
- **Auto Offset Reset**: `latest`
- **Enable Auto Commit**: `false` (Spark quản lý offset)

### 2. hbase-writer-consumer
- **Topic**: `traffic_violation_processed`
- **Purpose**: Ghi dữ liệu đã xử lý vào HBase
- **Auto Offset Reset**: `earliest`
- **Enable Auto Commit**: `true`

### 3. backup-consumer
- **Topic**: `traffic_violation_raw`
- **Purpose**: Backup dữ liệu thô
- **Auto Offset Reset**: `earliest`

## 🛠️ Cài Đặt và Cấu Hình

### 1. Tạo Topics

```bash
# Tạo topic traffic_violation_clean
kafka-topics.sh --create \
  --bootstrap-server localhost:9092 \
  --topic traffic_violation_clean \
  --partitions 12 \
  --replication-factor 2 \
  --config compression.type=snappy \
  --config retention.ms=259200000

# Tạo topic traffic_violation_raw
kafka-topics.sh --create \
  --bootstrap-server localhost:9092 \
  --topic traffic_violation_raw \
  --partitions 6 \
  --replication-factor 2 \
  --config retention.ms=604800000

# Tạo topic traffic_violation_processed
kafka-topics.sh --create \
  --bootstrap-server localhost:9092 \
  --topic traffic_violation_processed \
  --partitions 6 \
  --replication-factor 2 \
  --config retention.ms=86400000

# Tạo topic traffic_volume_metrics
kafka-topics.sh --create \
  --bootstrap-server localhost:9092 \
  --topic traffic_volume_metrics \
  --partitions 4 \
  --replication-factor 2 \
  --config retention.ms=604800000
```

### 2. Monitor Topics

```bash
# Kiểm tra số lượng messages trong topic
kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic traffic_violation_clean \
  --time -1

# Monitor consumer lag
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group spark-streaming-consumer \
  --describe
```

## 🔄 Fault Tolerance

### 1. Replication
- **Replication Factor = 2**: Đảm bảo dữ liệu không mất khi 1 broker down
- **Min In-Sync Replicas = 1**: Cho phép 1 replica offline

### 2. Producer Configuration
```properties
acks=all
retries=3
max.in.flight.requests.per.connection=5
enable.idempotence=true
```

### 3. Consumer Configuration
```properties
enable.auto.commit=false
auto.offset.reset=latest
max.poll.records=500
session.timeout.ms=30000
```

## 📊 Monitoring

### Metrics Cần Theo Dõi
1. **Throughput**: Messages/second per topic
2. **Latency**: End-to-end latency từ producer đến consumer
3. **Consumer Lag**: Độ trễ của consumer
4. **Disk Usage**: Dung lượng lưu trữ
5. **Network I/O**: Băng thông sử dụng

### Tools
- **Kafka Manager / CMAK**: Quản lý và monitor cluster
- **Prometheus + Grafana**: Metrics và alerting
- **Kafka Connect**: Nếu cần integrate với hệ thống khác

## 🎯 Kết Quả

- **Decoupling**: Tách biệt giữa NiFi (producer) và Spark (consumer)
- **Fault Tolerance**: Dữ liệu được replicate, không mất khi có lỗi
- **High Throughput**: Hỗ trợ 500k-1 triệu bản ghi/ngày dễ dàng
- **Scalability**: Có thể scale bằng cách tăng partitions
- **Replay Capability**: Có thể replay dữ liệu khi Spark lỗi

## 📌 Từ Khóa Bảo Vệ

- **Message Queue**: Hàng đợi tin nhắn phân tán
- **Partitioning Strategy**: Chiến lược phân vùng theo region
- **Fault Tolerance**: Khả năng chịu lỗi với replication
- **High Throughput**: Xử lý lượng lớn dữ liệu
- **Consumer Groups**: Quản lý nhiều consumer

