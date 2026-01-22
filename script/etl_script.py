from pyspark.sql import SparkSession

# Cấu hình kết nối MySQL (Lấy từ tham số hoặc Secrets Manager - ở đây hardcode demo, thực tế nên dùng boto3 lấy secret)
jdbc_url = "jdbc:mysql://YOUR_RDS_ENDPOINT:3306/datamart"
db_props = {
    "user": "admin",
    "password": "YOUR_PASSWORD",
    "driver": "com.mysql.cj.jdbc.Driver"
}

spark = SparkSession.builder \
    .appName("HBaseToMySQL") \
    .getOrCreate()

# Cấu hình HBase Catalog
catalog = ''.join("""{
    "table":{"namespace":"default", "name":"events"},
    "rowkey":"key",
    "columns":{
        "rowkey":{"cf":"rowkey", "col":"key", "type":"string"},
        "event_type":{"cf":"cf1", "col":"type", "type":"string"},
        "timestamp":{"cf":"cf1", "col":"ts", "type":"string"},
        "value":{"cf":"cf1", "col":"val", "type":"string"}
    }
}""".split())

# 1. Đọc từ HBase
df_hbase = spark.read \
    .option("catalog", catalog) \
    .format("org.apache.hadoop.hbase.spark") \
    .load()

# 2. Transform (Ví dụ: Group by event_type)
df_agg = df_hbase.groupBy("event_type").count()

# 3. Ghi vào MySQL
df_agg.write \
    .mode("overwrite") \
    .jdbc(jdbc_url, "events_agg", properties=db_props)

spark.stop()