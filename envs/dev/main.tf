data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"] # EMR, RDS
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"] # Superset, NAT

  enable_nat_gateway = true
  single_nat_gateway = true # Tiết kiệm chi phí lab
}


# Security Groups

# 1. Security Group cho Superset (EC2)
resource "aws_security_group" "superset" {
  name   = "${var.project_name}-superset-sg"
  vpc_id = module.vpc.vpc_id

  # SSH - Chỉ cho phép từ IP của bạn
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # cidr_blocks = [var.my_ip]
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Security Group cho RDS MySQL
resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = module.vpc.vpc_id

  # Cho phép Superset truy cập MySQL
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.superset.id]
  }

  # Cho phép các resource trong Private Subnets (như EMR) truy cập
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Security Group cho EMR Cluster
resource "aws_security_group" "emr" {
  name   = "${var.project_name}-emr-sg"
  vpc_id = module.vpc.vpc_id

  # Cho phép giao tiếp nội bộ giữa các node EMR (Master <-> Core)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  
  # SSH vào Master node từ máy của bạn (Optional - để debug)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "emr_service_access" {
  name   = "${var.project_name}-emr-service-access-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.emr.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# S3 Buckets
resource "aws_s3_bucket" "data" { bucket = "${var.project_name}-data-${random_id.suffix.hex}" }
resource "aws_s3_bucket" "logs" { bucket = "${var.project_name}-logs-${random_id.suffix.hex}" }
resource "random_id" "suffix" { byte_length = 4 }

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "My DB Subnet Group"
  }
}
# RDS MySQL
resource "aws_db_instance" "datamart" {
  identifier           = "${var.project_name}-db"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.medium"
  db_name              = "datamart"
  username             = "admin"
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  
  # Lab optimization
  multi_az = false
}

# Secrets Manager (Lưu thông tin DB để EMR/Superset lấy)
resource "aws_secretsmanager_secret" "db_creds" {
#   name = "${var.project_name}/db-creds"
  name = "${var.project_name}/db-creds-${random_id.suffix.hex}"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "db_creds_val" {
  secret_id     = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    username = aws_db_instance.datamart.username
    password = var.db_password
    host     = aws_db_instance.datamart.address
    dbname   = aws_db_instance.datamart.db_name
  })
}



resource "aws_emr_cluster" "hbase_cluster" {
  name          = "${var.project_name}-hbase"
  release_label = "emr-6.10.0" # Có HBase 2.4.13, Spark 3.3.1
  applications  = ["Hadoop", "HBase", "Spark", "Hive"]
  depends_on = [ module.vpc ]
  ec2_attributes {
    subnet_id                         = module.vpc.private_subnets[0]
    emr_managed_master_security_group = aws_security_group.emr.id
    emr_managed_slave_security_group  = aws_security_group.emr.id
    service_access_security_group     = aws_security_group.emr_service_access.id
    instance_profile                  = aws_iam_instance_profile.emr_profile.arn
    key_name                          = var.key_name
  }

  master_instance_group {
    instance_type = "m5.xlarge"
    instance_count = 1
  }

  core_instance_group {
    instance_type = "m5.xlarge"
    instance_count = 2
  }

  log_uri = "s3://${aws_s3_bucket.logs.id}/emr-logs/"
  
  service_role = aws_iam_role.emr_service_role.arn
  
  # Bootstrap action (Optional): Cài thêm thư viện Python nếu cần
#   bootstrap_action {
#     path = "s3://${aws_s3_bucket.data.id}/scripts/bootstrap.sh"
#     name = "InstallDependencies"
#   }
}


# resource "aws_instance" "superset" {
#   ami           = "ami-0df7a207adb9748c7" # Amazon Linux 2023 (check region!)
#   instance_type = "t3.large" # Superset cần RAM > 4GB để build assets nếu cần
#   subnet_id     = module.vpc.public_subnets[0]
#   key_name      = var.key_name
#   vpc_security_group_ids = [aws_security_group.superset.id]
#   iam_instance_profile = aws_iam_instance_profile.ec2_profile.name # Cần quyền đọc S3/Secrets

#   user_data = file("${path.module}/../../scripts/user_data_superset.sh")

#   tags = { Name = "Superset-Server" }
# }

resource "aws_instance" "superset" {
#   ami                    = "ami-06c4be2792f419b7b" # Amazon Linux 2023 (ap-southeast-1)
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.large"
  subnet_id              = module.vpc.public_subnets[0]
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.superset.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  tags = { Name = "Superset-Server" }

  # Sửa đoạn này: Nhúng script trực tiếp vào đây thay vì dùng file()
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker git
    service docker start
    usermod -a -G docker ec2-user
    chkconfig docker on

    # Cài Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Setup thư mục làm việc
    mkdir -p /home/ec2-user/superset
    cd /home/ec2-user/superset

    # Tạo file docker-compose.yml
    cat <<EZY > docker-compose.yml
    version: '3'
    services:
      superset:
        image: apache/superset
        ports:
          - "8088:8088"
        environment:
          - SUPERSET_SECRET_KEY=my-super-secret-key-change-me
        command: >
          bash -c "
            superset fab create-admin --username admin --firstname Superset --lastname Admin --email admin@fab.org --password admin &&
            superset db upgrade &&
            superset init &&
            /usr/bin/run-server.sh"
    EZY

    # Chạy container
    /usr/local/bin/docker-compose up -d
    echo "Waiting for Superset container..."
    sleep 180

    echo "Installing MySQL Drivers..."
    docker exec -u root superset_container pip install pymysql cryptography pkg-config

    echo "Restarting Superset..."
    docker restart superset_container
  EOF
}