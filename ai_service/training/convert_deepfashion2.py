"""
Convert DeepFashion2 dataset to YOLOv8 format.

DeepFashion2 annotation format (per-image JSON):
{
    "source": "...",
    "pair_id": 1,
    "1": {
        "category_id": 1,       # 1-13
        "bounding_box": [x1, y1, x2, y2],
        "style": 0,
        "scale": 1,
        "occlusion": 1,
        "zoom_in": 0,
        "viewpoint": 1
    },
    "2": { ... }
}

YOLO format (per-image .txt, one line per object):
class_id center_x center_y width height
(all values normalized 0-1)

Usage:
    python convert_deepfashion2.py --src /path/to/deepfashion2 --dst ./datasets/deepfashion2_yolo

DeepFashion2 categories (1-indexed → 0-indexed for YOLO):
    1: short_sleeve_top      → 0
    2: long_sleeve_top       → 1
    3: short_sleeve_outwear  → 2
    4: long_sleeve_outwear   → 3
    5: vest                  → 4
    6: sling                 → 5
    7: shorts                → 6
    8: trousers              → 7
    9: skirt                 → 8
    10: short_sleeve_dress   → 9
    11: long_sleeve_dress    → 10
    12: vest_dress           → 11
    13: sling_dress          → 12
"""

import os
import json
import shutil
import argparse
from pathlib import Path
from PIL import Image
from tqdm import tqdm


def convert_annotation(ann_path, img_width, img_height):
    """
    Đọc file annotation JSON của DeepFashion2 và chuyển sang YOLO format.

    Returns:
        list of str: Mỗi dòng là "class_id cx cy w h" (normalized)
    """
    with open(ann_path, "r") as f:
        data = json.load(f)

    yolo_lines = []

    for key, item in data.items():
        # Bỏ qua các key không phải annotation (source, pair_id, ...)
        if not isinstance(item, dict) or "category_id" not in item:
            continue

        category_id = item["category_id"]   # 1-indexed
        bbox = item["bounding_box"]         # [x1, y1, x2, y2] in pixels

        # Bỏ qua annotation không hợp lệ
        if not bbox or len(bbox) != 4:
            continue

        x1, y1, x2, y2 = bbox

        # Bỏ qua bbox quá nhỏ hoặc không hợp lệ
        if x2 <= x1 or y2 <= y1:
            continue

        # Chuyển sang YOLO format (normalized center x, center y, width, height)
        class_id = category_id - 1  # Convert 1-indexed → 0-indexed

        cx = ((x1 + x2) / 2.0) / img_width
        cy = ((y1 + y2) / 2.0) / img_height
        w = (x2 - x1) / img_width
        h = (y2 - y1) / img_height

        # Clamp values to [0, 1]
        cx = max(0.0, min(1.0, cx))
        cy = max(0.0, min(1.0, cy))
        w = max(0.0, min(1.0, w))
        h = max(0.0, min(1.0, h))

        yolo_lines.append(f"{class_id} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}")

    return yolo_lines


def process_split(src_dir, dst_dir, split_name):
    """
    Xử lý 1 split (train hoặc validation) của DeepFashion2.

    Args:
        src_dir: Thư mục gốc DeepFashion2 (chứa train/, validation/)
        dst_dir: Thư mục đích YOLO format
        split_name: "train" hoặc "validation"
    """
    img_src = Path(src_dir) / split_name / "image"
    ann_src = Path(src_dir) / split_name / "annos"

    img_dst = Path(dst_dir) / "images" / split_name
    lbl_dst = Path(dst_dir) / "labels" / split_name

    img_dst.mkdir(parents=True, exist_ok=True)
    lbl_dst.mkdir(parents=True, exist_ok=True)

    if not img_src.exists():
        print(f"[ERROR] Không tìm thấy thư mục: {img_src}")
        return 0

    if not ann_src.exists():
        print(f"[ERROR] Không tìm thấy thư mục: {ann_src}")
        return 0

    # Lấy danh sách ảnh
    img_files = sorted(list(img_src.glob("*.jpg")))
    print(f"\n[{split_name.upper()}] Tìm thấy {len(img_files)} ảnh")

    converted = 0
    skipped = 0

    for img_path in tqdm(img_files, desc=f"Converting {split_name}"):
        # Tìm file annotation tương ứng (cùng tên, đuôi .json)
        ann_file = ann_src / (img_path.stem + ".json")

        if not ann_file.exists():
            skipped += 1
            continue

        try:
            # Lấy kích thước ảnh
            img = Image.open(img_path)
            img_width, img_height = img.size

            # Convert annotation
            yolo_lines = convert_annotation(ann_file, img_width, img_height)

            if not yolo_lines:
                skipped += 1
                continue

            # Copy ảnh sang thư mục đích
            dst_img_path = img_dst / img_path.name
            shutil.copy2(img_path, dst_img_path)

            # Ghi file label YOLO
            label_path = lbl_dst / (img_path.stem + ".txt")
            with open(label_path, "w") as f:
                f.write("\n".join(yolo_lines))

            converted += 1

        except Exception as e:
            print(f"\n[WARNING] Lỗi xử lý {img_path.name}: {e}")
            skipped += 1

    print(f"[{split_name.upper()}] Hoàn thành: {converted} ảnh converted, {skipped} ảnh skipped")
    return converted


def process_split_classifier(src_dir, dst_dir, split_name):
    """
    Tạo dataset ImageFolder cho ResNet50 classifier.
    Cấu trúc: dst_dir/train/class_name/*.jpg (giống bài Garbage)
    """
    CATEGORY_MAP = {
        1: "short_sleeve_top", 2: "long_sleeve_top",
        3: "short_sleeve_outwear", 4: "long_sleeve_outwear",
        5: "vest", 6: "sling", 7: "shorts", 8: "trousers",
        9: "skirt", 10: "short_sleeve_dress", 11: "long_sleeve_dress",
        12: "vest_dress", 13: "sling_dress",
    }

    img_src = Path(src_dir) / split_name / "image"
    ann_src = Path(src_dir) / split_name / "annos"

    # Map split name: DeepFashion2 uses "validation", ImageFolder uses "val"
    folder_name = "val" if split_name == "validation" else split_name
    out_dir = Path(dst_dir) / folder_name

    if not img_src.exists() or not ann_src.exists():
        print(f"[ERROR] Không tìm thấy {img_src} hoặc {ann_src}")
        return 0

    # Tạo thư mục cho từng class
    for cls_name in CATEGORY_MAP.values():
        (out_dir / cls_name).mkdir(parents=True, exist_ok=True)

    img_files = sorted(list(img_src.glob("*.jpg")))
    print(f"\n[{split_name.upper()} → Classifier] Tìm thấy {len(img_files)} ảnh")

    converted = 0
    for img_path in tqdm(img_files, desc=f"Classifier {split_name}"):
        ann_file = ann_src / (img_path.stem + ".json")
        if not ann_file.exists():
            continue

        try:
            with open(ann_file, "r") as f:
                data = json.load(f)

            img = Image.open(img_path)
            img_w, img_h = img.size

            for key, item in data.items():
                if not isinstance(item, dict) or "category_id" not in item:
                    continue

                cat_id = item["category_id"]
                bbox = item.get("bounding_box", [])
                if not bbox or len(bbox) != 4:
                    continue

                x1, y1, x2, y2 = map(int, bbox)
                if x2 <= x1 or y2 <= y1:
                    continue

                # Mở rộng bbox 15% (giống post-processing trong pipeline)
                margin_x = int((x2 - x1) * 0.15)
                margin_y = int((y2 - y1) * 0.15)
                x1 = max(0, x1 - margin_x)
                y1 = max(0, y1 - margin_y)
                x2 = min(img_w, x2 + margin_x)
                y2 = min(img_h, y2 + margin_y)

                # Crop ROI
                roi = img.crop((x1, y1, x2, y2))

                # Lưu vào thư mục class tương ứng
                cls_name = CATEGORY_MAP.get(cat_id)
                if cls_name:
                    out_path = out_dir / cls_name / f"{img_path.stem}_{key}.jpg"
                    roi.save(out_path, "JPEG", quality=90)
                    converted += 1

        except Exception as e:
            continue

    print(f"[{split_name.upper()} → Classifier] {converted} crops đã tạo")
    return converted


def main():
    parser = argparse.ArgumentParser(
        description="Chuyển đổi DeepFashion2 dataset sang YOLOv8 + ImageFolder format"
    )
    parser.add_argument(
        "--src", type=str, required=True,
        help="Đường dẫn tới thư mục gốc DeepFashion2"
    )
    parser.add_argument(
        "--dst", type=str, default="./datasets/deepfashion2_yolo",
        help="Thư mục đích cho YOLO format"
    )
    parser.add_argument(
        "--cls-dst", type=str, default="./datasets/deepfashion2_cls",
        help="Thư mục đích cho Classifier format (ImageFolder)"
    )

    args = parser.parse_args()

    print("=" * 60)
    print("DeepFashion2 → YOLOv8 + Classifier Format Converter")
    print("=" * 60)
    print(f"Source: {args.src}")
    print(f"YOLO output: {args.dst}")
    print(f"Classifier output: {args.cls_dst}")

    # === YOLO format ===
    print("\n" + "=" * 60)
    print("PHASE 1: Tạo dataset YOLO format (cho YOLOv8 Detector)")
    print("=" * 60)
    total_yolo = 0
    for split in ["train", "validation"]:
        count = process_split(args.src, args.dst, split)
        total_yolo += count

    # === Classifier format (ImageFolder) ===
    print("\n" + "=" * 60)
    print("PHASE 2: Tạo dataset ImageFolder (cho ResNet50 Classifier)")
    print("=" * 60)
    total_cls = 0
    for split in ["train", "validation"]:
        count = process_split_classifier(args.src, args.cls_dst, split)
        total_cls += count

    print("\n" + "=" * 60)
    print(f"TỔNG CỘNG:")
    print(f"  YOLO: {total_yolo} ảnh → {args.dst}")
    print(f"  Classifier: {total_cls} crops → {args.cls_dst}")
    print("=" * 60)
    print("\nBước tiếp theo:")
    print("  1. Train YOLO:       python train.py")
    print("  2. Train Classifier: python train_classifier.py --data", args.cls_dst)


if __name__ == "__main__":
    main()
