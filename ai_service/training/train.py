"""
Train YOLOv8 trên DeepFashion2 dataset để nhận diện 13 loại trang phục.

Yêu cầu:
    1. Đã chạy convert_deepfashion2.py để tạo dataset YOLO format
    2. GPU có VRAM >= 4GB (khuyến nghị) hoặc dùng Google Colab

Usage:
    # Train với GPU (khuyến nghị)
    python train.py

    # Train với CPU (chậm, chỉ nên dùng khi test)
    python train.py --device cpu

    # Train với batch size nhỏ hơn (nếu thiếu VRAM)
    python train.py --batch 8 --imgsz 416

    # Resume training từ checkpoint
    python train.py --resume
"""

import argparse
import shutil
from pathlib import Path
from ultralytics import YOLO


def train(args):
    print("=" * 60)
    print("YOLOv8 Clothing Detection - Training")
    print("=" * 60)

    # Load base model (pretrained on COCO)
    if args.resume:
        # Resume from last checkpoint
        model_path = Path("runs/detect/clothing_yolov8/weights/last.pt")
        if not model_path.exists():
            print(f"[ERROR] Không tìm thấy checkpoint tại: {model_path}")
            print("[ERROR] Hãy train từ đầu (bỏ flag --resume)")
            return
        print(f"[RESUME] Tiếp tục training từ: {model_path}")
        model = YOLO(str(model_path))
    else:
        # Khởi tạo từ YOLOv8 nano pretrained trên COCO
        base_model = args.model
        print(f"[INIT] Sử dụng base model: {base_model}")
        model = YOLO(base_model)

    # Training configuration
    print(f"\n[CONFIG]")
    print(f"  Dataset: {args.data}")
    print(f"  Epochs: {args.epochs}")
    print(f"  Image size: {args.imgsz}")
    print(f"  Batch size: {args.batch}")
    print(f"  Device: {args.device}")
    print(f"  Workers: {args.workers}")
    print()

    # Train model
    results = model.train(
        data=args.data,
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        name="clothing_yolov8",
        device=args.device,
        workers=args.workers,
        patience=15,          # Early stopping nếu không cải thiện sau 15 epochs
        save=True,            # Lưu checkpoint
        save_period=10,       # Lưu checkpoint mỗi 10 epochs
        plots=True,           # Tạo biểu đồ training
        cos_lr=True,          # Cosine learning rate scheduler
        optimizer="AdamW",    # Optimizer
        lr0=0.001,            # Initial learning rate
        lrf=0.01,             # Final learning rate (lr0 * lrf)
        weight_decay=0.0005,
        warmup_epochs=3,
        mosaic=1.0,           # Mosaic augmentation
        flipud=0.5,           # Vertical flip augmentation
        fliplr=0.5,           # Horizontal flip augmentation
        hsv_h=0.015,          # HSV-Hue augmentation
        hsv_s=0.7,            # HSV-Saturation augmentation
        hsv_v=0.4,            # HSV-Value augmentation
        degrees=10.0,         # Rotation augmentation
        translate=0.1,        # Translation augmentation
        scale=0.5,            # Scale augmentation
    )

    # Copy best weights to deployment location
    best_weights = Path("runs/detect/clothing_yolov8/weights/best.pt")
    deploy_path = Path("../models/clothing_yolov8.pt")

    if best_weights.exists():
        deploy_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(best_weights, deploy_path)
        print("\n" + "=" * 60)
        print(f"[SUCCESS] Training hoàn thành!")
        print(f"[SUCCESS] Best model đã copy tới: {deploy_path}")
        print("=" * 60)
        print("\nBước tiếp theo:")
        print("  1. Rebuild Docker: docker-compose build ai_api")
        print("  2. Khởi động lại: docker-compose up")
    else:
        print("\n[WARNING] Không tìm thấy best.pt")
        print("[WARNING] Kiểm tra lại training logs")

    return results


def validate(args):
    """Chạy validation trên model đã train."""
    model_path = Path("runs/detect/clothing_yolov8/weights/best.pt")
    if not model_path.exists():
        model_path = Path("../models/clothing_yolov8.pt")

    if not model_path.exists():
        print("[ERROR] Không tìm thấy model. Hãy train trước!")
        return

    print(f"[VALIDATE] Loading model: {model_path}")
    model = YOLO(str(model_path))

    results = model.val(
        data=args.data,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
    )

    print("\n[RESULTS]")
    print(f"  mAP50: {results.box.map50:.4f}")
    print(f"  mAP50-95: {results.box.map:.4f}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train YOLOv8 Clothing Detection")

    parser.add_argument("--data", type=str, default="dataset.yaml",
                        help="Path tới dataset.yaml (mặc định: dataset.yaml)")
    parser.add_argument("--model", type=str, default="yolov8n.pt",
                        help="Base model: yolov8n.pt (nano), yolov8s.pt (small), yolov8m.pt (medium)")
    parser.add_argument("--epochs", type=int, default=50,
                        help="Số epochs (mặc định: 50)")
    parser.add_argument("--imgsz", type=int, default=640,
                        help="Kích thước ảnh training (mặc định: 640)")
    parser.add_argument("--batch", type=int, default=16,
                        help="Batch size (mặc định: 16, giảm nếu thiếu VRAM)")
    parser.add_argument("--device", type=str, default="0",
                        help="Device: '0' (GPU 0), 'cpu', '0,1' (multi-GPU)")
    parser.add_argument("--workers", type=int, default=4,
                        help="Số workers cho dataloader (mặc định: 4)")
    parser.add_argument("--resume", action="store_true",
                        help="Tiếp tục training từ checkpoint cuối")
    parser.add_argument("--validate", action="store_true",
                        help="Chỉ chạy validation, không train")

    args = parser.parse_args()

    if args.validate:
        validate(args)
    else:
        train(args)
