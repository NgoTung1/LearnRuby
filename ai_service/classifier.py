"""
classifier.py — ResNet50 Clothing Classifier (Stage 2)
Kiến trúc mirror từ project Garbage Classification:
  - ResNet50 pretrained ImageNet → fine-tune fc layer (13 clothing classes)
  - Singleton pattern, CUDA/CPU fallback
  - Xử lý tự động prefix 'module.' từ DataParallel training
"""

import os
import cv2
import torch
import torch.nn as nn
from PIL import Image
from torchvision import transforms
from torchvision.models import resnet50

# ──────────────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────────────
CLASSIFIER_WEIGHTS = os.environ.get(
    "CLASSIFIER_PATH", "models/clothing_resnet50.pth"
)
CLS_CONF_THRESH = 0.30  # Ngưỡng confidence tối thiểu

# 13 class DeepFashion2 (phải khớp thứ tự với dataset training)
CLASS_NAMES = [
    "short_sleeve_top", "long_sleeve_top", "short_sleeve_outwear",
    "long_sleeve_outwear", "vest", "sling", "shorts", "trousers",
    "skirt", "short_sleeve_dress", "long_sleeve_dress",
    "vest_dress", "sling_dress",
]

CLASS_NAMES_VI = {
    "short_sleeve_top": "áo ngắn tay",
    "long_sleeve_top": "áo dài tay",
    "short_sleeve_outwear": "áo khoác ngắn tay",
    "long_sleeve_outwear": "áo khoác dài tay",
    "vest": "áo gile",
    "sling": "áo hai dây",
    "shorts": "quần đùi",
    "trousers": "quần dài",
    "skirt": "chân váy",
    "short_sleeve_dress": "đầm ngắn tay",
    "long_sleeve_dress": "đầm dài tay",
    "vest_dress": "đầm gile",
    "sling_dress": "đầm hai dây",
}

WARMTH_LEVEL = {
    "short_sleeve_top": "mát",
    "long_sleeve_top": "ấm vừa",
    "short_sleeve_outwear": "ấm vừa",
    "long_sleeve_outwear": "ấm",
    "vest": "mát",
    "sling": "rất mát",
    "shorts": "mát",
    "trousers": "ấm vừa",
    "skirt": "mát",
    "short_sleeve_dress": "mát",
    "long_sleeve_dress": "ấm vừa",
    "vest_dress": "mát",
    "sling_dress": "rất mát",
}

# ──────────────────────────────────────────────────────────────────────────────
# Singleton
# ──────────────────────────────────────────────────────────────────────────────
_classifier = None
_transform = None
_class_names = []
_device = torch.device("cuda" if torch.cuda.is_available() else "cpu")


def _build_transform():
    """Pipeline tiền xử lý ảnh cho ResNet50 (giống bài Garbage)."""
    return transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])


def load_classifier(weights_path=None):
    """
    Tải ResNet50 classifier (singleton).
    Trả về (model, class_names) hoặc (None, []) nếu chưa có weights.
    """
    global _classifier, _transform, _class_names

    if _classifier is not None:
        return _classifier, _class_names

    path = weights_path or CLASSIFIER_WEIGHTS

    if not os.path.exists(path):
        print(f"[Classifier] WARNING: Không tìm thấy weights tại {path}")
        print(f"[Classifier] Two-stage sẽ dùng YOLO classification thay thế")
        return None, []

    print(f"[Classifier] Đang tải ResNet50 từ: {path}")
    state = torch.load(path, map_location=_device, weights_only=False)

    # Hỗ trợ 2 dạng checkpoint (giống bài Garbage)
    if "model_state_dict" in state:
        weights = state["model_state_dict"]
        c_names = state.get("class_names", CLASS_NAMES)
        num_classes = state.get("num_classes", len(c_names))
    else:
        weights = state
        c_names = CLASS_NAMES
        num_classes = len(c_names)

    # Xử lý prefix 'module.' từ DataParallel (giống bài Garbage)
    weights = {k.replace("module.", ""): v for k, v in weights.items()}

    model = resnet50(weights=None)
    model.fc = nn.Linear(model.fc.in_features, num_classes)
    model.load_state_dict(weights)
    model = model.to(_device)
    model.eval()

    _classifier = model
    _class_names = c_names
    _transform = _build_transform()

    print(f"[Classifier] ✅ Đã tải xong. {num_classes} classes: {c_names}")
    return _classifier, _class_names


def classify(roi_bgr, conf_thresh=CLS_CONF_THRESH):
    """
    Phân loại 1 ROI đã crop + letterbox.

    Args:
        roi_bgr: numpy BGR array (đã letterbox padding)
        conf_thresh: ngưỡng confidence tối thiểu

    Returns:
        dict | None: {"label", "label_vi", "cls_conf", "warmth", "class_idx"}
    """
    if _classifier is None:
        return None

    roi_rgb = cv2.cvtColor(roi_bgr, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(roi_rgb)
    tensor = _transform(pil_img).unsqueeze(0).to(_device)

    with torch.no_grad():
        out = _classifier(tensor)
        prob = torch.nn.functional.softmax(out, dim=1)
        conf, pred = torch.max(prob, 1)
        conf = float(conf)
        idx = int(pred)

    if conf < conf_thresh:
        return None

    label = _class_names[idx] if idx < len(_class_names) else f"class_{idx}"
    return {
        "label": label,
        "label_vi": CLASS_NAMES_VI.get(label, label),
        "cls_conf": round(conf, 3),
        "warmth": WARMTH_LEVEL.get(label, "không xác định"),
        "class_idx": idx,
    }


def is_classifier_loaded():
    return _classifier is not None
