# ---------------------------------------------------------------------------
# 1. IAM Role cho EMR Service (để EMR tự quản lý cluster)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "emr_service_role" {
  name = "${var.project_name}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "elasticmapreduce.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Gán quyền mặc định của AWS cho EMR Service Role
resource "aws_iam_role_policy_attachment" "emr_service_attach" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

# ---------------------------------------------------------------------------
# 2. IAM Role cho EC2 bên trong EMR Cluster (Master & Core nodes)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "emr_ec2_role" {
  name = "${var.project_name}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Gán quyền mặc định của AWS cho EMR EC2
resource "aws_iam_role_policy_attachment" "emr_ec2_attach" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# ==> Tạo Instance Profile từ Role trên (Đây là cái mà main.tf đang báo thiếu: aws_iam_instance_profile.emr_profile)
resource "aws_iam_instance_profile" "emr_profile" {
  name = "${var.project_name}-emr-profile"
  role = aws_iam_role.emr_ec2_role.name
}

# ---------------------------------------------------------------------------
# 3. IAM Role cho EC2 Superset
# ---------------------------------------------------------------------------
resource "aws_iam_role" "superset_role" {
  name = "${var.project_name}-superset-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Cấp quyền đọc S3 (để Superset có thể tải driver/config nếu cần)
resource "aws_iam_role_policy_attachment" "superset_s3_attach" {
  role       = aws_iam_role.superset_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Cấp quyền đọc Secrets Manager (để lấy password DB tự động)
resource "aws_iam_role_policy" "superset_secrets_policy" {
  name = "${var.project_name}-secrets-policy"
  role = aws_iam_role.superset_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.db_creds.arn]
    }]
  })
}

# ==> Tạo Instance Profile cho Superset (Đây là cái thiếu: aws_iam_instance_profile.ec2_profile)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-superset-profile"
  role = aws_iam_role.superset_role.name
}