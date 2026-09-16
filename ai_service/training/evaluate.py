"""
evaluate.py — Đánh giá toàn diện model Clothing Detection & Classification
Tạo ra các báo cáo + biểu đồ để phân tích hiệu suất.

Hỗ trợ:
  1. Evaluate ResNet50 Classifier → Confusion Matrix + Classification Report
  2. Evaluate YOLOv8 Detector     → mAP, Precision, Recall (built-in ultralytics)
  3. Evaluate Full Pipeline        → Test ảnh đầu vào → annotated output

Usage:
    # Evaluate classifier (ResNet50)
    python evaluate.py --mode classifier --data ./datasets/deepfashion2_cls --weights ../models/clothing_resnet50.pth

    # Evaluate detector (YOLOv8)
    python evaluate.py --mode detector --data dataset.yaml --weights ../models/clothing_yolov8.pt

    # Evaluate full pipeline on sample images
    python evaluate.py --mode pipeline --images ./test_images/ --weights-yolo ../models/clothing_yolov8.pt --weights-cls ../models/clothing_resnet50.pth
"""

import os
import sys
import argparse
import numpy as np
from pathlib import Path

import torch
import torch.nn as nn
from torchvision import datasets, transforms
from torchvision.models import resnet50
from torch.utils.data import DataLoader

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import (
    confusion_matrix,
    classification_report,
    precision_recall_fscore_support,
    accuracy_score,
)

# ──────────────────────────────────────────────────────────────────────────────
# 1. CLASSIFIER EVALUATION (ResNet50)
# ──────────────────────────────────────────────────────────────────────────────

def load_classifier_model(weights_path, device):
    """Tải ResNet50 classifier (xử lý DataParallel prefix)."""
    print(f"[*] Đang tải classifier: {weights_path}")
    state = torch.load(weights_path, map_location=device, weights_only=False)

    if "model_state_dict" in state:
        weights = state["model_state_dict"]
        class_names = state.get("class_names", [])
        num_classes = state.get("num_classes", len(class_names))
    else:
        weights = state
        class_names = []
        num_classes = max(1, len(weights.get("fc.weight", torch.zeros(13, 1))))

    # Xử lý prefix 'module.' từ DataParallel
    weights = {k.replace("module.", ""): v for k, v in weights.items()}

    model = resnet50(weights=None)
    model.fc = nn.Linear(model.fc.in_features, num_classes)
    model.load_state_dict(weights)
    model = model.to(device)
    model.eval()

    print(f"[*] ✅ Đã tải. {num_classes} classes: {class_names}")
    return model, class_names


def get_val_loader(data_dir, batch_size=32):
    """Tạo validation dataloader"""
    val_transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])

    val_dir = os.path.join(data_dir, "val")
    if not os.path.exists(val_dir):
        print(f"[!] Không tìm thấy thư mục val tại: {val_dir}")
        return None, [], 0

    dataset = datasets.ImageFolder(val_dir, val_transform)
    loader = DataLoader(dataset, batch_size=batch_size, shuffle=False, num_workers=4)
    return loader, dataset.classes, len(dataset)


def evaluate_classifier(model, dataloader, device):
    """Chạy inference trên toàn bộ validation set."""
    model.eval()
    all_preds = []
    all_labels = []
    all_probs = []

    print("\n[*] Đang chạy evaluation trên validation set...")
    with torch.no_grad():
        for batch_idx, (inputs, labels) in enumerate(dataloader):
            inputs = inputs.to(device)
            outputs = model(inputs)
            probs = torch.nn.functional.softmax(outputs, dim=1)
            _, preds = torch.max(probs, 1)

            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())
            all_probs.extend(probs.cpu().numpy())

            if (batch_idx + 1) % 50 == 0:
                print(f"  Batch {batch_idx + 1}/{len(dataloader)}")

    return np.array(all_labels), np.array(all_preds), np.array(all_probs)


def plot_confusion_matrix(y_true, y_pred, classes, save_path):
    """Vẽ Confusion Matrix bằng seaborn heatmap."""
    cm = confusion_matrix(y_true, y_pred)

    # Normalize (%)
    cm_norm = cm.astype("float") / cm.sum(axis=1)[:, np.newaxis] * 100

    plt.figure(figsize=(16, 13))
    sns.heatmap(
        cm_norm, annot=True, fmt=".1f", cmap="Blues",
        xticklabels=classes, yticklabels=classes,
        linewidths=0.5, linecolor="gray",
        cbar_kws={"label": "Accuracy (%)"},
    )
    plt.xlabel("Predicted Label", fontsize=13)
    plt.ylabel("True Label", fontsize=13)
    plt.title("Confusion Matrix — Clothing Classification (ResNet50)\n(Normalized %)",
              fontsize=14, fontweight="bold")
    plt.xticks(rotation=45, ha="right", fontsize=10)
    plt.yticks(rotation=0, fontsize=10)
    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"[+] Confusion matrix saved: {save_path}")


def plot_per_class_metrics(y_true, y_pred, classes, save_path):
    """Vẽ biểu đồ Precision / Recall / F1 cho từng class."""
    precision, recall, f1, support = precision_recall_fscore_support(
        y_true, y_pred, labels=range(len(classes)), zero_division=0
    )

    x = np.arange(len(classes))
    width = 0.25

    fig, ax = plt.subplots(figsize=(16, 7))
    bars1 = ax.bar(x - width, precision, width, label="Precision", color="#3b82f6")
    bars2 = ax.bar(x, recall, width, label="Recall", color="#22c55e")
    bars3 = ax.bar(x + width, f1, width, label="F1-Score", color="#f59e0b")

    ax.set_xlabel("Clothing Category", fontsize=12)
    ax.set_ylabel("Score", fontsize=12)
    ax.set_title("Per-Class Metrics — Clothing Classification (ResNet50)",
                 fontsize=14, fontweight="bold")
    ax.set_xticks(x)
    ax.set_xticklabels(classes, rotation=45, ha="right", fontsize=10)
    ax.set_ylim(0, 1.1)
    ax.legend(fontsize=11)
    ax.grid(axis="y", alpha=0.3)

    # Thêm số liệu lên bars
    for bar in bars1:
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.02,
                f"{bar.get_height():.2f}", ha="center", va="bottom", fontsize=7)

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"[+] Per-class metrics chart saved: {save_path}")


def plot_confidence_distribution(y_true, y_pred, probs, classes, save_path):
    """Vẽ phân bố confidence cho correct vs incorrect predictions."""
    correct_mask = y_true == y_pred
    max_probs = np.max(probs, axis=1)

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))

    # Correct predictions
    axes[0].hist(max_probs[correct_mask], bins=30, color="#22c55e", alpha=0.8, edgecolor="white")
    axes[0].set_title(f"Correct Predictions (n={correct_mask.sum()})", fontweight="bold")
    axes[0].set_xlabel("Confidence")
    axes[0].set_ylabel("Count")

    # Incorrect predictions
    axes[1].hist(max_probs[~correct_mask], bins=30, color="#ef4444", alpha=0.8, edgecolor="white")
    axes[1].set_title(f"Incorrect Predictions (n={(~correct_mask).sum()})", fontweight="bold")
    axes[1].set_xlabel("Confidence")
    axes[1].set_ylabel("Count")

    plt.suptitle("Confidence Distribution — Correct vs Incorrect",
                 fontsize=13, fontweight="bold")
    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"[+] Confidence distribution saved: {save_path}")


def run_classifier_evaluation(args):
    """Chạy full evaluation cho ResNet50 classifier."""
    device = torch.device("cuda" if torch.cuda.is_available() and args.device != "cpu" else "cpu")
    print(f"[*] Device: {device}")

    # Load model
    model, saved_classes = load_classifier_model(args.weights, device)

    # Load data
    loader, data_classes, total = get_val_loader(args.data, batch_size=args.batch)
    if loader is None:
        return

    classes = data_classes if data_classes else saved_classes
    print(f"[*] Validation set: {total} images, {len(classes)} classes")

    # Evaluate
    y_true, y_pred, probs = evaluate_classifier(model, loader, device)

    # ── Results ──
    acc = accuracy_score(y_true, y_pred)
    print("\n" + "=" * 70)
    print(f"  OVERALL ACCURACY: {acc:.4f} ({acc:.1%})")
    print("=" * 70)

    print("\nClassification Report:")
    print(classification_report(y_true, y_pred, target_names=classes, digits=4))

    # ── Error Analysis ──
    print("\n[Error Analysis] Classes dễ bị nhầm nhất:")
    cm = confusion_matrix(y_true, y_pred)
    for i, cls in enumerate(classes):
        if cm[i].sum() == 0:
            continue
        cls_acc = cm[i, i] / cm[i].sum()
        if cls_acc < 0.8:  # Classes có accuracy < 80%
            # Tìm class bị nhầm nhiều nhất
            confused_with_idx = np.argsort(cm[i])[-2]  # 2nd highest (1st is correct)
            confused_with = classes[confused_with_idx]
            confused_pct = cm[i, confused_with_idx] / cm[i].sum() * 100
            print(f"  ⚠️  {cls}: accuracy={cls_acc:.1%} | "
                  f"Hay bị nhầm với '{confused_with}' ({confused_pct:.1f}%)")

    # ── Plots ──
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    plot_confusion_matrix(y_true, y_pred, classes, output_dir / "confusion_matrix.png")
    plot_per_class_metrics(y_true, y_pred, classes, output_dir / "per_class_metrics.png")
    plot_confidence_distribution(y_true, y_pred, probs, classes,
                                 output_dir / "confidence_distribution.png")

    # ── Summary file ──
    summary_path = output_dir / "evaluation_report.txt"
    with open(summary_path, "w", encoding="utf-8") as f:
        f.write("=" * 70 + "\n")
        f.write("CLOTHING CLASSIFICATION — EVALUATION REPORT\n")
        f.write(f"Model: ResNet50 | Weights: {args.weights}\n")
        f.write(f"Dataset: {args.data} | Samples: {total}\n")
        f.write(f"Device: {device}\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Overall Accuracy: {acc:.4f} ({acc:.1%})\n\n")
        f.write("Classification Report:\n")
        f.write(classification_report(y_true, y_pred, target_names=classes, digits=4))
    print(f"[+] Report saved: {summary_path}")

    print(f"\n[*] Tất cả kết quả đã lưu tại: {output_dir}/")


# ──────────────────────────────────────────────────────────────────────────────
# 2. DETECTOR EVALUATION (YOLOv8)
# ──────────────────────────────────────────────────────────────────────────────

def run_detector_evaluation(args):
    """Chạy evaluation cho YOLOv8 detector (dùng built-in ultralytics)."""
    from ultralytics import YOLO

    print(f"[*] Đang tải YOLOv8: {args.weights}")
    model = YOLO(args.weights)

    print(f"[*] Chạy validation trên: {args.data}")
    results = model.val(
        data=args.data,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        plots=True,        # Tạo PR curves, confusion matrix tự động
        save_json=True,     # Lưu COCO format results
    )

    print("\n" + "=" * 70)
    print("  YOLO DETECTOR — EVALUATION RESULTS")
    print("=" * 70)
    print(f"  mAP@50:      {results.box.map50:.4f}")
    print(f"  mAP@50-95:   {results.box.map:.4f}")
    print(f"  Precision:   {results.box.mp:.4f}")
    print(f"  Recall:      {results.box.mr:.4f}")
    print("=" * 70)

    # Per-class AP
    if hasattr(results.box, "ap_class_index") and results.box.ap_class_index is not None:
        print("\nPer-Class AP@50:")
        names = model.names
        for i, cls_idx in enumerate(results.box.ap_class_index):
            cls_name = names[int(cls_idx)]
            ap50 = results.box.ap50[i] if i < len(results.box.ap50) else 0
            print(f"  {cls_name:<25s} AP@50 = {ap50:.4f}")

    print(f"\n[*] Plots đã được lưu tự động bởi ultralytics tại thư mục runs/")


# ──────────────────────────────────────────────────────────────────────────────
# 3. FULL PIPELINE EVALUATION
# ──────────────────────────────────────────────────────────────────────────────

def run_pipeline_evaluation(args):
    """Test full two-stage pipeline trên các ảnh mẫu."""
    import cv2
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    from app import run_pipeline, startup, annotate_image, encode_image_base64

    # Force load models
    os.environ["MODEL_PATH"] = args.weights_yolo or "models/clothing_yolov8.pt"
    os.environ["CLASSIFIER_PATH"] = args.weights_cls or "models/clothing_resnet50.pth"
    startup()

    images_dir = Path(args.images)
    if not images_dir.exists():
        print(f"[!] Không tìm thấy thư mục: {images_dir}")
        return

    output_dir = Path(args.output) / "pipeline_results"
    output_dir.mkdir(parents=True, exist_ok=True)

    img_files = list(images_dir.glob("*.jpg")) + list(images_dir.glob("*.png"))
    print(f"[*] Tìm thấy {len(img_files)} ảnh test")

    all_detections = []

    for img_path in img_files:
        print(f"\n[*] Processing: {img_path.name}")
        frame = cv2.imread(str(img_path))
        if frame is None:
            print(f"  [!] Không thể đọc ảnh")
            continue

        detections, annotated = run_pipeline(frame)

        # Lưu ảnh annotated
        out_path = output_dir / f"annotated_{img_path.name}"
        cv2.imwrite(str(out_path), annotated)

        # In kết quả
        if detections:
            for det in detections:
                print(f"  → {det['class_vi']} ({det['cls_conf']:.0%})")
                all_detections.append(det)
        else:
            print(f"  → Không phát hiện trang phục")

        print(f"  [+] Saved: {out_path.name}")

    # Thống kê tổng hợp
    if all_detections:
        print("\n" + "=" * 60)
        print("  PIPELINE TEST SUMMARY")
        print("=" * 60)

        class_counts = {}
        class_confs = {}
        for det in all_detections:
            cls = det["class_vi"]
            conf = det["cls_conf"]
            class_counts[cls] = class_counts.get(cls, 0) + 1
            class_confs.setdefault(cls, []).append(conf)

        print(f"  {'Loại trang phục':<25s} | {'Số lượng':>8s} | {'Conf TB':>8s}")
        print("  " + "-" * 50)
        for cls in sorted(class_counts, key=class_counts.get, reverse=True):
            avg_conf = sum(class_confs[cls]) / len(class_confs[cls])
            print(f"  {cls:<25s} | {class_counts[cls]:>8d} | {avg_conf:>7.1%}")

        print(f"\n  TỔNG: {len(all_detections)} vật thể trên {len(img_files)} ảnh")
        print("=" * 60)

    print(f"\n[*] Kết quả annotated đã lưu tại: {output_dir}/")


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Evaluate Clothing Detection & Classification Models"
    )
    parser.add_argument("--mode", type=str, required=True,
                        choices=["classifier", "detector", "pipeline"],
                        help="Loại evaluation: classifier | detector | pipeline")
    parser.add_argument("--data", type=str, default="./datasets/deepfashion2_cls",
                        help="Path tới dataset (ImageFolder cho classifier, YAML cho detector)")
    parser.add_argument("--weights", type=str, default="../models/clothing_resnet50.pth",
                        help="Path tới model weights")
    parser.add_argument("--weights-yolo", type=str, default="../models/clothing_yolov8.pt",
                        help="Path tới YOLO weights (mode=pipeline)")
    parser.add_argument("--weights-cls", type=str, default="../models/clothing_resnet50.pth",
                        help="Path tới classifier weights (mode=pipeline)")
    parser.add_argument("--images", type=str, default="./test_images",
                        help="Thư mục ảnh test (mode=pipeline)")
    parser.add_argument("--output", type=str, default="./eval_results",
                        help="Thư mục lưu kết quả evaluation")
    parser.add_argument("--batch", type=int, default=32)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--device", type=str, default="0")

    args = parser.parse_args()

    print("=" * 70)
    print(f"  CLOTHING MODEL EVALUATION — Mode: {args.mode.upper()}")
    print("=" * 70)

    if args.mode == "classifier":
        run_classifier_evaluation(args)
    elif args.mode == "detector":
        run_detector_evaluation(args)
    elif args.mode == "pipeline":
        run_pipeline_evaluation(args)


if __name__ == "__main__":
    main()
