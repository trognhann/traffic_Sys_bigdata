# HBase / HDFS - Chi Tiết Triển Khai

## 🎯 Mục Tiêu

Lưu trữ dữ liệu raw và lịch sử dài hạn, phục vụ cho phân tích batch và truy vấn nhanh.

## 📊 Kiến Trúc Lưu Trữ

### HBase: Lưu Trữ Dữ Liệu Bán Cấu Trúc

#### 1. Table: traffic_violations
- **Mục đích**: Lưu bản tin vi phạm gốc
- **Rowkey Design**: `{region}#{timestamp}#{camera_id}#{license_plate}`
  - VD: `BDG#1719448991037#BDG_CAM_001#11H03226`
  - Đảm bảo phân bố đều theo region
  - Dễ query theo thời gian và region

#### 2. Table: traffic_metrics
- **Mục đích**: Lưu metrics đã aggregate
- **Rowkey Design**: `{window_type}#{window_start}#{region}`
  - VD: `5min#2024-06-27T10:00:00#BDG`
  - Window types: `5min`, `15min`, `1hour`, `1day`

#### 3. Table: traffic_hotspots
- **Mục đích**: Lưu lịch sử hotspot detection
- **Rowkey Design**: `{date}#{hour}#{camera_id}`
  - VD: `2024-06-27#10#BDG_CAM_001`

### HDFS: Lưu Trữ File Parquet

#### 1. Raw Data (Parquet)
- **Path**: `/data/traffic_violations/raw/year={year}/month={month}/day={day}/`
- **Format**: Parquet
- **Partition**: Theo ngày
- **Schema**: Giống schema Avro trong NiFi

#### 2. Processed Data (Parquet)
- **Path**: `/data/traffic_violations/processed/year={year}/month={month}/day={day}/`
- **Format**: Parquet
- **Content**: Dữ liệu đã được làm sạch và enrich

#### 3. Metrics Data (Parquet)
- **Path**: `/data/traffic_metrics/{window_type}/year={year}/month={month}/day={day}/`
- **Format**: Parquet
- **Window types**: `5min`, `15min`, `1hour`, `1day`

## 🔧 Thiết Kế HBase Tables

### 1. Table: traffic_violations

```bash
# Tạo table
create 'traffic_violations', 
  {NAME => 'info', VERSIONS => 1, COMPRESSION => 'SNAPPY'},
  {NAME => 'media', VERSIONS => 1, COMPRESSION => 'SNAPPY'},
  {NAME => 'metadata', VERSIONS => 1, COMPRESSION => 'SNAPPY'}

# Column Families:
# - info: Thông tin cơ bản (camera_id, violation_type, license_plate, etc.)
# - media: Đường dẫn media (video_path, image_paths)
# - metadata: Metadata (ingest_timestamp, source_file, region)
```

**Column Design**:
- `info:camera_id`: Camera ID
- `info:vin`: VIN
- `info:timestamp`: Timestamp (milliseconds)
- `info:timestamp_iso`: ISO 8601 timestamp
- `info:violation_type`: Loại vi phạm
- `info:license_plate`: Biển số xe
- `info:processing_status`: Trạng thái xử lý
- `info:violation_severity`: Mức độ vi phạm
- `info:vehicle_color`: Màu xe
- `info:plate_color`: Màu biển số
- `media:video_path`: Đường dẫn video
- `media:plate_image`: Đường dẫn ảnh biển số
- `media:overview_image`: Đường dẫn ảnh tổng quan
- `media:vehicle_image`: Đường dẫn ảnh xe
- `media:before_image`: Đường dẫn ảnh trước
- `media:additional_image`: Đường dẫn ảnh bổ sung
- `metadata:region`: Region code
- `metadata:ingest_timestamp`: Thời gian ingest
- `metadata:source_file`: File nguồn

### 2. Table: traffic_metrics

```bash
create 'traffic_metrics',
  {NAME => 'metrics', VERSIONS => 1, COMPRESSION => 'SNAPPY'},
  {NAME => 'details', VERSIONS => 1, COMPRESSION => 'SNAPPY'}
```

**Column Design**:
- `metrics:window_type`: Loại window (5min, 15min, 1hour)
- `metrics:window_start`: Thời gian bắt đầu window
- `metrics:window_end`: Thời gian kết thúc window
- `metrics:violation_count`: Tổng số vi phạm
- `metrics:unique_vehicles`: Số phương tiện duy nhất
- `metrics:traffic_volume`: Lưu lượng giao thông
- `metrics:violation_rate`: Tỷ lệ vi phạm
- `details:cameras`: Danh sách camera (JSON)
- `details:violation_types`: Phân bố loại vi phạm (JSON)

### 3. Table: traffic_hotspots

```bash
create 'traffic_hotspots',
  {NAME => 'hotspot', VERSIONS => 1, COMPRESSION => 'SNAPPY'}
```

**Column Design**:
- `hotspot:camera_id`: Camera ID
- `hotspot:region`: Region
- `hotspot:violation_count`: Số vi phạm
- `hotspot:threshold`: Ngưỡng
- `hotspot:is_active`: Trạng thái active

## 📝 Ghi Dữ Liệu Vào HBase

### Từ Spark Streaming

```python
from pyspark.sql import SparkSession
import happybase

def write_to_hbase(batch_df, batch_id):
    connection = happybase.Connection('localhost')
    table = connection.table('traffic_violations')
    
    for row in batch_df.collect():
        rowkey = f"{row.region}#{row.timestamp}#{row.camera_id}#{row.license_plate}"
        
        data = {
            b'info:camera_id': str(row.camera_id).encode(),
            b'info:timestamp': str(row.timestamp).encode(),
            b'info:violation_type': str(row.violation_type).encode(),
            b'info:license_plate': str(row.license_plate).encode(),
            b'info:vehicle_color': str(row.vehicle_color or '').encode(),
            b'info:plate_color': str(row.plate_color or '').encode(),
            b'media:video_path': str(row.video_path or '').encode(),
            b'media:plate_image': str(row.plate_image_path or '').encode(),
            b'metadata:region': str(row.region).encode(),
            b'metadata:ingest_timestamp': str(row.ingest_timestamp).encode()
        }
        
        table.put(rowkey, data)
    
    connection.close()

# Sử dụng trong Spark Streaming
violations_df.writeStream \
    .foreachBatch(write_to_hbase) \
    .option("checkpointLocation", "/checkpoint/hbase") \
    .start()
```

### Từ Spark Batch (HDFS → HBase)

```python
# Đọc từ HDFS Parquet
df = spark.read.parquet("/data/traffic_violations/raw/year=2024/month=06/day=27/")

# Transform và ghi vào HBase
df.foreachPartition(write_partition_to_hbase)
```

## 📁 Cấu Trúc HDFS

```
/data/
├── traffic_violations/
│   ├── raw/
│   │   ├── year=2024/
│   │   │   ├── month=06/
│   │   │   │   ├── day=27/
│   │   │   │   │   ├── part-00000.parquet
│   │   │   │   │   └── part-00001.parquet
│   │   │   │   └── day=28/
│   │   │   └── month=07/
│   │   └── processed/
│   │       └── year=2024/
│   │           └── month=06/
│   │               └── day=27/
│   └── metrics/
│       ├── 5min/
│       │   └── year=2024/
│       │       └── month=06/
│       │           └── day=27/
│       ├── 15min/
│       ├── 1hour/
│       └── 1day/
└── traffic_volume/
    └── year=2024/
        └── month=06/
            └── day=27/
```

## 🔄 Ghi Dữ Liệu Vào HDFS

### Từ Spark Streaming

```python
# Ghi Parquet vào HDFS
query_hdfs = violations_df \
    .writeStream \
    .format("parquet") \
    .option("path", "/data/traffic_violations/raw") \
    .option("checkpointLocation", "/checkpoint/hdfs") \
    .partitionBy("year", "month", "day") \
    .start()
```

### Từ Spark Batch

```python
# Đọc từ Kafka hoặc HBase
df = spark.read.format("kafka")...

# Ghi vào HDFS
df.write \
    .mode("append") \
    .partitionBy("year", "month", "day") \
    .parquet("/data/traffic_violations/raw")
```

## 🔍 Query HBase

### 1. Query Theo Region và Thời Gian

```python
import happybase

connection = happybase.Connection('localhost')
table = connection.table('traffic_violations')

# Scan theo region và timestamp range
start_row = f"BDG#1719448990000"
stop_row = f"BDG#1719449000000"

for key, data in table.scan(row_start=start_row, row_stop=stop_row):
    print(key, data)
```

### 2. Query Metrics

```python
# Query metrics 5 phút
table = connection.table('traffic_metrics')

start_row = "5min#2024-06-27T10:00:00"
stop_row = "5min#2024-06-27T11:00:00"

for key, data in table.scan(row_start=start_row, row_stop=stop_row):
    print(key, data)
```

## 📊 Tối Ưu Hóa

### 1. Pre-splitting Regions

```bash
# Pre-split table theo region
create 'traffic_violations', 
  {NAME => 'info', VERSIONS => 1, COMPRESSION => 'SNAPPY'},
  {NAME => 'media', VERSIONS => 1, COMPRESSION => 'SNAPPY'},
  {NAME => 'metadata', VERSIONS => 1, COMPRESSION => 'SNAPPY'},
  {SPLITS => ['BDG', 'DTP', 'TVH', 'BKN']}
```

### 2. Compression
- Sử dụng `SNAPPY` cho tốc độ đọc/ghi tốt
- Hoặc `GZ` cho tỷ lệ nén cao hơn

### 3. Bloom Filter
- Enable bloom filter cho column `info:license_plate` để tăng tốc query

```bash
alter 'traffic_violations', {NAME => 'info', BLOOMFILTER => 'ROWCOL'}
```

## 🎯 Kết Quả

- **Scalable Storage**: Lưu trữ hàng triệu bản ghi
- **Fast Query**: Query nhanh với rowkey design hợp lý
- **Data Lake**: HDFS làm data lake cho phân tích batch
- **Historical Data**: Lưu trữ lịch sử dài hạn

## 📌 Từ Khóa Bảo Vệ

- **Distributed Storage**: Lưu trữ phân tán
- **NoSQL Database**: HBase cho dữ liệu bán cấu trúc
- **Data Lake**: HDFS làm data lake
- **Rowkey Design**: Thiết kế rowkey tối ưu
- **Column Families**: Tổ chức dữ liệu theo column families

