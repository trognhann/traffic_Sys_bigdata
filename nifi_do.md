# Apache NiFi - Chi Tiết Triển Khai

## 🎯 Mục Tiêu

Thu thập và chuẩn hóa dữ liệu vi phạm giao thông từ các nguồn khác nhau, làm sạch và validate dữ liệu trước khi đẩy vào Kafka.

## 📋 Cấu Trúc Dữ Liệu Đầu Vào

Dựa trên file `cdr_struggle.md`, dữ liệu đầu vào có cấu trúc CSV với 15 trường:
1. Camera ID (VD: `BDG_CAM_001`) - Map với `CAM_CODE` trong bảng `v_camera`
2. VIN (VD: `VIN01`) - Mã vi phạm, map với `VIN_CODE` trong bảng `v_violation_code`
3. Timestamp (milliseconds)
4. Loại phương tiện (VD: `21`=ô tô, `31`=xe máy, `41`=xe đạp, `51`=xe khách, `61`=xe tải)
5. Biển số xe (VD: `11H03226`)
6. Đường dẫn video
7. Đường dẫn ảnh biển số
8. Đường dẫn ảnh tổng quan
9. Đường dẫn ảnh xe
10. Đường dẫn ảnh trước khi vi phạm
11. Đường dẫn ảnh bổ sung
12. Trạng thái xử lý
13. Mức độ vi phạm
14. Màu xe
15. Màu biển số

## 🔧 Các Processor Cần Triển Khai

### 1. GetFile / ListFile
- **Mục đích**: Đọc file `.txt` từ thư mục `data/`
- **Cấu hình**:
  - Input Directory: `/path/to/data`
  - File Filter: `.*\.txt$`
  - Keep Source File: `false` (di chuyển sau khi xử lý)
  - Polling Interval: `1 second`

### 2. ConvertRecord
- **Mục đích**: Chuyển đổi CSV sang JSON
- **Cấu hình**:
  - Record Reader: `CSVReader`
    - Schema Access Strategy: `Use String Fields From Header`
    - CSV Format: `RFC4180`
    - Schema Registry: `AvroSchemaRegistry`
  - Record Writer: `JsonRecordSetWriter`
    - Schema Access Strategy: `Inherit Record Schema`

### 3. ValidateRecord
- **Mục đích**: Validate schema và dữ liệu
- **Cấu hình**:
  - Schema Registry: `AvroSchemaRegistry`
  - Validation Strategy: `full-validation`
  - Schema: Định nghĩa schema với 15 trường
- **Validation Rules**:
  - Trường 1 (Camera ID): Không null, format `[A-Z]+_CAM_[0-9]+`, phải tồn tại trong bảng `v_camera`
  - Trường 2 (VIN): Không null, có thể map với `v_violation_code` (không bắt buộc)
  - Trường 3 (Timestamp): Không null, số nguyên 13 chữ số
  - Trường 4 (Loại phương tiện): Không null, số nguyên (21, 31, 41, 51, 61)
  - Trường 5 (Biển số): Không null, không rỗng
  - Trường 6-11 (Đường dẫn): Có thể null nhưng nếu có thì phải hợp lệ

### 4. LookupAttribute / QueryDatabaseTable
- **Mục đích**: Bổ sung thông tin camera và khu vực từ MySQL
- **Cấu hình**:
  - Database Connection: MySQL connection pool
  - Query: 
    ```sql
    SELECT 
        c.CAM_ID, c.CAM_CODE, c.CAM_NAME, c.AREA_ID, c.LOCATION,
        a.AREA_CODE, a.AREA_NAME, a.PROVINCE, a.DISTRICT, a.VILLAGE
    FROM v_camera c
    LEFT JOIN v_area a ON c.AREA_ID = a.AREA_ID
    WHERE c.CAM_CODE = ?
    ```
  - Lookup key: `camera_id` (trường 1)
  - Output attributes:
    - `camera_name`: Tên camera
    - `area_id`: ID khu vực
    - `area_code`: Mã khu vực
    - `area_name`: Tên khu vực
    - `province`: Tỉnh/Thành phố
    - `district`: Quận/Huyện
    - `village`: Phường/Xã
    - `camera_location`: Vị trí camera

### 5. LookupAttribute / QueryDatabaseTable (VIN Code)
- **Mục đích**: Bổ sung thông tin mã vi phạm
- **Cấu hình**:
  - Query:
    ```sql
    SELECT VIN_CODE, VIN_NAME, DESCRIPTION, CAR_FEE_MIN, CAR_FEE_MAX
    FROM v_violation_code
    WHERE VIN_CODE = ?
    ```
  - Lookup key: `vin` (trường 2)
  - Output attributes:
    - `violation_name`: Tên loại vi phạm
    - `violation_description`: Mô tả vi phạm
    - `car_fee_min`: Phí tối thiểu (ô tô)
    - `car_fee_max`: Phí tối đa (ô tô)

### 6. UpdateAttribute
- **Mục đích**: Chuẩn hóa và bổ sung metadata
- **Cấu hình**:
  - Thêm attributes:
    - `ingest_timestamp`: Thời gian hiện tại (ISO 8601)
    - `source_file`: Tên file gốc
    - `data_source`: `traffic_violation_camera`
    - `vehicle_type_name`: Tên loại phương tiện (dựa trên trường 4)
  - Chuẩn hóa:
    - Chuyển timestamp từ milliseconds sang ISO 8601
    - Normalize biển số (uppercase, loại bỏ khoảng trắng)
    - Map loại phương tiện: `21`→`Ô tô`, `31`→`Xe máy`, `41`→`Xe đạp`, `51`→`Xe khách`, `61`→`Xe tải`

### 7. RouteOnAttribute
- **Mục đích**: Phân loại và routing dữ liệu
- **Routes**:
  - `valid_data`: Dữ liệu hợp lệ → đẩy sang Kafka topic `traffic_violation_clean`
  - `invalid_data`: Dữ liệu không hợp lệ → lưu vào thư mục `error/` để xử lý sau
  - `duplicate_data`: Phát hiện duplicate (dựa trên Camera ID + Timestamp + Biển số) → lưu vào `duplicate/`

### 8. PublishKafkaRecord_2_6
- **Mục đích**: Đẩy dữ liệu đã làm sạch vào Kafka
- **Cấu hình**:
  - Kafka Brokers: `localhost:9092` (hoặc cluster)
  - Topic Name: `traffic_violation_clean`
  - Delivery Guarantee: `best_effort`
  - Record Writer: `JsonRecordSetWriter`
  - Partition Strategy: `Expression Language` → partition theo region (extract từ Camera ID)

## 📊 Flow Diagram

```
GetFile
  ↓
ConvertRecord (CSV → JSON)
  ↓
ValidateRecord
  ↓ (valid)
QueryDatabaseTable (Lookup Camera & Area)
  ↓
QueryDatabaseTable (Lookup VIN Code)
  ↓
UpdateAttribute (chuẩn hóa + metadata)
  ↓
RouteOnAttribute
  ├─→ valid_data → PublishKafkaRecord → Kafka
  ├─→ invalid_data → PutFile (error/)
  └─→ duplicate_data → PutFile (duplicate/)
```

## 🔍 Xử Lý Đặc Biệt

### 1. Xử Lý 2 Định Dạng Đường Dẫn
- **Định dạng 1**: Đường dẫn đầy đủ với `VIOLATION//`
- **Định dạng 2**: Tên file ngắn
- **Giải pháp**: Sử dụng `ReplaceText` processor để chuẩn hóa về format thống nhất

### 2. Xử Lý Giá Trị None
- Trường 14 (Màu xe) có thể là `None` (chuỗi)
- Chuyển thành `null` trong JSON

### 3. Xử Lý Timestamp
- Input: milliseconds (13 chữ số)
- Output: ISO 8601 format: `2024-06-27T10:23:11.037Z`
- Sử dụng Expression Language: `${timestamp:toNumber():divide(1000):toDate():format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')}`

### 4. Lookup Camera và Area từ MySQL
- Sử dụng `QueryDatabaseTable` hoặc `ExecuteSQL` processor
- Lookup dựa trên `CAM_CODE` (trường 1 - Camera ID)
- Join với bảng `v_area` để lấy thông tin khu vực
- Nếu không tìm thấy camera, đánh dấu là invalid data

### 5. Lookup VIN Code từ MySQL
- Lookup thông tin mã vi phạm từ bảng `v_violation_code`
- Bổ sung tên vi phạm, mô tả, phí phạt
- Nếu không tìm thấy, vẫn giữ nguyên VIN code gốc

## 📝 Schema Avro Mẫu

```json
{
  "type": "record",
  "name": "TrafficViolation",
  "fields": [
    {"name": "camera_id", "type": "string"},
    {"name": "camera_name", "type": ["null", "string"], "default": null},
    {"name": "area_id", "type": ["null", "long"], "default": null},
    {"name": "area_code", "type": ["null", "string"], "default": null},
    {"name": "area_name", "type": ["null", "string"], "default": null},
    {"name": "province", "type": ["null", "string"], "default": null},
    {"name": "district", "type": ["null", "string"], "default": null},
    {"name": "village", "type": ["null", "string"], "default": null},
    {"name": "vin", "type": ["null", "string"], "default": null},
    {"name": "violation_name", "type": ["null", "string"], "default": null},
    {"name": "violation_description", "type": ["null", "string"], "default": null},
    {"name": "timestamp", "type": "long"},
    {"name": "timestamp_iso", "type": "string"},
    {"name": "vehicle_type", "type": "int"},
    {"name": "vehicle_type_name", "type": ["null", "string"], "default": null},
    {"name": "license_plate", "type": "string"},
    {"name": "video_path", "type": ["null", "string"], "default": null},
    {"name": "plate_image_path", "type": ["null", "string"], "default": null},
    {"name": "overview_image_path", "type": ["null", "string"], "default": null},
    {"name": "vehicle_image_path", "type": ["null", "string"], "default": null},
    {"name": "before_image_path", "type": ["null", "string"], "default": null},
    {"name": "additional_image_path", "type": ["null", "string"], "default": null},
    {"name": "processing_status", "type": "int"},
    {"name": "violation_severity", "type": "int"},
    {"name": "vehicle_color", "type": ["null", "string"], "default": null},
    {"name": "plate_color", "type": ["null", "string"], "default": null},
    {"name": "region", "type": ["null", "string"], "default": null},
    {"name": "camera_location", "type": ["null", "string"], "default": null},
    {"name": "ingest_timestamp", "type": "string"},
    {"name": "source_file", "type": "string"}
  ]
}
```

## 🎯 Output

- **Topic Kafka**: `traffic_violation_clean`
- **Format**: JSON với schema chuẩn
- **Throughput**: Hỗ trợ xử lý 500k-1 triệu bản ghi/ngày
- **Error Handling**: Tách riêng dữ liệu lỗi để xử lý sau

## 📌 Từ Khóa Bảo Vệ

- **Data Ingestion**: Thu thập dữ liệu từ nhiều nguồn
- **Data Cleansing**: Làm sạch và validate dữ liệu
- **Schema Normalization**: Chuẩn hóa schema và format
- **Error Handling**: Xử lý lỗi và duplicate detection
- **Metadata Enrichment**: Bổ sung metadata cho dữ liệu
- **Data Enrichment**: Bổ sung thông tin từ database (camera, area, violation code)
- **Lookup Processing**: Tra cứu thông tin reference từ MySQL

