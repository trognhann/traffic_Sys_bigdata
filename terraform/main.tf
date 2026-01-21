provider "aws" {
  region = "ap-southeast-1"
}

# --- 1. BIẾN ĐẦU VÀO (Sửa tên Key Pair ở đây nếu khác) ---
variable "key_name" {
  default = "bigdataLab" # <--- Tên Key Pair của bạn trên AWS
}

# --- 2. LẤY THÔNG TIN MẠNG CÓ SẴN (DEFAULT VPC) ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- 3. BẢO MẬT (SECURITY GROUPS) ---
# SG cho Master: Mở SSH (22) và HBase UI (16010)
resource "aws_security_group" "master_sg" {
  name        = "tf_emr_master_sg"
  description = "Allow SSH and HBase UI"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HBase Web UI
  # HBase Web UI - BỊ EMR CHẶN NẾU ĐỂ 0.0.0.0/0
  # AWS EMR cấm mở port công khai ngoài port 22 trên Managed Security Group.
  # Để truy cập UI, bạn nên dùng SSH Tunneling hoặc giới hạn IP cụ thể.
  # ingress {
  #   from_port   = 16010
  #   to_port     = 16010
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # Cho phép tất cả traffic ra ngoài
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG cho Core/Slave: Cho phép giao tiếp nội bộ
resource "aws_security_group" "slave_sg" {
  name        = "tf_emr_slave_sg"
  description = "EMR Slave"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Quy tắc quan trọng: Master và Slave phải nói chuyện được với nhau
resource "aws_security_group_rule" "master_to_slave" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.master_sg.id
  security_group_id        = aws_security_group.slave_sg.id
}

resource "aws_security_group_rule" "slave_to_master" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.slave_sg.id
  security_group_id        = aws_security_group.master_sg.id
}

resource "aws_security_group_rule" "slave_to_slave" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.slave_sg.id
  security_group_id        = aws_security_group.slave_sg.id
}


# --- 4. QUYỀN TRUY CẬP (IAM ROLES) ---
# Role cho EMR Service (Cluster quản lý resources)
resource "aws_iam_role" "emr_service_role" {
  name = "tf_emr_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "elasticmapreduce.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "emr_service_attach" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

# Role cho EC2 Instances (Các node trong cluster)
resource "aws_iam_role" "emr_ec2_role" {
  name = "tf_emr_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "emr_ec2_attach" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_instance_profile" "emr_ec2_profile" {
  name = "tf_emr_ec2_profile"
  role = aws_iam_role.emr_ec2_role.name
}

# --- 5. EMR CLUSTER ---
resource "aws_emr_cluster" "cluster" {
  name          = "HBase-Terraform-Lab"
  release_label = "emr-6.15.0"
  applications  = ["Hadoop", "HBase", "Spark", "ZooKeeper"]

  ec2_attributes {
    subnet_id                         = data.aws_subnets.default.ids[0]
    emr_managed_master_security_group = aws_security_group.master_sg.id
    emr_managed_slave_security_group  = aws_security_group.slave_sg.id
    instance_profile                  = aws_iam_instance_profile.emr_ec2_profile.arn
    key_name                          = var.key_name
  }

  master_instance_group {
    instance_type = "m5.xlarge"
  }

  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 2
  }

  service_role = aws_iam_role.emr_service_role.arn

  # Visible to all users in account
  visible_to_all_users = true
}

# --- 6. OUTPUT ---
output "ssh_command" {
  value = "ssh -i ${var.key_name}.pem hadoop@${aws_emr_cluster.cluster.master_public_dns}"
}

output "hbase_ui" {
  value = "http://${aws_emr_cluster.cluster.master_public_dns}:16010"
}
