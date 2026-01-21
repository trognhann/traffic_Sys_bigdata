# Spark Streaming - Chi Tiết Triển Khai

## 🎯 Mục Tiêu

Xử lý streaming dữ liệu vi phạm giao thông và lưu lượng giao thông theo thời gian thực, phát hiện patterns và tính toán metrics.

## 📊 Các Bài Toán Xử Lý

### 1. Giám Sát Vi Phạm Giao Thông

#### 1.1. Thống Kê Vi Phạm Theo Thời Gian Thực
- **Window**: 5 phút, 15 phút, 1 giờ
- **Metrics**:
  - Tổng số vi phạm trong window
  - Số vi phạm theo loại (violation_type)
  - Số vi phạm theo region (camera location)
  - Tỷ lệ tăng/giảm so với window trước
  - Top 10 camera có nhiều vi phạm nhất

#### 1.2. Phát Hiện Điểm Nóng (Hotspot Detection)
- **Window**: 15 phút, 1 giờ
- **Logic**:
  - Tính số vi phạm/giờ cho mỗi camera
  - So sánh với ngưỡng trung bình (mean + 2*std)
  - Alert khi vượt ngưỡng
- **Output**: Danh sách camera đang ở trạng thái "hotspot"

#### 1.3. Phát Hiện Vi Phạm Bất Thường
- **Window**: 1 giờ
- **Logic**:
  - So sánh số vi phạm hiện tại với lịch sử cùng khung giờ
  - Phát hiện spike bất thường (> 3 lần trung bình)
  - Phát hiện drop bất thường (< 0.3 lần trung bình)
- **Use Case**: Phát hiện sự cố camera hoặc sự kiện đặc biệt

#### 1.4. Phân Tích Vi Phạm Theo Loại Phương Tiện
- **Window**: 1 giờ
- **Metrics**:
  - Phân bố vi phạm theo loại phương tiện (21=ô tô, 31=xe máy, 41=xe đạp, 51=xe khách, 61=xe tải)
  - Phân bố vi phạm theo màu biển số (xe cá nhân vs xe kinh doanh)
  - Phân bố vi phạm theo màu xe
  - Top loại vi phạm (VIN code) phổ biến nhất
  - Correlation giữa loại phương tiện và loại vi phạm

#### 1.5. Tracking Xe Vi Phạm Nhiều Lần
- **Window**: Sliding window 24 giờ
- **Logic**:
  - Group theo biển số xe
  - Đếm số lần vi phạm trong 24h
  - Alert khi > 3 lần vi phạm
- **Output**: Danh sách xe vi phạm nhiều lần

### 2. Đo Đếm Lưu Lượng Giao Thông

#### 2.1. Tính Lưu Lượng Theo Thời Gian
- **Window**: 5 phút, 15 phút, 1 giờ
- **Metrics**:
  - Số phương tiện đi qua mỗi camera (count distinct license_plate)
  - Lưu lượng theo region
  - Lưu lượng theo giờ trong ngày
  - Peak hours detection

#### 2.2. Phân Tích Lưu Lượng Theo Loại Xe
- **Window**: 1 giờ
- **Metrics**:
  - Số lượng xe cá nhân (biển số đen)
  - Số lượng xe kinh doanh (biển số vàng/xanh)
  - Tỷ lệ % mỗi loại

#### 2.3. Tính Tốc Độ Trung Bình (Nếu có dữ liệu)
- **Window**: 15 phút
- **Logic**:
  - Nếu có timestamp và vị trí camera, tính tốc độ
  - So sánh với tốc độ cho phép
  - Phát hiện đoạn đường có tốc độ trung bình cao

#### 2.4. Phân Tích Mật Độ Giao Thông
- **Window**: 15 phút
- **Metrics**:
  - Số phương tiện/phút cho mỗi camera
  - Mật độ theo region
  - So sánh với capacity của đường

#### 2.5. Dự Đoán Lưu Lượng (Simple Moving Average)
- **Window**: 1 giờ
- **Logic**:
  - Tính moving average 3 giờ
  - Dự đoán lưu lượng giờ tiếp theo
  - So sánh với thực tế để đánh giá độ chính xác

### 3. Tích Hợp Cả Hai

#### 3.1. Tỷ Lệ Vi Phạm / Lưu Lượng
- **Window**: 1 giờ
- **Metrics**:
  - Tỷ lệ vi phạm = (Số vi phạm / Tổng lưu lượng) × 100
  - So sánh tỷ lệ giữa các region
  - Phát hiện region có tỷ lệ vi phạm cao bất thường

#### 3.2. Correlation Analysis
- **Window**: 1 giờ
- **Logic**:
  - Tìm correlation giữa lưu lượng và số vi phạm
  - Phát hiện khi lưu lượng cao nhưng vi phạm thấp (có thể do tuần tra)
  - Phát hiện khi lưu lượng thấp nhưng vi phạm cao (có thể do camera nhạy)

## 🔧 Triển Khai Chi Tiết

### 1. Cấu Hình Spark Streaming

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

# Tạo SparkSession
spark = SparkSession.builder \
    .appName("TrafficViolationStreaming") \
    .config("spark.sql.streaming.checkpointLocation", "/checkpoint/traffic") \
    .config("spark.sql.shuffle.partitions", "200") \
    .getOrCreate()

# Đọc từ Kafka
df = spark \
    .readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "traffic_violation_clean") \
    .option("startingOffsets", "latest") \
    .option("failOnDataLoss", "false") \
    .load()
```

### 2. Parse JSON và Transform

```python
# Schema cho dữ liệu
schema = StructType([
    StructField("camera_id", StringType()),
    StructField("vin", StringType()),
    StructField("timestamp", LongType()),
    StructField("timestamp_iso", StringType()),
    StructField("violation_type", IntegerType()),
    StructField("license_plate", StringType()),
    StructField("video_path", StringType()),
    StructField("plate_image_path", StringType()),
    StructField("overview_image_path", StringType()),
    StructField("vehicle_image_path", StringType()),
    StructField("before_image_path", StringType()),
    StructField("additional_image_path", StringType()),
    StructField("processing_status", IntegerType()),
    StructField("violation_severity", IntegerType()),
    StructField("vehicle_color", StringType()),
    StructField("plate_color", StringType()),
    StructField("region", StringType()),
    StructField("ingest_timestamp", StringType()),
    StructField("source_file", StringType())
])

# Parse JSON
violations_df = df.select(
    from_json(col("value").cast("string"), schema).alias("data")
).select("data.*")

# Thêm cột thời gian
violations_df = violations_df.withColumn(
    "event_time", 
    from_unixtime(col("timestamp") / 1000)
).withColumn(
    "hour", 
    hour(col("event_time"))
).withColumn(
    "date", 
    to_date(col("event_time"))
)
```

### 3. Window Aggregations

#### 3.1. Thống Kê Vi Phạm 5 Phút

```python
# Window 5 phút
window_5min = violations_df \
    .withWatermark("event_time", "10 minutes") \
    .groupBy(
        window(col("event_time"), "5 minutes"),
        col("area_name"),
        col("province"),
        col("vehicle_type"),
        col("vin")
    ) \
    .agg(
        count("*").alias("violation_count"),
        countDistinct("license_plate").alias("unique_vehicles"),
        collect_list("camera_id").alias("cameras")
    )

# Ghi vào Kafka
query_5min = window_5min \
    .select(to_json(struct("*")).alias("value")) \
    .writeStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("topic", "traffic_violation_processed") \
    .option("checkpointLocation", "/checkpoint/5min") \
    .start()
```

#### 3.2. Hotspot Detection

```python
# Window 15 phút để phát hiện hotspot
hotspot_df = violations_df \
    .withWatermark("event_time", "30 minutes") \
    .groupBy(
        window(col("event_time"), "15 minutes"),
        col("camera_id"),
        col("region")
    ) \
    .agg(
        count("*").alias("violation_count")
    ) \
    .withColumn(
        "is_hotspot",
        when(col("violation_count") > 50, True).otherwise(False)
    )

# Alert khi có hotspot
hotspot_alert = hotspot_df \
    .filter(col("is_hotspot") == True) \
    .select(
        col("window.start").alias("window_start"),
        col("camera_id"),
        col("region"),
        col("violation_count")
    )
```

#### 3.3. Lưu Lượng Giao Thông

```python
# Tính lưu lượng (count distinct license_plate)
traffic_volume = violations_df \
    .withWatermark("event_time", "10 minutes") \
    .groupBy(
        window(col("event_time"), "15 minutes"),
        col("camera_id"),
        col("region")
    ) \
    .agg(
        countDistinct("license_plate").alias("traffic_volume"),
        count("*").alias("total_records")
    ) \
    .withColumn(
        "violation_rate",
        (col("total_records") / col("traffic_volume")) * 100
    )

# Ghi vào Kafka topic riêng
query_volume = traffic_volume \
    .select(to_json(struct("*")).alias("value")) \
    .writeStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("topic", "traffic_volume_metrics") \
    .option("checkpointLocation", "/checkpoint/volume") \
    .start()
```

### 4. Ghi Vào HBase

```python
# Function để ghi vào HBase
def write_to_hbase(batch_df, batch_id):
    # Convert DataFrame thành HBase format
    # Sử dụng happybase hoặc hbase-python
    pass

# Ghi vào HBase
query_hbase = violations_df \
    .writeStream \
    .foreachBatch(write_to_hbase) \
    .option("checkpointLocation", "/checkpoint/hbase") \
    .start()
```

## 📊 Output Streams

### 1. Kafka Topics
- `traffic_violation_processed`: Kết quả aggregation
- `traffic_volume_metrics`: Metrics lưu lượng
- `traffic_hotspot_alerts`: Cảnh báo hotspot

### 2. HBase Tables
- `traffic_violations`: Raw data với rowkey = `region#timestamp#id`
- `traffic_metrics_5min`: Metrics 5 phút
- `traffic_metrics_15min`: Metrics 15 phút
- `traffic_metrics_1hour`: Metrics 1 giờ

### 3. Console/Dashboard
- Real-time metrics hiển thị trên console
- Có thể tích hợp với Grafana để visualize

## ⚙️ Cấu Hình Performance

```python
spark.conf.set("spark.sql.streaming.checkpointLocation", "/checkpoint")
spark.conf.set("spark.sql.shuffle.partitions", "200")
spark.conf.set("spark.streaming.backpressure.enabled", "true")
spark.conf.set("spark.streaming.kafka.maxRatePerPartition", "1000")
spark.conf.set("spark.sql.streaming.stateStore.providerClass", 
                "org.apache.spark.sql.execution.streaming.state.HDFSBackedStateStoreProvider")
```

## 🎯 Kết Quả

- **Real-time Analytics**: Xử lý dữ liệu gần như real-time (latency < 1 phút)
- **Hotspot Detection**: Phát hiện điểm nóng vi phạm
- **Traffic Volume**: Đo đếm lưu lượng giao thông
- **Anomaly Detection**: Phát hiện bất thường
- **Scalability**: Có thể scale bằng cách tăng partitions

## 📌 Từ Khóa Bảo Vệ

- **Streaming Analytics**: Phân tích dữ liệu streaming
- **Window Aggregation**: Tổng hợp theo cửa sổ thời gian
- **Watermarking**: Xử lý dữ liệu trễ
- **Hotspot Detection**: Phát hiện điểm nóng
- **Traffic Volume Analysis**: Phân tích lưu lượng giao thông
- **Anomaly Detection**: Phát hiện bất thường

