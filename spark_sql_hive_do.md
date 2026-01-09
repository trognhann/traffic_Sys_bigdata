# Spark SQL / Hive - Chi Tiết Triển Khai

## 🎯 Mục Tiêu

Phân tích batch dữ liệu lịch sử, phát hiện xu hướng, và tổng hợp dữ liệu để đẩy vào MySQL Data Mart.

## 📊 Các Bài Toán Xử Lý

### 1. Giám Sát Vi Phạm Giao Thông

#### 1.1. Tổng Hợp Vi Phạm Theo Ngày/Tháng
- **Input**: Dữ liệu từ HDFS Parquet
- **Output**: Bảng tổng hợp theo ngày, tháng
- **Metrics**:
  - Tổng số vi phạm theo ngày/tháng
  - Số vi phạm theo region
  - Số vi phạm theo loại
  - Top 10 camera có nhiều vi phạm nhất
  - Tỷ lệ tăng/giảm so với kỳ trước

#### 1.2. Phân Tích Xu Hướng Vi Phạm
- **Time Series Analysis**:
  - Xu hướng vi phạm theo giờ trong ngày
  - Xu hướng vi phạm theo ngày trong tuần
  - Xu hướng vi phạm theo tháng trong năm
  - Phát hiện seasonal patterns
- **Output**: Bảng time series với các metrics

#### 1.3. Phân Tích Vi Phạm Theo Địa Bàn
- **Spatial Analysis**:
  - Bản đồ nhiệt (heatmap) vi phạm theo region
  - So sánh vi phạm giữa các region
  - Phát hiện region có tỷ lệ vi phạm cao
  - Correlation giữa mật độ dân số và vi phạm (nếu có dữ liệu)

#### 1.4. Phân Tích Vi Phạm Theo Loại Phương Tiện
- **Vehicle Analysis**:
  - Phân bố vi phạm theo màu biển số (xe cá nhân vs kinh doanh)
  - Phân bố vi phạm theo màu xe
  - Top loại vi phạm phổ biến nhất
  - Correlation giữa loại xe và loại vi phạm

#### 1.5. Phân Tích Xe Vi Phạm Nhiều Lần
- **Repeat Offender Analysis**:
  - Xác định xe vi phạm nhiều lần trong tháng
  - Phân tích pattern vi phạm của từng xe
  - Phát hiện xe có hành vi vi phạm nghiêm trọng
  - Top 100 xe vi phạm nhiều nhất

#### 1.6. Phân Tích Hiệu Quả Camera
- **Camera Performance**:
  - Số vi phạm phát hiện được của mỗi camera
  - So sánh hiệu quả giữa các camera
  - Phát hiện camera có vấn đề (quá ít hoặc quá nhiều vi phạm)
  - ROI của từng camera

### 2. Đo Đếm Lưu Lượng Giao Thông

#### 2.1. Tổng Hợp Lưu Lượng Theo Thời Gian
- **Traffic Volume Aggregation**:
  - Lưu lượng theo giờ/ngày/tháng
  - Lưu lượng theo region
  - Peak hours analysis
  - Off-peak hours analysis

#### 2.2. Phân Tích Lưu Lượng Theo Loại Xe
- **Vehicle Type Analysis**:
  - Số lượng xe cá nhân (biển số đen)
  - Số lượng xe kinh doanh (biển số vàng/xanh)
  - Tỷ lệ % mỗi loại theo thời gian
  - Xu hướng thay đổi tỷ lệ

#### 2.3. Phân Tích Mật Độ Giao Thông
- **Traffic Density**:
  - Mật độ giao thông theo giờ
  - Mật độ theo region
  - So sánh với capacity của đường
  - Phát hiện đoạn đường quá tải

#### 2.4. Phân Tích Lưu Lượng Theo Ngày Trong Tuần
- **Day of Week Analysis**:
  - So sánh lưu lượng giữa các ngày trong tuần
  - Phát hiện ngày có lưu lượng cao nhất/thấp nhất
  - Pattern theo tuần

#### 2.5. Dự Đoán Lưu Lượng
- **Forecasting**:
  - Sử dụng Moving Average, Exponential Smoothing
  - Dự đoán lưu lượng cho ngày/tuần tiếp theo
  - So sánh với thực tế để đánh giá độ chính xác

### 3. Tích Hợp Cả Hai

#### 3.1. Tỷ Lệ Vi Phạm / Lưu Lượng
- **Violation Rate Analysis**:
  - Tỷ lệ vi phạm = (Số vi phạm / Tổng lưu lượng) × 100
  - Tỷ lệ theo region
  - Tỷ lệ theo thời gian
  - Phát hiện region/thời điểm có tỷ lệ vi phạm cao

#### 3.2. Correlation Analysis
- **Statistical Analysis**:
  - Correlation giữa lưu lượng và số vi phạm
  - Correlation giữa thời gian và vi phạm
  - Correlation giữa loại xe và vi phạm
  - Phân tích nguyên nhân

#### 3.3. Phân Tích Hiệu Quả Tuần Tra
- **Enforcement Effectiveness**:
  - So sánh vi phạm trước và sau khi có tuần tra
  - Đánh giá hiệu quả của camera
  - ROI của hệ thống giám sát

## 🔧 Triển Khai Chi Tiết

### 1. Tạo Hive Tables

```sql
-- Tạo database
CREATE DATABASE IF NOT EXISTS traffic_violations;

USE traffic_violations;

-- Table cho raw data
CREATE EXTERNAL TABLE IF NOT EXISTS violations_raw (
    camera_id string,
    vin string,
    timestamp bigint,
    timestamp_iso string,
    violation_type int,
    license_plate string,
    video_path string,
    plate_image_path string,
    overview_image_path string,
    vehicle_image_path string,
    before_image_path string,
    additional_image_path string,
    processing_status int,
    violation_severity int,
    vehicle_color string,
    plate_color string,
    region string,
    ingest_timestamp string,
    source_file string
)
PARTITIONED BY (year int, month int, day int)
STORED AS PARQUET
LOCATION '/data/traffic_violations/raw';

-- Repair partitions
MSCK REPAIR TABLE violations_raw;
```

### 2. Tạo Views và Aggregated Tables

```sql
-- View với các cột tính toán
CREATE VIEW violations_enriched AS
SELECT 
    *,
    from_unixtime(timestamp / 1000) as event_datetime,
    year(from_unixtime(timestamp / 1000)) as event_year,
    month(from_unixtime(timestamp / 1000)) as event_month,
    day(from_unixtime(timestamp / 1000)) as event_day,
    hour(from_unixtime(timestamp / 1000)) as event_hour,
    dayofweek(from_unixtime(timestamp / 1000)) as day_of_week,
    CASE 
        WHEN plate_color = 'black' THEN 'Personal'
        WHEN plate_color IN ('yellow', 'blue') THEN 'Commercial'
        ELSE 'Unknown'
    END as vehicle_category
FROM violations_raw;

-- Bảng tổng hợp theo ngày
CREATE TABLE violations_daily_summary AS
SELECT 
    event_date,
    region,
    COUNT(*) as total_violations,
    COUNT(DISTINCT license_plate) as unique_vehicles,
    COUNT(DISTINCT camera_id) as active_cameras,
    COUNT(DISTINCT violation_type) as violation_types,
    SUM(CASE WHEN violation_type = 31 THEN 1 ELSE 0 END) as type_31_count,
    SUM(CASE WHEN violation_type = 61 THEN 1 ELSE 0 END) as type_61_count,
    AVG(violation_severity) as avg_severity,
    COUNT(CASE WHEN vehicle_category = 'Personal' THEN 1 END) as personal_vehicles,
    COUNT(CASE WHEN vehicle_category = 'Commercial' THEN 1 END) as commercial_vehicles
FROM (
    SELECT 
        date(from_unixtime(timestamp / 1000)) as event_date,
        region,
        license_plate,
        camera_id,
        violation_type,
        violation_severity,
        CASE 
            WHEN plate_color = 'black' THEN 'Personal'
            WHEN plate_color IN ('yellow', 'blue') THEN 'Commercial'
            ELSE 'Unknown'
        END as vehicle_category
    FROM violations_raw
) t
GROUP BY event_date, region;
```

### 3. Spark SQL Queries

#### 3.1. Phân Tích Xu Hướng

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

spark = SparkSession.builder \
    .appName("TrafficViolationAnalysis") \
    .enableHiveSupport() \
    .getOrCreate()

# Đọc từ Hive
df = spark.sql("SELECT * FROM traffic_violations.violations_enriched")

# Xu hướng theo giờ
hourly_trend = df \
    .groupBy("event_hour") \
    .agg(
        count("*").alias("violation_count"),
        countDistinct("license_plate").alias("unique_vehicles"),
        avg("violation_severity").alias("avg_severity")
    ) \
    .orderBy("event_hour")

# Xu hướng theo ngày trong tuần
weekly_trend = df \
    .groupBy("day_of_week") \
    .agg(
        count("*").alias("violation_count"),
        countDistinct("license_plate").alias("unique_vehicles")
    ) \
    .orderBy("day_of_week")

# Xu hướng theo tháng
monthly_trend = df \
    .groupBy("event_year", "event_month") \
    .agg(
        count("*").alias("violation_count"),
        countDistinct("license_plate").alias("unique_vehicles"),
        countDistinct("camera_id").alias("active_cameras")
    ) \
    .orderBy("event_year", "event_month")
```

#### 3.2. Phân Tích Xe Vi Phạm Nhiều Lần

```python
# Xe vi phạm nhiều lần trong tháng
repeat_offenders = df \
    .groupBy("license_plate", "event_year", "event_month") \
    .agg(
        count("*").alias("violation_count"),
        collect_set("violation_type").alias("violation_types"),
        collect_set("camera_id").alias("cameras"),
        min("event_datetime").alias("first_violation"),
        max("event_datetime").alias("last_violation")
    ) \
    .filter(col("violation_count") >= 3) \
    .orderBy(desc("violation_count"))

# Top 100 xe vi phạm nhiều nhất
top_offenders = repeat_offenders \
    .orderBy(desc("violation_count")) \
    .limit(100)
```

#### 3.3. Phân Tích Lưu Lượng

```python
# Lưu lượng theo giờ
traffic_volume_hourly = df \
    .groupBy("event_date", "event_hour", "region") \
    .agg(
        countDistinct("license_plate").alias("traffic_volume"),
        count("*").alias("total_records")
    ) \
    .withColumn(
        "violation_rate",
        (col("total_records") / col("traffic_volume")) * 100
    )

# Peak hours
peak_hours = traffic_volume_hourly \
    .groupBy("event_hour") \
    .agg(
        avg("traffic_volume").alias("avg_volume"),
        max("traffic_volume").alias("max_volume")
    ) \
    .orderBy(desc("avg_volume"))
```

#### 3.4. Correlation Analysis

```python
from pyspark.ml.stat import Correlation
from pyspark.ml.feature import VectorAssembler

# Tạo features cho correlation
features_df = df \
    .groupBy("event_date", "event_hour", "region") \
    .agg(
        count("*").alias("violation_count"),
        countDistinct("license_plate").alias("traffic_volume"),
        avg("violation_severity").alias("avg_severity")
    ) \
    .withColumn(
        "violation_rate",
        (col("violation_count") / col("traffic_volume")) * 100
    )

# Vectorize
assembler = VectorAssembler(
    inputCols=["violation_count", "traffic_volume", "avg_severity", "violation_rate"],
    outputCol="features"
)

vector_df = assembler.transform(features_df)

# Tính correlation
correlation_matrix = Correlation.corr(vector_df, "features").head()[0]
```

### 4. Ghi Vào MySQL

```python
# Ghi daily summary vào MySQL
daily_summary.write \
    .format("jdbc") \
    .option("url", "jdbc:mysql://localhost:3306/traffic_db") \
    .option("dbtable", "violation_daily_summary") \
    .option("user", "root") \
    .option("password", "password") \
    .mode("overwrite") \
    .save()
```

## 📊 Output Tables

### 1. Hive Tables
- `violations_daily_summary`: Tổng hợp theo ngày
- `violations_monthly_summary`: Tổng hợp theo tháng
- `violations_by_region`: Tổng hợp theo region
- `violations_by_type`: Tổng hợp theo loại vi phạm
- `traffic_volume_daily`: Lưu lượng theo ngày
- `traffic_volume_hourly`: Lưu lượng theo giờ
- `repeat_offenders`: Xe vi phạm nhiều lần
- `camera_performance`: Hiệu quả camera

### 2. MySQL Tables (sẽ được tạo trong mysql_do.md)
- Các bảng tương tự nhưng tối ưu cho query nhanh

## 🎯 Kết Quả

- **Batch Analytics**: Phân tích dữ liệu lịch sử
- **Trend Analysis**: Phát hiện xu hướng
- **Statistical Analysis**: Phân tích thống kê
- **Data Mart**: Dữ liệu tổng hợp sẵn cho BI

## 📌 Từ Khóa Bảo Vệ

- **OLAP**: Online Analytical Processing
- **Batch Analytics**: Phân tích batch
- **Time Series Analysis**: Phân tích chuỗi thời gian
- **Statistical Analysis**: Phân tích thống kê
- **Data Mart**: Kho dữ liệu phân tích

