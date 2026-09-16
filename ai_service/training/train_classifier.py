"""
Train ResNet50 Clothing Classifier (Stage 2)
  - Transfer Learning: ResNet50 pretrained ImageNet
  - Freeze backbone, chỉ train layer4 + fc
  - Label Smoothing + CosineAnnealingLR + AdamW
  - Best model tracking + Confusion Matrix + Classification Report

Usage:
    python train_classifier.py --data ./datasets/deepfashion2_cls
    python train_classifier.py --data ./datasets/deepfashion2_cls --epochs 30 --device cpu
"""

import os
import sys
import copy
import argparse
import numpy as np
from pathlib import Path

import torch
import torch.nn as nn
import torch.optim as optim
from torch.optim import lr_scheduler
from torchvision import datasets, transforms
from torchvision.models import resnet50, ResNet50_Weights
from torch.utils.data import DataLoader

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import confusion_matrix, classification_report


# ──────────────────────────────────────────────────────────────────────────────
# Data Loading 
# ──────────────────────────────────────────────────────────────────────────────
def get_data_loaders(data_dir, batch_size=32):
    data_transforms = {
        "train": transforms.Compose([
            transforms.RandomResizedCrop(224),
            transforms.RandomHorizontalFlip(),
            transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ]),
        "val": transforms.Compose([
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ]),
    }

    image_datasets = {
        x: datasets.ImageFolder(os.path.join(data_dir, x), data_transforms[x])
        for x in ["train", "val"]
    }
    dataloaders = {
        x: DataLoader(image_datasets[x], batch_size=batch_size,
                       shuffle=(x == "train"), num_workers=4, pin_memory=True)
        for x in ["train", "val"]
    }
    dataset_sizes = {x: len(image_datasets[x]) for x in ["train", "val"]}
    class_names = image_datasets["train"].classes

    return dataloaders, dataset_sizes, class_names


# ──────────────────────────────────────────────────────────────────────────────
# Training Loop (giống bài Garbage — train.py)
# ──────────────────────────────────────────────────────────────────────────────
def train_model(model, dataloaders, dataset_sizes, criterion, optimizer,
                scheduler, device, num_epochs):
    best_model_wts = copy.deepcopy(model.state_dict())
    best_acc = 0.0
    history = {"train_loss": [], "val_loss": [], "train_acc": [], "val_acc": []}

    print("Starting Training...")

    for epoch in range(num_epochs):
        print(f"\nEpoch {epoch+1}/{num_epochs}")
        print("-" * 40)

        for phase in ["train", "val"]:
            if phase == "train":
                model.train()
            else:
                model.eval()

            running_loss = 0.0
            running_corrects = 0

            for batch_idx, (inputs, labels) in enumerate(dataloaders[phase]):
                inputs = inputs.to(device)
                labels = labels.to(device)

                optimizer.zero_grad()

                with torch.set_grad_enabled(phase == "train"):
                    outputs = model(inputs)
                    _, preds = torch.max(outputs, 1)
                    loss = criterion(outputs, labels)

                    if phase == "train":
                        loss.backward()
                        optimizer.step()

                running_loss += loss.item() * inputs.size(0)
                running_corrects += torch.sum(preds == labels).item()

                if (batch_idx + 1) % 50 == 0:
                    print(f"  [{phase}] Batch {batch_idx+1}/{len(dataloaders[phase])} | "
                          f"Loss: {loss.item():.4f}")

            if phase == "train":
                scheduler.step()

            epoch_loss = running_loss / dataset_sizes[phase]
            epoch_acc = running_corrects / dataset_sizes[phase]

            history[f"{phase}_loss"].append(epoch_loss)
            history[f"{phase}_acc"].append(epoch_acc)

            lr_now = optimizer.param_groups[0]["lr"]
            print(f">> {phase} | Loss: {epoch_loss:.4f} | Acc: {epoch_acc:.4f} | LR: {lr_now:.6f}")

            if phase == "val" and epoch_acc > best_acc:
                best_acc = epoch_acc
                best_model_wts = copy.deepcopy(model.state_dict())
                print(f"  [*] New best val acc: {best_acc:.4f}")

    print(f"\nTraining complete. Best val Acc: {best_acc:.4f}")
    model.load_state_dict(best_model_wts)
    return model, history


# ──────────────────────────────────────────────────────────────────────────────
# Evaluation
# ──────────────────────────────────────────────────────────────────────────────
def evaluate_model(model, dataloader, device):
    model.eval()
    all_preds = []
    all_labels = []

    with torch.no_grad():
        for inputs, labels in dataloader:
            inputs = inputs.to(device)
            outputs = model(inputs)
            _, preds = torch.max(outputs, 1)
            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())

    return np.array(all_labels), np.array(all_preds)


def plot_confusion_matrix(y_true, y_pred, classes, save_path):
    cm = confusion_matrix(y_true, y_pred)
    plt.figure(figsize=(14, 12))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues",
                xticklabels=classes, yticklabels=classes)
    plt.xlabel("Predicted")
    plt.ylabel("True")
    plt.title("Confusion Matrix — Clothing Classification (ResNet50)")
    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"Confusion matrix saved: {save_path}")


def plot_training_curves(history, save_path):
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    ax1.plot(history["train_loss"], label="Train")
    ax1.plot(history["val_loss"], label="Val")
    ax1.set_title("Loss")
    ax1.set_xlabel("Epoch")
    ax1.legend()

    ax2.plot(history["train_acc"], label="Train")
    ax2.plot(history["val_acc"], label="Val")
    ax2.set_title("Accuracy")
    ax2.set_xlabel("Epoch")
    ax2.legend()

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"Training curves saved: {save_path}")


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Train ResNet50 Clothing Classifier")
    parser.add_argument("--data", type=str, default="./datasets/deepfashion2_cls",
                        help="Path tới dataset (ImageFolder format)")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--batch", type=int, default=32)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--device", type=str, default="0")
    args = parser.parse_args()

    device = torch.device(f"cuda:{args.device}" if args.device.isdigit()
                          and torch.cuda.is_available() else "cpu")
    print(f"[*] Device: {device}")

    # ── Data ──
    dataloaders, dataset_sizes, class_names = get_data_loaders(args.data, args.batch)
    num_classes = len(class_names)
    print(f"[*] {num_classes} classes: {class_names}")
    for phase in ["train", "val"]:
        print(f"    {phase}: {dataset_sizes[phase]} images")

    # ── Model  ──
    model = resnet50(weights=ResNet50_Weights.DEFAULT)
    model.fc = nn.Linear(model.fc.in_features, num_classes)

    # Freeze backbone, chỉ train layer4 + fc 
    for param in model.parameters():
        param.requires_grad = False
    for name, param in model.named_parameters():
        if "layer4" in name or "fc" in name:
            param.requires_grad = True

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"[*] Trainable params: {trainable:,} / {total:,} ({trainable/total:.1%})")

    model = model.to(device)

    # ── Loss + Optimizer ──
    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    optimizer = optim.AdamW(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=args.lr, weight_decay=1e-4,
    )
    scheduler = lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)

    # ── Train ──
    model, history = train_model(
        model, dataloaders, dataset_sizes,
        criterion, optimizer, scheduler, device, args.epochs,
    )

    # ── Save model ──
    save_dir = Path("../models")
    save_dir.mkdir(parents=True, exist_ok=True)
    save_path = save_dir / "clothing_resnet50.pth"

    state_dict = model.module.state_dict() if isinstance(model, nn.DataParallel) \
                 else model.state_dict()
    torch.save({
        "model_state_dict": state_dict,
        "class_names": class_names,
        "num_classes": num_classes,
    }, save_path)
    print(f"\n[*] Model saved: {save_path}")

    # ── Evaluate + Plots ──
    y_true, y_pred = evaluate_model(model, dataloaders["val"], device)
    print("\nClassification Report:")
    print(classification_report(y_true, y_pred, target_names=class_names))

    plot_confusion_matrix(y_true, y_pred, class_names, "confusion_matrix.png")
    plot_training_curves(history, "training_curves.png")


if __name__ == "__main__":
    main()
