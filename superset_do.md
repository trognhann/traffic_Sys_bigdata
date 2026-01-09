# Apache Superset - Chi Tiết Triển Khai

## 🎯 Mục Tiêu

Tạo dashboard trực quan hóa dữ liệu vi phạm giao thông và lưu lượng giao thông, hỗ trợ ra quyết định.

## 📊 Database Connection

### 1. Kết Nối MySQL

```python
# Trong Superset UI:
# Database → Add Database

Database Name: Traffic Violations DB
SQLAlchemy URI: mysql+pymysql://root:password@localhost:3306/traffic_db?charset=utf8mb4
```

### 2. Import Tables

- `violation_daily_summary`
- `violation_by_area`
- `violation_by_type`
- `traffic_volume_daily`
- `traffic_volume_hourly`
- `violation_trends`
- `repeat_offenders`
- `camera_performance`

## 📈 Dashboards Cần Tạo

### 1. Dashboard: Tổng Quan Vi Phạm Giao Thông

#### 1.1. Chart: Tổng Số Vi Phạm Theo Thời Gian
- **Type**: Line Chart
- **Query**:
```sql
SELECT 
    summary_date as date,
    SUM(total_violations) as violations
FROM violation_daily_summary
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY summary_date
ORDER BY summary_date
```
- **Metrics**: Sum of violations
- **Time Grain**: Day

#### 1.2. Chart: Vi Phạm Theo Region
- **Type**: Bar Chart
- **Query**:
```sql
SELECT 
    region,
    SUM(total_violations) as violations
FROM violation_daily_summary
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY region
ORDER BY violations DESC
```
- **Metrics**: Sum of violations
- **Group By**: region

#### 1.3. Chart: Top 10 Camera Có Nhiều Vi Phạm
- **Type**: Table
- **Query**:
```sql
SELECT 
    camera_id,
    region,
    SUM(violation_count) as total_violations,
    AVG(violation_rate) as avg_violation_rate
FROM violation_by_area
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY camera_id, region
ORDER BY total_violations DESC
LIMIT 10
```

#### 1.4. Chart: Phân Bố Vi Phạm Theo Loại
- **Type**: Pie Chart
- **Query**:
```sql
SELECT 
    violation_type,
    SUM(violation_count) as count
FROM violation_by_type
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY violation_type
ORDER BY count DESC
```

#### 1.5. Chart: Heatmap Vi Phạm Theo Region và Thời Gian
- **Type**: Heatmap
- **Query**:
```sql
SELECT 
    region,
    DAYOFWEEK(summary_date) as day_of_week,
    SUM(total_violations) as violations
FROM violation_daily_summary
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY region, DAYOFWEEK(summary_date)
```

### 2. Dashboard: Lưu Lượng Giao Thông

#### 2.1. Chart: Lưu Lượng Theo Giờ
- **Type**: Line Chart
- **Query**:
```sql
SELECT 
    summary_hour as hour,
    AVG(traffic_volume) as avg_volume,
    MAX(traffic_volume) as max_volume
FROM traffic_volume_hourly
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY summary_hour
ORDER BY summary_hour
```

#### 2.2. Chart: Peak Hours
- **Type**: Bar Chart
- **Query**:
```sql
SELECT 
    summary_hour as hour,
    AVG(traffic_volume) as avg_volume
FROM traffic_volume_hourly
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY summary_hour
ORDER BY avg_volume DESC
LIMIT 10
```

#### 2.3. Chart: Lưu Lượng Theo Region
- **Type**: Bar Chart
- **Query**:
```sql
SELECT 
    region,
    SUM(total_volume) as total_volume,
    AVG(avg_hourly_volume) as avg_hourly
FROM traffic_volume_daily
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY region
ORDER BY total_volume DESC
```

#### 2.4. Chart: Tỷ Lệ Vi Phạm / Lưu Lượng
- **Type**: Line Chart
- **Query**:
```sql
SELECT 
    summary_hour as hour,
    AVG(violation_rate) as avg_rate
FROM traffic_volume_hourly
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY summary_hour
ORDER BY summary_hour
```

### 3. Dashboard: Phân Tích Xu Hướng

#### 3.1. Chart: Xu Hướng Vi Phạm Theo Giờ Trong Ngày
- **Type**: Line Chart
- **Query**:
```sql
SELECT 
    trend_value as hour,
    AVG(violation_count) as avg_violations
FROM violation_trends
WHERE trend_type = 'hourly'
    AND trend_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY trend_value
ORDER BY trend_value
```

#### 3.2. Chart: Xu Hướng Vi Phạm Theo Ngày Trong Tuần
- **Type**: Bar Chart
- **Query**:
```sql
SELECT 
    CASE trend_value
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END as day_name,
    AVG(violation_count) as avg_violations
FROM violation_trends
WHERE trend_type = 'weekly'
    AND trend_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
GROUP BY trend_value
ORDER BY trend_value
```

#### 3.3. Chart: Xu Hướng Theo Tháng
- **Type**: Line Chart
- **Query**:
```sql
SELECT 
    DATE_FORMAT(trend_date, '%Y-%m') as month,
    SUM(violation_count) as total_violations
FROM violation_trends
WHERE trend_type = 'monthly'
    AND trend_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(trend_date, '%Y-%m')
ORDER BY month
```

### 4. Dashboard: Xe Vi Phạm Nhiều Lần

#### 4.1. Chart: Top 20 Xe Vi Phạm Nhiều Nhất
- **Type**: Table
- **Query**:
```sql
SELECT 
    license_plate,
    summary_month,
    violation_count,
    violation_types,
    cameras,
    first_violation,
    last_violation,
    avg_severity
FROM repeat_offenders
WHERE summary_month >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
ORDER BY violation_count DESC
LIMIT 20
```

#### 4.2. Chart: Phân Bố Số Lần Vi Phạm
- **Type**: Histogram
- **Query**:
```sql
SELECT 
    CASE 
        WHEN violation_count = 1 THEN '1 time'
        WHEN violation_count BETWEEN 2 AND 3 THEN '2-3 times'
        WHEN violation_count BETWEEN 4 AND 5 THEN '4-5 times'
        WHEN violation_count > 5 THEN '6+ times'
    END as violation_range,
    COUNT(*) as vehicle_count
FROM repeat_offenders
WHERE summary_month >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
GROUP BY violation_range
```

### 5. Dashboard: Hiệu Quả Camera

#### 5.1. Chart: Hiệu Quả Camera Theo Region
- **Type**: Bar Chart
- **Query**:
```sql
SELECT 
    region,
    AVG(violation_count) as avg_violations,
    AVG(violation_rate) as avg_rate,
    AVG(uptime_percentage) as avg_uptime
FROM camera_performance
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY region
ORDER BY avg_violations DESC
```

#### 5.2. Chart: Camera Có Vấn Đề
- **Type**: Table
- **Query**:
```sql
SELECT 
    camera_id,
    region,
    AVG(violation_count) as avg_violations,
    AVG(uptime_percentage) as avg_uptime
FROM camera_performance
WHERE summary_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY camera_id, region
HAVING avg_uptime < 95 OR avg_violations < 5
ORDER BY avg_uptime ASC
```

## 🎨 Customization

### 1. Filters

Tạo filters chung cho dashboard:
- **Date Range**: Filter theo khoảng thời gian
- **Region**: Filter theo region
- **Violation Type**: Filter theo loại vi phạm

### 2. Alerts

Cấu hình alerts:
- Alert khi số vi phạm vượt ngưỡng
- Alert khi camera có uptime < 95%
- Alert khi có xe vi phạm > 5 lần trong tháng

### 3. Refresh Schedule

- Auto-refresh mỗi 5 phút cho real-time dashboard
- Auto-refresh mỗi 1 giờ cho dashboard tổng hợp

## 📱 Mobile Responsive

Đảm bảo dashboard hiển thị tốt trên mobile:
- Sử dụng responsive charts
- Tối ưu layout cho màn hình nhỏ
- Touch-friendly controls

## 🔐 Security

### 1. User Roles

- **Admin**: Full access
- **Analyst**: Read-only access, có thể tạo chart
- **Viewer**: Chỉ xem dashboard

### 2. Row Level Security

```python
# Trong Superset config
ROW_LEVEL_SECURITY = {
    'traffic_db': {
        'violation_daily_summary': {
            'filter': 'region IN (SELECT region FROM user_regions WHERE user_id = CURRENT_USER())'
        }
    }
}
```

## 🎯 Kết Quả

- **Visualization**: Trực quan hóa dữ liệu đẹp và dễ hiểu
- **Interactive**: Dashboard tương tác với filters
- **Real-time**: Cập nhật dữ liệu gần real-time
- **Decision Support**: Hỗ trợ ra quyết định

## 📌 Từ Khóa Bảo Vệ

- **Business Intelligence**: Trí tuệ kinh doanh
- **Data Visualization**: Trực quan hóa dữ liệu
- **Dashboard**: Bảng điều khiển
- **Decision Support System**: Hệ thống hỗ trợ ra quyết định
- **Self-Service BI**: BI tự phục vụ

