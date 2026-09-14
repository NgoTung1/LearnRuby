# Hướng dẫn huấn luyện YOLOv8 Clothing Detection

## Tổng quan

Huấn luyện mô hình **YOLOv8** trên dataset **DeepFashion2** để nhận diện **13 loại trang phục**:

| ID | Class | Tiếng Việt |
|----|-------|------------|
| 0 | short_sleeve_top | Áo ngắn tay |
| 1 | long_sleeve_top | Áo dài tay |
| 2 | short_sleeve_outwear | Áo khoác ngắn tay |
| 3 | long_sleeve_outwear | Áo khoác dài tay |
| 4 | vest | Áo gile |
| 5 | sling | Áo hai dây |
| 6 | shorts | Quần đùi |
| 7 | trousers | Quần dài |
| 8 | skirt | Chân váy |
| 9 | short_sleeve_dress | Đầm ngắn tay |
| 10 | long_sleeve_dress | Đầm dài tay |
| 11 | vest_dress | Đầm gile |
| 12 | sling_dress | Đầm hai dây |

---

## Yêu cầu hệ thống

- **Python** >= 3.8
- **GPU** có VRAM >= 4GB (khuyến nghị NVIDIA GTX 1060 trở lên)
- **Dung lượng ổ đĩa:** ~30GB cho dataset + model
- Hoặc sử dụng **Google Colab** (miễn phí, có GPU T4)

---

## Bước 1: Cài đặt thư viện

```bash
pip install ultralytics tqdm Pillow
```

---

## Bước 2: Tải DeepFashion2 Dataset

DeepFashion2 là dataset nghiên cứu, cần đăng ký trước:

1. Truy cập: https://github.com/switchablenorms/DeepFashion2
2. Đọc LICENSE và điền form yêu cầu quyền truy cập
3. Tải về và giải nén, cấu trúc thư mục:

```
deepfashion2/
├── train/
│   ├── image/
│   │   ├── 000001.jpg
│   │   ├── 000002.jpg
│   │   └── ...
│   └── annos/
│       ├── 000001.json
│       ├── 000002.json
│       └── ...
└── validation/
    ├── image/
    │   └── ...
    └── annos/
        └── ...
```

---

## Bước 3: Chuyển đổi sang YOLO format

```bash
cd ai_service/training

python convert_deepfashion2.py \
    --src /đường/dẫn/tới/deepfashion2 \
    --dst ./datasets/deepfashion2_yolo
```

Kết quả sẽ tạo ra:
```
datasets/deepfashion2_yolo/
├── images/
│   ├── train/       # ~191k ảnh
│   └── validation/  # ~32k ảnh
└── labels/
    ├── train/       # ~191k file .txt
    └── validation/  # ~32k file .txt
```

---

## Bước 4: Huấn luyện model

### Trên máy có GPU:
```bash
# Train mặc định (50 epochs, batch 16, GPU 0)
python train.py

# Train với batch nhỏ hơn (nếu thiếu VRAM)
python train.py --batch 8 --imgsz 416

# Train lâu hơn để đạt accuracy cao hơn
python train.py --epochs 100 --model yolov8s.pt

# Tiếp tục train từ checkpoint
python train.py --resume
```

### Trên Google Colab (khuyến nghị nếu không có GPU):
```python
# Cell 1: Cài đặt
!pip install ultralytics

# Cell 2: Upload dataset (hoặc mount Google Drive)
from google.colab import drive
drive.mount('/content/drive')

# Cell 3: Train
from ultralytics import YOLO
model = YOLO("yolov8n.pt")
results = model.train(
    data="/content/drive/MyDrive/deepfashion2_yolo/dataset.yaml",
    epochs=50,
    imgsz=640,
    batch=16,
    name="clothing_yolov8",
    device=0
)

# Cell 4: Download model
from google.colab import files
files.download("runs/detect/clothing_yolov8/weights/best.pt")
```

---

## Bước 5: Deploy model

Sau khi train xong, copy file `best.pt` vào thư mục `ai_service/models/`:

```bash
# Nếu train trên máy local (script tự động copy)
# File đã được copy tại: ai_service/models/clothing_yolov8.pt

# Nếu train trên Colab, copy thủ công:
cp best.pt ../models/clothing_yolov8.pt
```

Sau đó rebuild Docker:
```bash
docker-compose build ai_api
docker-compose up
```

---

## Bước 6: Kiểm tra model

### Chạy validation:
```bash
python train.py --validate
```

### Test thử 1 ảnh:
```bash
# Khi AI service đang chạy
curl -X POST http://localhost:8000/detect \
  -F "file=@path/to/test_image.jpg"
```

---

## Lưu ý

- **Thời gian train:** ~2-4 giờ với GPU T4 (Colab), ~6-8 giờ với GTX 1060
- **mAP50 kỳ vọng:** 0.65 - 0.75 (YOLOv8n), 0.70 - 0.80 (YOLOv8s)
- Nếu muốn accuracy cao hơn, dùng model lớn hơn: `yolov8s.pt` hoặc `yolov8m.pt`
- Dataset DeepFashion2 khá lớn (~191k ảnh train). Nếu muốn test nhanh, có thể chỉ convert 5000-10000 ảnh đầu tiên
