# 🧠 AI Stylist — Training & Evaluation Guide

## Kiến trúc Two-Stage Pipeline

```
Ảnh trang phục
     │
     ▼
  YOLOv8 Detector ──→ Bounding Boxes
     │
     ▼
  Post-Processing  ──→ Bbox expand 15% + Blur filter + Letterbox
     │
     ▼
  ResNet50 Classifier ──→ Phân loại 13 class trang phục
     │
     ▼
  Annotated Image + Gemini AI ──→ Lời khuyên trang phục
```

---

## Bước 1: Chuẩn bị Dataset

### Download DeepFashion2
Tải từ [DeepFashion2 GitHub](https://github.com/switchablenorms/DeepFashion2):
```
deepfashion2/
├── train/
│   ├── image/       ← ảnh training
│   └── annos/       ← annotation JSON
└── validation/
    ├── image/
    └── annos/
```

### Convert Dataset
```bash
cd ai_service/training

pip install tqdm Pillow

# Convert → tạo cả 2 format:
#   YOLO format (cho YOLOv8 Detector)
#   ImageFolder format (cho ResNet50 Classifier)
python convert_deepfashion2.py \
    --src /path/to/deepfashion2 \
    --dst ./datasets/deepfashion2_yolo \
    --cls-dst ./datasets/deepfashion2_cls
```

Output:
```
datasets/
├── deepfashion2_yolo/     ← YOLO format (Stage 1)
│   ├── images/train/
│   ├── images/val/
│   ├── labels/train/
│   └── labels/val/
└── deepfashion2_cls/      ← ImageFolder (Stage 2)
    ├── train/
    │   ├── short_sleeve_top/
    │   ├── long_sleeve_top/
    │   ├── ...
    │   └── sling_dress/
    └── val/
        ├── short_sleeve_top/
        └── ...
```

---

## Bước 2: Train Models

### Train YOLOv8 Detector (Stage 1)
```bash
python train.py

# Hoặc trên Google Colab (khuyến nghị nếu không có GPU):
# 1. Upload datasets/deepfashion2_yolo/ lên Drive
# 2. Chạy: !python train.py --device 0
```

Output: `../models/clothing_yolov8.pt`

### Train ResNet50 Classifier (Stage 2)
```bash
python train_classifier.py \
    --data ./datasets/deepfashion2_cls \
    --epochs 50 \
    --batch 32 \
    --lr 1e-4

# Kỹ thuật training (giống bài Garbage Classification):
# - Transfer Learning: ResNet50 pretrained ImageNet
# - Freeze backbone: chỉ train layer4 + fc
# - Label Smoothing: CrossEntropyLoss(label_smoothing=0.1)
# - CosineAnnealingLR: learning rate giảm theo cosine
# - AdamW: optimizer với weight decay regularization
```

Output: `../models/clothing_resnet50.pth`

---

## Bước 3: Evaluate Models 📊

### Evaluate Classifier (ResNet50)
```bash
python evaluate.py \
    --mode classifier \
    --data ./datasets/deepfashion2_cls \
    --weights ../models/clothing_resnet50.pth \
    --output ./eval_results

# Output:
# eval_results/
# ├── confusion_matrix.png          ← Ma trận nhầm lẫn (seaborn heatmap)
# ├── per_class_metrics.png         ← Precision/Recall/F1 từng class
# ├── confidence_distribution.png   ← Phân bố confidence correct vs incorrect
# └── evaluation_report.txt         ← Classification report đầy đủ
```

### Evaluate Detector (YOLOv8)
```bash
python evaluate.py \
    --mode detector \
    --data dataset.yaml \
    --weights ../models/clothing_yolov8.pt

# Output: mAP@50, mAP@50-95, per-class AP, PR curves
# (tự động lưu bởi ultralytics tại runs/)
```

### Test Full Pipeline
```bash
# Tạo thư mục test_images/ chứa vài ảnh trang phục
python evaluate.py \
    --mode pipeline \
    --images ./test_images \
    --weights-yolo ../models/clothing_yolov8.pt \
    --weights-cls ../models/clothing_resnet50.pth

# Output: ảnh annotated + bảng thống kê detection
```

---

## Bước 4: Deploy

```bash
# Copy weights vào thư mục models/
cp models/clothing_yolov8.pt ../models/
cp models/clothing_resnet50.pth ../models/

# Build & run Docker
cd ../..
docker-compose build
docker-compose up

# Test: http://localhost:3000 → Chatbot → 📷 Upload ảnh
```

---

## Chạy trên Google Colab (miễn phí GPU)

```python
# Cell 1: Setup
!pip install ultralytics torchvision seaborn scikit-learn tqdm

# Cell 2: Mount Drive (nếu dataset trên Drive)
from google.colab import drive
drive.mount('/content/drive')

# Cell 3: Convert dataset
!python convert_deepfashion2.py --src /content/drive/MyDrive/deepfashion2

# Cell 4: Train YOLO
!python train.py --device 0

# Cell 5: Train Classifier
!python train_classifier.py --data ./datasets/deepfashion2_cls --device 0

# Cell 6: Evaluate
!python evaluate.py --mode classifier --data ./datasets/deepfashion2_cls
!python evaluate.py --mode detector --data dataset.yaml

# Cell 7: Download weights
from google.colab import files
files.download('../models/clothing_yolov8.pt')
files.download('../models/clothing_resnet50.pth')
```

---

## 13 Class trang phục (DeepFashion2)

| ID | English | Tiếng Việt | Mức giữ ấm |
|----|---------|------------|-------------|
| 0 | short_sleeve_top | Áo ngắn tay | Mát |
| 1 | long_sleeve_top | Áo dài tay | Ấm vừa |
| 2 | short_sleeve_outwear | Áo khoác ngắn tay | Ấm vừa |
| 3 | long_sleeve_outwear | Áo khoác dài tay | Ấm |
| 4 | vest | Áo gile | Mát |
| 5 | sling | Áo hai dây | Rất mát |
| 6 | shorts | Quần đùi | Mát |
| 7 | trousers | Quần dài | Ấm vừa |
| 8 | skirt | Chân váy | Mát |
| 9 | short_sleeve_dress | Đầm ngắn tay | Mát |
| 10 | long_sleeve_dress | Đầm dài tay | Ấm vừa |
| 11 | vest_dress | Đầm gile | Mát |
| 12 | sling_dress | Đầm hai dây | Rất mát |
