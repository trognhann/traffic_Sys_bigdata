variable "region" {
  description = "AWS Region triển khai (Tokyo)"
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Tên dự án dùng làm tiền tố cho các resource"
  default     = "bigdata-lab"
}

variable "my_ip" {
  description = "Địa chỉ IP Public của bạn để SSH (Ví dụ: 1.2.3.4/32)"
  type        = string
}

variable "db_password" {
  description = "Mật khẩu cho RDS MySQL"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "Tên Key Pair đã tạo trên AWS để SSH vào EC2/EMR"
  type        = string
}