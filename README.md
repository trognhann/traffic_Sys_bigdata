# traffic_Sys_bigdataDưới đây là **stack nâng cao** và **nên làm cụ thể gì ở từng bước**, bám sát **bài toán bản tin vi phạm giao thông** và đúng chuẩn **môn Phân tích dữ liệu lớn** (dễ bảo vệ, dễ ghi điểm).

---

## 🧱 Tổng thể kiến trúc (stack nâng cao)
```
Nguồn bản tin
   ↓
Apache NiFi
   ↓
Apache Kafka
   ↓
Spark Streaming / Spark SQL
   ↓
HBase / HDFS
   ↓
MySQL (Data Mart)
   ↓
Apache Superset
```

---

## 1️⃣ Apache NiFi – Thu thập & chuẩn hóa dữ liệu

🎯 **Mục tiêu**: Ingest + làm sạch dữ liệu đầu vào

### Nên làm gì?

* Nhận bản tin từ:

  * API
  * File JSON / CSV
  * TCP / HTTP
* Xử lý:

  * Validate schema
  * Loại bản tin lỗi
  * Chuẩn hóa trường (thời gian, biển số, loại vi phạm)
  * Gắn metadata (nguồn, thời điểm ingest)

* bổ sung dữ liệu:
  * trong mysql.sql có cấu trúc 2 bảng v_camera và v_area tương ứng với bảng thông tin camera và thông tin khu vực
  * mỗi camera thuộc 1 khu vực duy nhất, mỗi khu vực có thể có nhiều camera
  * Từ bản tin gốc, bổ sung thêm các thuộc tính vào bản tin để xác định được bản tin thu thập được từ camera nào, khu vực nào. điều kiện map thông qua mã camera (Camera ID)


### Processor nên dùng

* ConsumeHTTP / ListenTCP
* JoltTransformJSON
* UpdateAttribute
* RouteOnAttribute

👉 **Output**: bản tin sạch, JSON chuẩn → đẩy sang Kafka

📌 **Từ khóa bảo vệ**: *Data ingestion, data cleansing, schema normalization*

---

## 2️⃣ Apache Kafka – Message queue & streaming backbone

🎯 **Mục tiêu**: Đệm dữ liệu & tách hệ thống

![Image](https://www.cloudkarafka.com/img/blog/apache-kafka-partition.png)

![Image](https://images.ctfassets.net/8vofjvai1hpv/3UHKmM3EKx4uC7pQKu7DAE/b6733704bf885d6228eb476433b6378e/producer.png)

### Nên làm gì?

* Tạo topic:

  * `traffic_violation_raw`
  * `traffic_violation_clean`
* Partition theo:

  * Khu vực
  * Thời gian
* Giữ dữ liệu vài ngày để replay

👉 Kafka giúp:

* Chịu tải lớn
* Replay dữ liệu khi Spark lỗi
* Mở rộng nhiều consumer

📌 **Từ khóa bảo vệ**: *Decoupling, fault tolerance, high throughput*

---

## 3️⃣ Spark Streaming – Phân tích thời gian thực

🎯 **Mục tiêu**: Xử lý streaming + thống kê nhanh

![Image](https://spark.apache.org/docs/3.5.7/img/structured-streaming-example-model.png)

![Image](https://www.databricks.com/wp-content/uploads/2017/05/mapping-of-event-time-to-overlapping-windows-of-length-10-mins-and-sliding-interval-5-mins.png)

### Nên làm gì?

* Đọc dữ liệu từ Kafka
* Áp dụng:

  * Window (5 phút, 1 giờ)
  * Group theo:

    * Địa bàn
    * Loại vi phạm
    * Thời gian
* Tính:

  * Số vụ vi phạm
  * Tỷ lệ tăng/giảm
  * Điểm nóng (hotspot)

👉 Có thể demo **near real-time analytics**

📌 **Từ khóa bảo vệ**: *Streaming analytics, window aggregation*

---

## 4️⃣ HBase / HDFS – Lưu trữ dữ liệu lớn

🎯 **Mục tiêu**: Lưu raw + lịch sử dài hạn

![Image](https://chase-seibert.github.io/blog/images/hbase_tables.png)

![Image](https://dz2cdn1.dzone.com/storage/temp/14013344-data-lake-architecture.jpg)

### HBase

* Lưu:

  * Bản tin gốc
  * Dữ liệu bán cấu trúc
* Thiết kế rowkey:

  ```
  region#timestamp#id
  ```

### HDFS (hoặc S3)

* Lưu file Parquet
* Phục vụ Spark SQL / Hive

📌 **Từ khóa bảo vệ**: *Distributed storage, scalable NoSQL*

---

## 5️⃣ Spark SQL / Hive – Phân tích batch

🎯 **Mục tiêu**: Phân tích sâu, lịch sử

![Image](https://dezyre.gumlet.io/images/blog/Spark%2BSQL%2Bfor%2BRelational%2BBig%2BData%2BProcessing/Spark%2BSQL%2BArchitecture.jpg?dpr=2.6\&w=376)

![Image](https://www.aegissofttech.com/articles/images/advance-analytics-hive.jpg)

### Nên làm gì?

* Tổng hợp:

  * Theo ngày / tháng
  * Theo địa bàn
  * Theo loại vi phạm
* Phát hiện xu hướng:

  * Giờ cao điểm
  * Khu vực thường xuyên vi phạm

👉 Output dạng bảng → đẩy sang MySQL

📌 **Từ khóa bảo vệ**: *OLAP, batch analytics*

---

## 6️⃣ MySQL – Data Mart cho BI

🎯 **Mục tiêu**: Phục vụ dashboard nhanh

### Nên làm gì?

* Lưu bảng:

  * `violation_daily_summary`
  * `violation_by_area`
* Dữ liệu đã:

  * Tổng hợp
  * Nhẹ
  * Tối ưu truy vấn

📌 **Từ khóa bảo vệ**: *Data mart, analytical database*

---

## 7️⃣ Apache Superset – Trực quan hóa & báo cáo

🎯 **Mục tiêu**: Hiển thị kết quả phân tích

![Image](https://images.ctfassets.net/o7xu9whrs0u9/6Owclv6qrvPxVgH69nMb5D/1c69db45a5b976209d84100caa5d9f65/Superset_Community_Metrics.png)

![Image](https://www.slideteam.net/media/catalog/product/cache/1280x720/d/a/dashboard_for_big_data_management_big_data_analytics_and_management_slide01.jpg)

### Nên làm gì?

* Dashboard:

  * Số vi phạm theo thời gian
  * Heatmap theo khu vực
  * Top lỗi vi phạm
* Filter:

  * Ngày
  * Địa bàn
  * Loại vi phạm

📌 **Từ khóa bảo vệ**: *Decision support system*

---

## 8️⃣ Nếu giảng viên hỏi: “Big Data ở đâu?”

👉 Trả lời gọn:

* Streaming data (NiFi, Kafka)
* Distributed processing (Spark)
* Distributed storage (HBase, HDFS)
* Phân tích + trực quan hóa (Superset)

---

## ✅ Kết luận

**Stack nâng cao này:**

* Rất đúng môn
* Có chiều sâu kỹ thuật
* Dễ mở rộng khi bảo vệ

👉 Nếu bạn muốn, mình có thể:

* Chọn **phần nào làm demo, phần nào mô tả**
* Viết **mục tiêu + đóng góp khoa học** cho đồ án
* Soạn **slide bảo vệ theo từng bước**
