"""
Clothing Detection API — Two-Stage Pipeline (YOLOv8 + ResNet50)
  Stage 1: YOLOv8 detect → tìm vùng chứa quần áo (bounding box)
  Stage 2: Crop ROI → post-processing → ResNet50 classify → phân loại chi tiết

Output: JSON detections + ảnh annotated (base64) với bounding box + label
"""

import os
import io
import base64
import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image
from ultralytics import YOLO

from classifier import (
    load_classifier, classify, is_classifier_loaded,
    CLASS_NAMES_VI, WARMTH_LEVEL,
)

app = FastAPI(
    title="Clothing Detection API — Two-Stage Pipeline",
    description="YOLOv8 Detector → ResNet50 Classifier",
    version="2.0.0",
)

# ══════════════════════════════════════════════════════════════════════════════
# Config
# ══════════════════════════════════════════════════════════════════════════════
MODEL_PATH = os.environ.get("MODEL_PATH", "models/clothing_yolov8.pt")
FALLBACK_MODEL = "yolov8n.pt"

# Post-processing (từ bài Garbage)
DET_CONF_THRESH = 0.25
BBOX_EXPAND     = 0.15      # Mở rộng bbox 15% lấy ngữ cảnh
MIN_BOX_AREA    = 1500       # Diện tích bbox tối thiểu (px²)
MIN_BLUR_SCORE  = 60.0       # Laplacian variance tối thiểu (0 = tắt)
MIN_CROP_SIZE   = 10         # Kích thước crop tối thiểu (px)

CLASS_COLORS = {
    "short_sleeve_top":     (255, 178, 102),
    "long_sleeve_top":      (255, 140,  50),
    "short_sleeve_outwear": (102, 102, 255),
    "long_sleeve_outwear":  ( 50,  50, 255),
    "vest":                 (102, 255, 102),
    "sling":                (255, 102, 255),
    "shorts":               (102, 255, 200),
    "trousers":             (255, 255, 102),
    "skirt":                (200, 150, 255),
    "short_sleeve_dress":   (102, 200, 255),
    "long_sleeve_dress":    ( 50, 150, 255),
    "vest_dress":           (200, 255, 150),
    "sling_dress":          (255, 200, 200),
    "default":              (  0, 255,   0),
}

# ══════════════════════════════════════════════════════════════════════════════
# Model loading (singleton — giống bài Garbage)
# ══════════════════════════════════════════════════════════════════════════════
yolo_model = None
using_custom_yolo = False


@app.on_event("startup")
def startup():
    """Load cả 2 model khi khởi động."""
    global yolo_model, using_custom_yolo

    # --- Stage 1: YOLO Detector ---
    if os.path.exists(MODEL_PATH):
        print(f"[Detector] ✅ Loading custom YOLO: {MODEL_PATH}")
        yolo_model = YOLO(MODEL_PATH)
        using_custom_yolo = True
    else:
        print(f"[Detector] ⚠️  Custom model not found, using COCO fallback: {FALLBACK_MODEL}")
        yolo_model = YOLO(FALLBACK_MODEL)
        using_custom_yolo = False

    # --- Stage 2: ResNet50 Classifier ---
    load_classifier()


# ══════════════════════════════════════════════════════════════════════════════
# Post-processing utilities (port từ bài Garbage — detector.py)
# ══════════════════════════════════════════════════════════════════════════════

def is_blurry(roi_gray, threshold):
    """Kiểm tra ROI có quá mờ không (Laplacian variance)."""
    return cv2.Laplacian(roi_gray, cv2.CV_64F).var() < threshold


def expand_bbox(x1, y1, x2, y2, img_w, img_h, margin_ratio=BBOX_EXPAND):
    """Mở rộng bbox thêm margin_ratio% (giống bài Garbage)."""
    margin_x = int((x2 - x1) * margin_ratio)
    margin_y = int((y2 - y1) * margin_ratio)
    return (
        max(0, x1 - margin_x),
        max(0, y1 - margin_y),
        min(img_w, x2 + margin_x),
        min(img_h, y2 + margin_y),
    )


def letterbox_pad(roi_bgr):
    """Letterbox padding → hình vuông."""
    h, w = roi_bgr.shape[:2]
    max_dim = max(h, w)
    pad_top = (max_dim - h) // 2
    pad_bottom = max_dim - h - pad_top
    pad_left = (max_dim - w) // 2
    pad_right = max_dim - w - pad_left
    return cv2.copyMakeBorder(
        roi_bgr, pad_top, pad_bottom, pad_left, pad_right,
        cv2.BORDER_CONSTANT, value=[114, 114, 114],
    )


def annotate_image(image_bgr, detections):
    """
    Vẽ bounding box + label lên ảnh.
    """
    annotated = image_bgr.copy()
    h, w = annotated.shape[:2]
    
    # Tính toán font và độ dày nét vẽ tỷ lệ thuận với kích thước ảnh
    scale = min(w, h) / 400.0
    font_scale = max(0.3, 0.5 * scale)
    thickness = max(1, int(1.5 * scale))

    for det in detections:
        x1, y1, x2, y2 = det["bbox"]
        label = det.get("class", "unknown")
        cls_conf = det.get("cls_conf") or det.get("det_conf", 0)
        label_vi = det.get("class_vi", label)

        color = CLASS_COLORS.get(label, CLASS_COLORS["default"])

        # 1. Vẽ bounding box
        cv2.rectangle(annotated, (x1, y1), (x2, y2), color, thickness)

        # 2. Chuẩn bị text
        text = f"{label_vi} ({cls_conf:.0%})"

        # 3. Kích thước text
        (tw, th), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, font_scale, thickness)
        
        # 4. Vẽ nền và text (tránh bị cắt mất chữ nếu bounding box sát mép trên)
        if y1 - th - 10 < 0:
            cv2.rectangle(annotated, (x1, y1), (x1 + tw + 6, y1 + th + 10), color, -1)
            cv2.putText(annotated, text, (x1 + 3, y1 + th + 5), cv2.FONT_HERSHEY_SIMPLEX, font_scale, (0, 0, 0), thickness)
        else:
            cv2.rectangle(annotated, (x1, y1 - th - 10), (x1 + tw + 6, y1), color, -1)
            cv2.putText(annotated, text, (x1 + 3, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, font_scale, (0, 0, 0), thickness)

    return annotated


def encode_image_base64(image_bgr, quality=85):
    """Encode ảnh BGR sang base64 JPEG."""
    _, buffer = cv2.imencode(".jpg", image_bgr, [cv2.IMWRITE_JPEG_QUALITY, quality])
    return base64.b64encode(buffer).decode("utf-8")


# ══════════════════════════════════════════════════════════════════════════════
# Two-Stage Pipeline 
# ══════════════════════════════════════════════════════════════════════════════

def run_pipeline(image_bgr, det_conf=DET_CONF_THRESH):
    """
    Full two-stage pipeline trên 1 ảnh BGR.

    Stage 1: YOLO detect → bounding boxes
    Stage 2: Crop + Post-process + ResNet50 classify

    Returns: (list[dict], annotated_bgr)
    """
    orig_h, orig_w = image_bgr.shape[:2]
    classifier_available = is_classifier_loaded()

    # ── Stage 1: YOLO Detection ──
    results = yolo_model(image_bgr, conf=det_conf, verbose=False, stream=True)

    hits = []

    for result in results:
        for box in result.boxes:
            det_conf_val = float(box.conf[0])
            if det_conf_val < det_conf:
                continue

            x1, y1, x2, y2 = map(int, box.xyxy[0])
            yolo_cls_id = int(box.cls[0])
            yolo_cls_name = yolo_model.names[yolo_cls_id]

            # ── Post-processing Filter 1: Bbox quá nhỏ ──
            box_area = (x2 - x1) * (y2 - y1)
            if box_area < MIN_BOX_AREA:
                continue

            # ── Post-processing: Expand bbox 15% ──
            cx1, cy1, cx2, cy2 = expand_bbox(x1, y1, x2, y2, orig_w, orig_h)

            # ── Post-processing Filter 2: Crop quá nhỏ ──
            if (cx2 - cx1) < MIN_CROP_SIZE or (cy2 - cy1) < MIN_CROP_SIZE:
                continue

            # ── Crop ROI từ ảnh gốc ──
            roi = image_bgr[cy1:cy2, cx1:cx2]

            # ── Post-processing Filter 3: Blur detection (Laplacian) ──
            if MIN_BLUR_SCORE > 0:
                gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
                if is_blurry(gray, MIN_BLUR_SCORE):
                    continue

            # ── Post-processing: Letterbox padding ──
            roi_padded = letterbox_pad(roi)

            # ── Stage 2: ResNet50 Classification (nếu có) ──
            if classifier_available:
                cls_result = classify(roi_padded)
                if cls_result is not None:
                    # Dùng kết quả ResNet50 (chính xác hơn)
                    final_label = cls_result["label"]
                    final_label_vi = cls_result["label_vi"]
                    cls_conf = cls_result["cls_conf"]
                    warmth = cls_result["warmth"]
                else:
                    # ResNet50 không đủ confident → dùng YOLO class
                    final_label = yolo_cls_name
                    final_label_vi = CLASS_NAMES_VI.get(yolo_cls_name, yolo_cls_name)
                    cls_conf = det_conf_val
                    warmth = WARMTH_LEVEL.get(yolo_cls_name, "không xác định")
            else:
                # Không có ResNet50 → dùng YOLO class
                final_label = yolo_cls_name
                final_label_vi = CLASS_NAMES_VI.get(yolo_cls_name, yolo_cls_name)
                cls_conf = det_conf_val
                warmth = WARMTH_LEVEL.get(yolo_cls_name, "không xác định")

            hits.append({
                "class": final_label,
                "class_vi": final_label_vi,
                "det_conf": round(det_conf_val, 3),
                "cls_conf": round(cls_conf, 3),
                "warmth": warmth,
                "bbox": [x1, y1, x2, y2],
            })

    # Sort by confidence
    hits.sort(key=lambda x: x["cls_conf"], reverse=True)

    # ── Annotate image ──
    annotated = annotate_image(image_bgr, hits)

    return hits, annotated


# ══════════════════════════════════════════════════════════════════════════════
# API Endpoints
# ══════════════════════════════════════════════════════════════════════════════

@app.get("/health")
def health():
    return {
        "status": "ok",
        "yolo_loaded": yolo_model is not None,
        "using_custom_yolo": using_custom_yolo,
        "resnet50_loaded": is_classifier_loaded(),
        "pipeline": "two-stage (YOLOv8 + ResNet50)" if is_classifier_loaded()
                     else "single-stage (YOLOv8 only)",
    }


@app.post("/detect")
async def detect_clothing(file: UploadFile = File(...), confidence: float = 0.25):
    """
    Two-stage clothing detection pipeline.

    Returns:
        - detections: danh sách trang phục + confidence + bbox
        - annotated_image: ảnh base64 đã vẽ bounding box + label
        - summary: tóm tắt tiếng Việt
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File phải là ảnh")

    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        image_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if image_bgr is None:
            raise HTTPException(status_code=400, detail="Không thể đọc ảnh")

        # ── Run full pipeline ──
        detections, annotated = run_pipeline(image_bgr, det_conf=confidence)

        # ── Build summary ──
        if detections:
            unique_items = list(dict.fromkeys(d["class_vi"] for d in detections))
            summary = "Phát hiện: " + ", ".join(unique_items)
        else:
            summary = "Không phát hiện trang phục nào trong ảnh"

        # ── Encode annotated image ──
        annotated_b64 = encode_image_base64(annotated)

        return {
            "success": True,
            "detections": detections,
            "annotated_image": annotated_b64,
            "summary": summary,
            "total": len(detections),
            "pipeline": "two-stage (YOLOv8 + ResNet50)" if is_classifier_loaded()
                         else "single-stage (YOLOv8 only)",
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi xử lý: {str(e)}")
