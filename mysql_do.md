# MySQL - Data Mart Chi Tiết Triển Khai

## 🎯 Mục Tiêu

Tạo Data Mart tối ưu cho BI tools, lưu trữ dữ liệu đã tổng hợp từ Spark SQL/Hive để phục vụ dashboard nhanh.

## 📊 Schema Design

### 0. Bảng Reference (Từ hệ thống quản lý)

#### 0.1. Bảng: v_camera
- **Nguồn**: Import từ file `mysql.sql`
- **Mục đích**: Thông tin camera giám sát
- **Key fields**: `CAM_ID`, `CAM_CODE`, `AREA_ID`, `CAM_NAME`, `LOCATION`
- **Relationship**: Mỗi camera thuộc 1 khu vực (AREA_ID → v_area.AREA_ID)

#### 0.2. Bảng: v_area
- **Nguồn**: Import từ file `mysql.sql`
- **Mục đích**: Thông tin khu vực/địa bàn
- **Key fields**: `AREA_ID`, `AREA_CODE`, `AREA_NAME`, `PROVINCE`, `DISTRICT`, `VILLAGE`
- **Relationship**: Một khu vực có nhiều camera

#### 0.3. Bảng: v_violation_code
- **Nguồn**: Import từ file `mysql.sql`
- **Mục đích**: Mã và thông tin vi phạm
- **Key fields**: `VIN_ID`, `VIN_CODE`, `VIN_NAME`, `DESCRIPTION`, `CAR_FEE_MIN`, `CAR_FEE_MAX`
- **Mapping**: VIN_CODE map với trường VIN trong bản tin

### 1. Bảng: violation_daily_summary

```sql
CREATE TABLE violation_daily_summary (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    summary_date DATE NOT NULL,
    area_id BIGINT,
    area_code VARCHAR(255),
    area_name VARCHAR(255),
    province VARCHAR(200),
    region VARCHAR(50) NOT NULL,
    total_violations INT NOT NULL DEFAULT 0,
    unique_vehicles INT NOT NULL DEFAULT 0,
    active_cameras INT NOT NULL DEFAULT 0,
    violation_types INT NOT NULL DEFAULT 0,
    type_31_count INT NOT NULL DEFAULT 0,
    type_61_count INT NOT NULL DEFAULT 0,
    avg_severity DECIMAL(5,2) DEFAULT 0.00,
    personal_vehicles INT NOT NULL DEFAULT 0,
    commercial_vehicles INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_date_region (summary_date, region),
    INDEX idx_summary_date (summary_date),
    INDEX idx_region (region),
    INDEX idx_area_id (area_id),
    FOREIGN KEY (area_id) REFERENCES v_area(AREA_ID) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2. Bảng: violation_by_area

```sql
CREATE TABLE violation_by_area (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    summary_date DATE NOT NULL,
    camera_id VARCHAR(100) NOT NULL,
    cam_id BIGINT,
    camera_name VARCHAR(500),
    area_id BIGINT,
    area_code VARCHAR(255),
    area_name VARCHAR(255),
    province VARCHAR(200),
    region VARCHAR(50) NOT NULL,
    violation_count INT NOT NULL DEFAULT 0,
    unique_vehicles INT NOT NULL DEFAULT 0,
    violation_rate DECIMAL(5,2) DEFAULT 0.00,
    avg_severity DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_date_camera (summary_date, camera_id),
    INDEX idx_summary_date (summary_date),
    INDEX idx_region (region),
    INDEX idx_camera_id (camera_id),
    INDEX idx_cam_id (cam_id),
    INDEX idx_area_id (area_id),
    FOREIGN KEY (cam_id) REFERENCES v_camera(CAM_ID) ON DELETE SET NULL,
    FOREIGN KEY (area_id) REFERENCES v_area(AREA_ID) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 3. Bảng: violation_by_type

```sql
CREATE TABLE violation_by_type (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    summary_date DATE NOT NULL,
    violation_type INT NOT NULL,
    vehicle_type INT NOT NULL, -- 21=ô tô, 31=xe máy, 41=xe đạp, 51=xe khách, 61=xe tải
    vehicle_type_name VARCHAR(50),
    violation_count INT NOT NULL DEFAULT 0,
    unique_vehicles INT NOT NULL DEFAULT 0,
    avg_severity DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_date_type (summary_date, violation_type),
    INDEX idx_summary_date (summary_date),
    INDEX idx_violation_type (violation_type),
    INDEX idx_vehicle_type (vehicle_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 4. Bảng: traffic_volume_daily

```sql
CREATE TABLE traffic_volume_daily (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    summary_date DATE NOT NULL,
    region VARCHAR(50) NOT NULL,
    total_volume INT NOT NULL DEFAULT 0,
    peak_hour INT,
    peak_volume INT,
    avg_hourly_volume DECIMAL(10,2) DEFAULT 0.00,
    personal_vehicles INT NOT NULL DEFAULT 0,
    commercial_vehicles INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_date_region (summary_date, region),
    INDEX idx_summary_date (summary_date),
    INDEX idx_region (region)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 5. Bảng: traffic_volume_hourly

```sql
CREATE TABLE traffic_volume_hourly (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    summary_date DATE NOT NULL,
    summary_hour INT NOT NULL,
    region VARCHAR(50) NOT NULL,
    traffic_volume INT NOT NULL DEFAULT 0,
    violation_count INT NOT NULL DEFAULT 0,
    violation_rate DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_date_hour_region (summary_date, summary_hour, region),
    INDEX idx_summary_date (summary_date),
    INDEX idx_region (region),
    INDEX idx_hour (summary_hour)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 6. Bảng: violation_trends

```sql
CREATE TABLE violation_trends (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    trend_type VARCHAR(50) NOT NULL, -- 'hourly', 'daily', 'weekly', 'monthly'
    trend_date DATE NOT NULL,
    trend_value INT, -- hour (0-23), day_of_week (1-7), day_of_month (1-31), month (1-12)
    region VARCHAR(50),
    violation_count INT NOT NULL DEFAULT 0,
    traffic_volume INT NOT NULL DEFAULT 0,
    violation_rate DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_trend (trend_type, trend_date, trend_value, region),
    INDEX idx_trend_type (trend_type),
    INDEX idx_trend_date (trend_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 7. Bảng: repeat_offenders

```sql
CREATE TABLE repeat_offenders (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    license_plate VARCHAR(20) NOT NULL,
    summary_month DATE NOT NULL, -- First day of month
    violation_count INT NOT NULL DEFAULT 0,
    violation_types TEXT, -- JSON array of violation types
    cameras TEXT, -- JSON array of camera IDs
    first_violation DATETIME,
    last_violation DATETIME,
    avg_severity DECIMAL(5,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_plate_month (license_plate, summary_month),
    INDEX idx_summary_month (summary_month),
    INDEX idx_violation_count (violation_count)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 8. Bảng: camera_performance

```sql
CREATE TABLE camera_performance (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    summary_date DATE NOT NULL,
    camera_id VARCHAR(100) NOT NULL,
    cam_id BIGINT,
    camera_name VARCHAR(500),
    area_id BIGINT,
    area_name VARCHAR(255),
    region VARCHAR(50) NOT NULL,
    violation_count INT NOT NULL DEFAULT 0,
    unique_vehicles INT NOT NULL DEFAULT 0,
    traffic_volume INT NOT NULL DEFAULT 0,
    violation_rate DECIMAL(5,2) DEFAULT 0.00,
    avg_severity DECIMAL(5,2) DEFAULT 0.00,
    uptime_percentage DECIMAL(5,2) DEFAULT 100.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_date_camera (summary_date, camera_id),
    INDEX idx_summary_date (summary_date),
    INDEX idx_region (region),
    INDEX idx_camera_id (camera_id),
    INDEX idx_cam_id (cam_id),
    INDEX idx_area_id (area_id),
    FOREIGN KEY (cam_id) REFERENCES v_camera(CAM_ID) ON DELETE SET NULL,
    FOREIGN KEY (area_id) REFERENCES v_area(AREA_ID) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## 📝 Import Reference Tables

Trước khi chạy ETL, cần import các bảng reference từ file `mysql.sql`:

```sql
-- Import v_camera
SOURCE /path/to/mysql.sql; -- Chỉ phần CREATE TABLE v_camera

-- Import v_area  
SOURCE /path/to/mysql.sql; -- Chỉ phần CREATE TABLE v_area

-- Import v_violation_code
SOURCE /path/to/mysql.sql; -- Chỉ phần CREATE TABLE v_violation_code
```

Hoặc import trực tiếp từ dump file nếu có.

## 🔄 ETL Process

### 1. Từ Spark SQL Ghi Vào MySQL

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MySQLETL") \
    .enableHiveSupport() \
    .getOrCreate()

# Đọc từ Hive
daily_summary = spark.sql("""
    SELECT 
        event_date as summary_date,
        area_id,
        area_code,
        area_name,
        province,
        region,
        total_violations,
        unique_vehicles,
        active_cameras,
        violation_types,
        type_31_count,
        type_61_count,
        avg_severity,
        personal_vehicles,
        commercial_vehicles
    FROM traffic_violations.violations_daily_summary
""")

# Ghi vào MySQL
daily_summary.write \
    .format("jdbc") \
    .option("url", "jdbc:mysql://localhost:3306/traffic_db?useSSL=false&serverTimezone=UTC") \
    .option("dbtable", "violation_daily_summary") \
    .option("user", "root") \
    .option("password", "password") \
    .option("driver", "com.mysql.cj.jdbc.Driver") \
    .mode("overwrite") \
    .save()
```

### 2. Scheduled Job (Airflow hoặc Cron)

```python
# ETL script chạy hàng ngày
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'traffic_analytics',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

dag = DAG(
    'traffic_etl_daily',
    default_args=default_args,
    description='Daily ETL from Hive to MySQL',
    schedule_interval='0 2 * * *',  # Chạy lúc 2h sáng mỗi ngày
    catchup=False
)

etl_task = BashOperator(
    task_id='run_etl',
    bash_command='spark-submit --class TrafficETL /path/to/etl_job.py',
    dag=dag
)
```

## 📊 Query Optimization

### 1. Indexes

Tất cả các bảng đã có indexes phù hợp:
- Index trên `summary_date` cho query theo thời gian
- Index trên `region` cho filter theo region
- Composite indexes cho unique constraints

### 2. Partitioning (MySQL 8.0+)

```sql
-- Partition theo tháng cho bảng lớn
ALTER TABLE violation_daily_summary
PARTITION BY RANGE (TO_DAYS(summary_date)) (
    PARTITION p202401 VALUES LESS THAN (TO_DAYS('2024-02-01')),
    PARTITION p202402 VALUES LESS THAN (TO_DAYS('2024-03-01')),
    -- ... các partition khác
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

### 3. Materialized Views (MySQL 8.0+)

```sql
-- View tổng hợp cho dashboard
CREATE VIEW dashboard_summary AS
SELECT 
    vds.summary_date,
    vds.region,
    vds.total_violations,
    vds.unique_vehicles,
    tvd.total_volume as traffic_volume,
    (vds.total_violations / tvd.total_volume * 100) as violation_rate
FROM violation_daily_summary vds
LEFT JOIN traffic_volume_daily tvd 
    ON vds.summary_date = tvd.summary_date 
    AND vds.region = tvd.region;
```

## 🔍 Sample Queries cho Superset

### 1. Query Tổng Hợp

```sql
-- Tổng hợp vi phạm theo ngày
SELECT 
    summary_date,
    SUM(total_violations) as total_violations,
    SUM(unique_vehicles) as total_vehicles,
    AVG(avg_severity) as avg_severity
FROM violation_daily_summary
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY summary_date
ORDER BY summary_date;
```

### 2. Query Theo Region

```sql
-- Top regions có nhiều vi phạm
SELECT 
    region,
    SUM(total_violations) as total_violations,
    SUM(unique_vehicles) as total_vehicles
FROM violation_daily_summary
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY region
ORDER BY total_violations DESC
LIMIT 10;
```

### 3. Query Lưu Lượng

```sql
-- Lưu lượng theo giờ
SELECT 
    summary_hour,
    AVG(traffic_volume) as avg_volume,
    AVG(violation_rate) as avg_violation_rate
FROM traffic_volume_hourly
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY summary_hour
ORDER BY summary_hour;
```

## 🎯 Kết Quả

- **Fast Queries**: Tối ưu cho query nhanh với indexes
- **Data Mart**: Dữ liệu tổng hợp sẵn cho BI
- **Scalable**: Có thể partition cho dữ liệu lớn
- **Integration**: Dễ tích hợp với Superset và các BI tools khác

## 📌 Từ Khóa Bảo Vệ

- **Data Mart**: Kho dữ liệu phân tích
- **OLAP Database**: Database tối ưu cho phân tích
- **ETL Process**: Quá trình Extract, Transform, Load
- **Query Optimization**: Tối ưu truy vấn
- **Materialized Views**: View được materialize

