# Phân Tích Cấu Trúc File CDR (Call Detail Record)

## Tổng Quan

Các file `.txt` trong thư mục `data` chứa dữ liệu về các vi phạm giao thông được ghi lại bởi hệ thống camera giám sát. Mỗi file chứa một bản ghi duy nhất với định dạng CSV (Comma-Separated Values).

## Đặc Điểm Chung

- **Định dạng**: CSV (phân tách bằng dấu phẩy)
- **Số dòng**: Mỗi file chỉ chứa **1 dòng duy nhất**
- **Số trường**: **15 trường** được phân tách bằng dấu phẩy
- **Encoding**: UTF-8 (có thể chứa ký tự tiếng Việt)

## Cấu Trúc 15 Trường

### Trường 1: Camera ID
- **Mô tả**: Mã định danh của camera
- **Ví dụ**: `BDG_CAM_001`, `DTP_CAM_001`, `TVH_VHT_CAM_001`, `BKN_CAM_002`
- **Định dạng**: `[LOCATION]_CAM_[NUMBER]`

### Trường 2: VIN 
- **Mô tả**: Mã vi phạm, mapping với vincode trong bảng v_violation_code 
- **Ví dụ**: `VIN01`
- **Ghi chú**: Có vẻ là giá trị cố định trong hầu hết các bản ghi

### Trường 3: Timestamp
- **Mô tả**: Thời gian ghi nhận vi phạm (Unix timestamp tính bằng milliseconds)
- **Ví dụ**: `1719448991037`, `1734428712904`
- **Định dạng**: Số nguyên 13 chữ số (milliseconds từ epoch)

### Trường 4: Loại phương tiện
- **Mô tả**: Mã loại vi phạm
- **Ví dụ**: `31`, `61`: 21 ô tô, 31 xe máy, 41 xe đạp, 51 xe khách, 61 xe tải 


### Trường 5: Biển Số Xe
- **Mô tả**: Biển số xe vi phạm
- **Ví dụ**: `11H03226`, `61H172040`, `64K74018`, `66G103131`
- **Định dạng**: Biển số xe Việt Nam

### Trường 6: Đường Dẫn Video
- **Mô tả**: Đường dẫn đến file video ghi lại vi phạm
- **Ví dụ 1** (đường dẫn đầy đủ): `/2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_1719448991037_11H03226.mp4`
- **Ví dụ 2** (tên file ngắn): `TVH_VHT_CAM_001_VP_1734428706171.mp4`
- **Định dạng**: Có 2 loại:
  - Đường dẫn đầy đủ với cấu trúc: `/[YYYY]/[MM]/[DD]/[CAMERA_ID]_VIN01_[timestamp]_[sequence]_[timestamp]_[biensoxe].mp4`
  - Tên file ngắn: `[CAMERA_ID]_VP_[timestamp].mp4`

### Trường 7: Đường Dẫn Ảnh Biển Số (License Plate)
- **Mô tả**: Đường dẫn đến ảnh chụp biển số xe
- **Ví dụ 1**: `VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_lpn_1719448991037_11H03226.jpg`
- **Ví dụ 2**: `TVH_VHT_CAM_001_VP_1734428712904_64K74018_plate.jpg`
- **Định dạng**: 
  - Đường dẫn đầy đủ: `VIOLATION//[YYYY]/[MM]/[DD]/[CAMERA_ID]_VIN01_[timestamp]_[sequence]_lpn_[timestamp]_[biensoxe].jpg`
  - Tên file ngắn: `[CAMERA_ID]_VP_[timestamp]_[biensoxe]_plate.jpg`

### Trường 8: Đường Dẫn Ảnh Tổng Quan
- **Mô tả**: Đường dẫn đến ảnh tổng quan của vi phạm
- **Ví dụ 1**: `VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_1719448991037_11H03226.jpg`
- **Ví dụ 2**: `TVH_VHT_CAM_001_VP_1734428712904_64K74018.jpg`
- **Ghi chú**: Ảnh chính của vi phạm

### Trường 9: Đường Dẫn Ảnh Xe
- **Mô tả**: Đường dẫn đến ảnh chụp phương tiện
- **Ví dụ 1**: `VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_vehicle_1719448991037_11H03226.jpg`
- **Ví dụ 2**: `TVH_VHT_CAM_001_VP_1734428712904_64K74018_vehicle.jpg`
- **Định dạng**: Có từ khóa `vehicle` trong tên file

### Trường 10: Đường Dẫn Ảnh Trước Khi Vi Phạm
- **Mô tả**: Đường dẫn đến ảnh chụp trước khi vi phạm xảy ra
- **Ví dụ 1**: `VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_before_1719448991037_11H03226.jpg`
- **Ví dụ 2**: `TVH_VHT_CAM_001_VP_1734428712904_64K74018_before.jpg`
- **Định dạng**: Có từ khóa `before` trong tên file

### Trường 11: Đường Dẫn Ảnh Bổ Sung
- **Mô tả**: Đường dẫn đến ảnh bổ sung (có thể là ảnh sau khi vi phạm hoặc ảnh khác)
- **Ví dụ 1**: `VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_1719448991037_11H03226.jpg` (trùng với trường 8)
- **Ví dụ 2**: `TVH_VHT_CAM_001_VP_1734428712904_64K74018_after.jpg` (ảnh sau khi vi phạm)
- **Ghi chú**: Có thể là ảnh trùng lặp hoặc ảnh bổ sung tùy theo camera

### Trường 12: Trạng Thái Xử Lý
- **Mô tả**: Trạng thái xử lý vi phạm
- **Ví dụ**: `1`
- **Ghi chú**: Có thể là flag xác định trạng thái (1 = đã xử lý, 0 = chưa xử lý, hoặc mã trạng thái khác)

### Trường 13: Mức Độ Vi Phạm
- **Mô tả**: Mức độ nghiêm trọng của vi phạm
- **Ví dụ**: `2`, `5`, `27`
- **Ghi chú**: Có thể là điểm phạt hoặc mức độ vi phạm

### Trường 14: Màu Xe
- **Mô tả**: Màu sắc của phương tiện
- **Ví dụ**: `white`, `black`, `None`
- **Định dạng**: Tên màu bằng tiếng Anh hoặc `None` nếu không xác định được

### Trường 15: Màu Biển Số
- **Mô tả**: Màu sắc của biển số xe
- **Ví dụ**: `black`, `unknown`
- **Ghi chú**: Thường là `black` (biển số đen) hoặc `unknown` (không xác định)

## Ví Dụ Mẫu

### Ví Dụ 1: File với đường dẫn đầy đủ
```
BDG_CAM_001,VIN01,1719448991037,61,11H03226,/2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_1719448991037_11H03226.mp4,VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_lpn_1719448991037_11H03226.jpg,VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_1719448991037_11H03226.jpg,VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_vehicle_1719448991037_11H03226.jpg,VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_before_1719448991037_11H03226.jpg,VIOLATION//2024/06/27/BDG_CAM_001_VIN01_1719448991_5240_1719448991037_11H03226.jpg,1,2,None,black
```

### Ví Dụ 2: File với tên file ngắn
```
TVH_VHT_CAM_001,VIN01,1734428712904,31,64K74018,TVH_VHT_CAM_001_VP_1734428706171.mp4,TVH_VHT_CAM_001_VP_1734428712904_64K74018_plate.jpg,TVH_VHT_CAM_001_VP_1734428712904_64K74018.jpg,TVH_VHT_CAM_001_VP_1734428712904_64K74018_vehicle.jpg,TVH_VHT_CAM_001_VP_1734428712904_64K74018_before.jpg,TVH_VHT_CAM_001_VP_1734428712904_64K74018_after.jpg,1,5,white,unknown
```

## Phân Loại Camera

Dựa trên phân tích mẫu, các loại camera phổ biến bao gồm:
- `BDG_CAM_001`: Camera tại Bình Dương
- `DTP_CAM_001`: Camera tại Đồng Tháp
- `TVH_VHT_CAM_001`: Camera tại Thừa Thiên Huế
- `BKN_CAM_002`: Camera tại Bắc Kạn

## Lưu Ý Khi Xử Lý Dữ Liệu

1. **Định dạng đường dẫn**: Có 2 định dạng khác nhau tùy theo camera:
   - Đường dẫn đầy đủ với prefix `VIOLATION//` và cấu trúc thư mục theo ngày
   - Tên file ngắn không có đường dẫn đầy đủ

2. **Giá trị None**: Trường 14 (Màu Xe) có thể có giá trị `None` (dạng chuỗi, không phải NULL)

3. **Timestamp**: Timestamp ở trường 3 là milliseconds, cần chia cho 1000 để có seconds nếu cần chuyển đổi

4. **Tên file**: Tên file `.txt` có cấu trúc: `VP_[CAMERA_ID]_[BIENSOXE]_[TIMESTAMP].txt` hoặc `VP_[CAMERA_ID]_[TIMESTAMP].txt`

## Ứng Dụng

Cấu trúc này phù hợp cho:
- Phân tích dữ liệu vi phạm giao thông
- Thống kê theo camera, thời gian, loại vi phạm
- Liên kết với các file media (video, ảnh) tương ứng
- Xây dựng hệ thống quản lý vi phạm giao thông

