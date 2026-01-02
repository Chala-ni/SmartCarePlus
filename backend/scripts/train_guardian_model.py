#!/usr/bin/env python3
"""
🎬 SmartCare+ Guardian: Video Action Recognition Training Script

Train EfficientNetV2-S + LSTM model for fall detection & gait analysis.

Usage:
    python train_guardian_model.py --dataset /path/to/dataset --output /path/to/output

    # With custom settings:
    python train_guardian_model.py --dataset ./data --output ./models --epochs1 15 --epochs2 30

Author: Madhushani (Guardian Service)
"""

import os
import sys
import json
import random
import argparse
import warnings
from pathlib import Path
from datetime import datetime
from typing import Tuple, List, Dict, Optional

import numpy as np
import cv2
import tensorflow as tf
from tensorflow.keras import layers, models, mixed_precision
from tensorflow.keras.applications import EfficientNetV2S
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend for servers
import matplotlib.pyplot as plt
import seaborn as sns

warnings.filterwarnings('ignore')

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

def get_config(args) -> dict:
    """Build configuration from command-line arguments."""
    return {
        # Paths
        "dataset_path": args.dataset,
        "model_save_path": args.output,
        "checkpoint_path": os.path.join(args.output, "checkpoints"),
        
        # Video processing
        "num_frames": args.frames,
        "frame_height": args.resolution,
        "frame_width": args.resolution,
        "channels": 3,
        
        # Training
        "batch_size": args.batch_size,
        "epochs_phase1": args.epochs1,
        "epochs_phase2": args.epochs2,
        "learning_rate_phase1": args.lr1,
        "learning_rate_phase2": args.lr2,
        "weight_decay": 1e-5,
        
        # Data split
        "test_split": 0.15,
        "val_split": 0.15,
        "random_seed": 42,
    }


def parse_args():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Train Guardian video classification model",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    # Required paths
    parser.add_argument("--dataset", type=str, required=True,
                        help="Path to dataset folder with class subfolders")
    parser.add_argument("--output", type=str, required=True,
                        help="Path to save trained models")
    
    # Video settings
    parser.add_argument("--frames", type=int, default=32,
                        help="Number of frames to sample per video")
    parser.add_argument("--resolution", type=int, default=224,
                        help="Frame resolution (height=width)")
    
    # Training settings
    parser.add_argument("--batch-size", type=int, default=4,
                        help="Batch size for training")
    parser.add_argument("--epochs1", type=int, default=15,
                        help="Number of epochs for Phase 1 (frozen backbone)")
    parser.add_argument("--epochs2", type=int, default=30,
                        help="Number of epochs for Phase 2 (fine-tuning)")
    parser.add_argument("--lr1", type=float, default=1e-3,
                        help="Learning rate for Phase 1")
    parser.add_argument("--lr2", type=float, default=1e-5,
                        help="Learning rate for Phase 2")
    
    # Options
    parser.add_argument("--mixed-precision", action="store_true", default=True,
                        help="Use mixed precision (float16) training")
    parser.add_argument("--no-mixed-precision", action="store_false", dest="mixed_precision",
                        help="Disable mixed precision training")
    
    return parser.parse_args()


# ═══════════════════════════════════════════════════════════════════════════════
# DATASET UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

def discover_dataset(dataset_path: str) -> Tuple[List[str], List[int], Dict[str, int], Dict[int, str]]:
    """
    Scan dataset directory and create file lists with labels.
    
    Returns:
        video_paths, labels, class_to_idx, idx_to_class
    """
    dataset_path = Path(dataset_path)
    
    if not dataset_path.exists():
        raise ValueError(f"Dataset path does not exist: {dataset_path}")
    
    class_folders = sorted([d for d in dataset_path.iterdir() if d.is_dir()])
    
    if len(class_folders) == 0:
        raise ValueError(f"No class folders found in: {dataset_path}")
    
    class_to_idx = {folder.name: idx for idx, folder in enumerate(class_folders)}
    idx_to_class = {idx: name for name, idx in class_to_idx.items()}
    
    video_paths = []
    labels = []
    video_extensions = {'.mp4', '.avi', '.mov', '.mkv', '.MP4', '.AVI', '.MOV', '.MKV'}
    
    for class_folder in class_folders:
        class_idx = class_to_idx[class_folder.name]
        for video_file in class_folder.iterdir():
            if video_file.suffix in video_extensions:
                video_paths.append(str(video_file))
                labels.append(class_idx)
    
    return video_paths, labels, class_to_idx, idx_to_class


def load_video_frames(video_path: str, num_frames: int, height: int, width: int) -> np.ndarray:
    """Load and uniformly sample frames from a video file."""
    cap = cv2.VideoCapture(video_path)
    
    if not cap.isOpened():
        print(f"⚠️ Cannot open video: {video_path}")
        return np.zeros((num_frames, height, width, 3), dtype=np.float32)
    
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    if total_frames >= num_frames:
        indices = np.linspace(0, total_frames - 1, num_frames, dtype=int)
    else:
        indices = list(range(total_frames))
        if total_frames > 0:
            indices.extend([total_frames - 1] * (num_frames - total_frames))
        else:
            indices = [0] * num_frames
        indices = np.array(indices[:num_frames])
    
    frames = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        
        if ret:
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame = cv2.resize(frame, (width, height))
            frame = frame.astype(np.float32) / 255.0
            frames.append(frame)
        else:
            if frames:
                frames.append(frames[-1].copy())
            else:
                frames.append(np.zeros((height, width, 3), dtype=np.float32))
    
    cap.release()
    
    while len(frames) < num_frames:
        frames.append(frames[-1].copy() if frames else np.zeros((height, width, 3), dtype=np.float32))
    
    return np.array(frames[:num_frames], dtype=np.float32)


def apply_augmentation(frames: np.ndarray, training: bool = True) -> np.ndarray:
    """Apply data augmentation to video frames."""
    if not training:
        return frames
    
    frames = frames.copy()
    
    # Random horizontal flip
    if random.random() > 0.5:
        frames = frames[:, :, ::-1, :]
    
    # Random brightness
    brightness = random.uniform(0.8, 1.2)
    frames = np.clip(frames * brightness, 0, 1)
    
    # Random contrast
    contrast = random.uniform(0.8, 1.2)
    mean = np.mean(frames, axis=(1, 2, 3), keepdims=True)
    frames = np.clip((frames - mean) * contrast + mean, 0, 1)
    
    # Random temporal jitter
    if random.random() > 0.5:
        shift = random.randint(-2, 2)
        if shift != 0:
            frames = np.roll(frames, shift, axis=0)
    
    return frames.astype(np.float32)


def create_dataset(video_paths: List[str], labels: List[int], config: dict,
                   training: bool = True) -> tf.data.Dataset:
    """Create tf.data.Dataset for efficient data loading."""
    
    def load_video_tf(video_path, label):
        def _load(path, lbl):
            path_str = path.numpy().decode('utf-8')
            frames = load_video_frames(
                path_str, config["num_frames"],
                config["frame_height"], config["frame_width"]
            )
            if training:
                frames = apply_augmentation(frames, training=True)
            return frames.astype(np.float32), lbl.numpy()
        
        frames, lbl = tf.py_function(
            _load, [video_path, label], [tf.float32, tf.int32]
        )
        frames.set_shape([config["num_frames"], config["frame_height"],
                          config["frame_width"], config["channels"]])
        lbl.set_shape([])
        return frames, lbl
    
    dataset = tf.data.Dataset.from_tensor_slices((video_paths, labels))
    
    if training:
        dataset = dataset.shuffle(buffer_size=len(video_paths), seed=config["random_seed"])
    
    dataset = dataset.map(load_video_tf, num_parallel_calls=tf.data.AUTOTUNE)
    dataset = dataset.batch(config["batch_size"])
    dataset = dataset.prefetch(tf.data.AUTOTUNE)
    
    return dataset


# ═══════════════════════════════════════════════════════════════════════════════
# MODEL BUILDING
# ═══════════════════════════════════════════════════════════════════════════════

def build_video_backbone(config: dict) -> models.Model:
    """Build video classification backbone using EfficientNetV2-S + LSTM."""
    print("\n📦 Building Video Classification Backbone...")
    print("   Using EfficientNetV2-S + Bidirectional LSTM")
    
    input_shape = (config["num_frames"], config["frame_height"],
                   config["frame_width"], config["channels"])
    
    print("   Loading EfficientNetV2-S (ImageNet pretrained)...")
    efficientnet = EfficientNetV2S(
        include_top=False,
        weights='imagenet',
        input_shape=(config["frame_height"], config["frame_width"], config["channels"]),
        pooling='avg'
    )
    
    # Freeze most layers initially
    for layer in efficientnet.layers[:-30]:
        layer.trainable = False
    
    video_input = layers.Input(shape=input_shape, name="video_input")
    
    # Apply EfficientNet to each frame
    frame_features = layers.TimeDistributed(efficientnet, name="frame_encoder")(video_input)
    
    # Temporal modeling with Bidirectional LSTM
    x = layers.Bidirectional(
        layers.LSTM(256, return_sequences=True, dropout=0.3, recurrent_dropout=0.2),
        name="temporal_lstm_1"
    )(frame_features)
    
    x = layers.Bidirectional(
        layers.LSTM(128, return_sequences=False, dropout=0.3, recurrent_dropout=0.2),
        name="temporal_lstm_2"
    )(x)
    
    # Feature vector output
    features = layers.Dense(512, activation='relu', name="feature_dense")(x)
    features = layers.BatchNormalization(name="feature_bn")(features)
    features = layers.Dropout(0.4, name="feature_dropout")(features)
    
    backbone = models.Model(inputs=video_input, outputs=features, name="video_backbone")
    
    print(f"✅ Backbone built: {backbone.count_params():,} parameters")
    return backbone


def build_guardian_model(backbone: models.Model, num_classes: int,
                         dropout_rate: float = 0.3) -> models.Model:
    """Build complete Guardian classification model."""
    print(f"\n🏗️ Building Guardian model with {num_classes} classes...")
    
    features = backbone.output
    
    x = layers.Dropout(dropout_rate, name="classifier_dropout")(features)
    x = layers.Dense(256, activation='relu', name="classifier_dense_1")(x)
    x = layers.BatchNormalization(name="classifier_bn")(x)
    x = layers.Dropout(dropout_rate / 2, name="classifier_dropout_2")(x)
    x = layers.Dense(128, activation='relu', name="classifier_dense_2")(x)
    
    outputs = layers.Dense(
        num_classes, activation="softmax", dtype='float32',
        kernel_regularizer=tf.keras.regularizers.l2(0.001),
        name="predictions"
    )(x)
    
    model = models.Model(inputs=backbone.input, outputs=outputs, name="guardian_classifier")
    print(f"✅ Model built: {model.count_params():,} parameters")
    return model


# ═══════════════════════════════════════════════════════════════════════════════
# TRAINING
# ═══════════════════════════════════════════════════════════════════════════════

def train_model(model, backbone, train_dataset, val_dataset, config, class_weights,
                model_dir, timestamp):
    """Two-phase training: frozen backbone → fine-tuning."""
    
    # ─── PHASE 1: Train Classification Head ───
    print("\n" + "=" * 70)
    print("🎯 PHASE 1: Training Classification Head (EfficientNet Frozen)")
    print("=" * 70)
    
    # Freeze backbone
    for layer in backbone.layers:
        if 'frame_encoder' in layer.name:
            layer.trainable = False
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=config["learning_rate_phase1"]),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=['accuracy', tf.keras.metrics.SparseTopKCategoricalAccuracy(k=2, name='top2_accuracy')]
    )
    
    callbacks_phase1 = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_accuracy', patience=10,
            restore_best_weights=True, verbose=1, mode='max'
        ),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(model_dir / f"guardian_phase1_{timestamp}.keras"),
            monitor='val_accuracy', save_best_only=True, verbose=1, mode='max'
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss', factor=0.5, patience=5, min_lr=1e-7, verbose=1
        )
    ]
    
    print(f"\n   Training for {config['epochs_phase1']} epochs...\n")
    history_phase1 = model.fit(
        train_dataset, validation_data=val_dataset,
        epochs=config["epochs_phase1"], callbacks=callbacks_phase1,
        class_weight=class_weights, verbose=1
    )
    
    # ─── PHASE 2: Fine-tune Entire Model ───
    print("\n" + "=" * 70)
    print("🔧 PHASE 2: Fine-tuning Entire Model")
    print("=" * 70)
    
    # Unfreeze backbone
    for layer in backbone.layers:
        layer.trainable = True
    
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=config["learning_rate_phase2"]),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=['accuracy', tf.keras.metrics.SparseTopKCategoricalAccuracy(k=2, name='top2_accuracy')]
    )
    
    callbacks_phase2 = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_accuracy', patience=10,
            restore_best_weights=True, verbose=1, mode='max'
        ),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(model_dir / f"guardian_finetune_{timestamp}.keras"),
            monitor='val_accuracy', save_best_only=True, verbose=1, mode='max'
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss', factor=0.5, patience=3, min_lr=1e-8, verbose=1
        )
    ]
    
    initial_epoch = len(history_phase1.history['loss'])
    print(f"\n   Fine-tuning for {config['epochs_phase2']} epochs...\n")
    
    history_phase2 = model.fit(
        train_dataset, validation_data=val_dataset,
        epochs=initial_epoch + config["epochs_phase2"],
        initial_epoch=initial_epoch,
        callbacks=callbacks_phase2, class_weight=class_weights, verbose=1
    )
    
    return history_phase1, history_phase2


# ═══════════════════════════════════════════════════════════════════════════════
# EVALUATION & VISUALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

def evaluate_model(model, test_dataset, class_names, model_dir, timestamp):
    """Evaluate model and generate metrics."""
    print("\n🧪 Evaluating model on test set...")
    test_loss, test_accuracy, test_top2 = model.evaluate(test_dataset, verbose=1)
    
    print(f"\n📊 Test Results:")
    print(f"   Loss:      {test_loss:.4f}")
    print(f"   Accuracy:  {test_accuracy:.4f} ({test_accuracy*100:.1f}%)")
    print(f"   Top-2 Acc: {test_top2:.4f} ({test_top2*100:.1f}%)")
    
    # Get predictions
    y_true, y_pred = [], []
    for videos, labels in test_dataset:
        preds = model.predict(videos, verbose=0)
        y_pred.extend(np.argmax(preds, axis=1).tolist())
        y_true.extend(labels.numpy().tolist())
    
    y_true, y_pred = np.array(y_true), np.array(y_pred)
    
    # Classification report
    print("\n📋 Classification Report:")
    print("=" * 60)
    print(classification_report(y_true, y_pred, target_names=class_names, digits=3))
    
    # Confusion matrix
    cm = confusion_matrix(y_true, y_pred)
    cm_norm = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]
    
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                xticklabels=class_names, yticklabels=class_names, ax=axes[0])
    axes[0].set_xlabel('Predicted')
    axes[0].set_ylabel('Actual')
    axes[0].set_title('Confusion Matrix (Counts)')
    
    sns.heatmap(cm_norm, annot=True, fmt='.2f', cmap='Blues',
                xticklabels=class_names, yticklabels=class_names, ax=axes[1])
    axes[1].set_xlabel('Predicted')
    axes[1].set_ylabel('Actual')
    axes[1].set_title('Confusion Matrix (Normalized)')
    
    plt.tight_layout()
    plt.savefig(model_dir / f"confusion_matrix_{timestamp}.png", dpi=150)
    plt.close()
    
    return test_loss, test_accuracy, test_top2


def plot_history(history1, history2, model_dir, timestamp):
    """Plot training history."""
    acc = history1.history['accuracy'] + history2.history['accuracy']
    val_acc = history1.history['val_accuracy'] + history2.history['val_accuracy']
    loss = history1.history['loss'] + history2.history['loss']
    val_loss = history1.history['val_loss'] + history2.history['val_loss']
    
    epochs = range(1, len(acc) + 1)
    phase1_end = len(history1.history['accuracy'])
    
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    
    axes[0].plot(epochs, acc, 'b-', label='Training', linewidth=2)
    axes[0].plot(epochs, val_acc, 'r-', label='Validation', linewidth=2)
    axes[0].axvline(x=phase1_end, color='gray', linestyle='--', label='Phase 2')
    axes[0].set_xlabel('Epoch')
    axes[0].set_ylabel('Accuracy')
    axes[0].set_title('Training and Validation Accuracy')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)
    
    axes[1].plot(epochs, loss, 'b-', label='Training', linewidth=2)
    axes[1].plot(epochs, val_loss, 'r-', label='Validation', linewidth=2)
    axes[1].axvline(x=phase1_end, color='gray', linestyle='--', label='Phase 2')
    axes[1].set_xlabel('Epoch')
    axes[1].set_ylabel('Loss')
    axes[1].set_title('Training and Validation Loss')
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(model_dir / f"training_history_{timestamp}.png", dpi=150)
    plt.close()
    
    print(f"📊 Best val accuracy: {max(val_acc):.4f}")


def save_model(model, class_names, config, test_results, history1, history2,
               X_train, X_val, X_test, model_dir, timestamp):
    """Save model in multiple formats."""
    print("\n💾 Saving model...")
    
    # Class mapping
    class_mapping = {i: name for i, name in enumerate(class_names)}
    with open(model_dir / f"class_mapping_{timestamp}.json", 'w') as f:
        json.dump(class_mapping, f, indent=2)
    
    # Keras format
    keras_path = model_dir / f"guardian_final_{timestamp}.keras"
    model.save(keras_path)
    print(f"   ✅ Keras: {keras_path}")
    
    # SavedModel format
    savedmodel_path = model_dir / f"guardian_savedmodel_{timestamp}"
    model.export(savedmodel_path)
    print(f"   ✅ SavedModel: {savedmodel_path}")
    
    # TFLite
    try:
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        tflite_model = converter.convert()
        
        tflite_path = model_dir / f"guardian_{timestamp}.tflite"
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        print(f"   ✅ TFLite: {tflite_path} ({len(tflite_model)/(1024*1024):.1f} MB)")
    except Exception as e:
        print(f"   ⚠️ TFLite conversion failed: {e}")
    
    # Training summary
    summary = {
        "timestamp": timestamp,
        "model_type": "EfficientNetV2-S + LSTM",
        "num_classes": len(class_names),
        "class_names": class_names,
        "config": config,
        "training": {
            "phase1_epochs": len(history1.history['loss']),
            "phase2_epochs": len(history2.history['loss']),
            "best_val_accuracy": float(max(
                history1.history['val_accuracy'] + history2.history['val_accuracy']
            ))
        },
        "test_results": {
            "loss": float(test_results[0]),
            "accuracy": float(test_results[1]),
            "top2_accuracy": float(test_results[2])
        },
        "data_split": {
            "train": len(X_train),
            "val": len(X_val),
            "test": len(X_test)
        }
    }
    
    with open(model_dir / f"training_summary_{timestamp}.json", 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"   ✅ Summary: training_summary_{timestamp}.json")


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    """Main training pipeline."""
    args = parse_args()
    config = get_config(args)
    
    # Setup
    print("\n" + "=" * 70)
    print("🎬 SmartCare+ Guardian Video Classification Training")
    print("=" * 70)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    model_dir = Path(config["model_save_path"])
    model_dir.mkdir(parents=True, exist_ok=True)
    
    # Set seeds
    tf.random.set_seed(config["random_seed"])
    np.random.seed(config["random_seed"])
    random.seed(config["random_seed"])
    
    # Mixed precision
    if args.mixed_precision:
        mixed_precision.set_global_policy('mixed_float16')
        print("✅ Mixed precision (float16) enabled")
    
    # GPU check
    gpus = tf.config.list_physical_devices('GPU')
    print(f"✅ TensorFlow {tf.__version__}")
    print(f"✅ GPUs available: {len(gpus)}")
    if gpus:
        for gpu in gpus:
            print(f"   • {gpu.name}")
    
    print(f"\n📁 Dataset: {config['dataset_path']}")
    print(f"📁 Output:  {config['model_save_path']}")
    print(f"🎞️  Frames: {config['num_frames']} @ {config['frame_height']}x{config['frame_width']}")
    print(f"📦 Batch size: {config['batch_size']}")
    print(f"🔄 Epochs: Phase1={config['epochs_phase1']}, Phase2={config['epochs_phase2']}")
    
    # ─── Load Dataset ───
    print("\n🔍 Scanning dataset...")
    video_paths, labels, class_to_idx, idx_to_class = discover_dataset(config["dataset_path"])
    class_names = [idx_to_class[i] for i in range(len(idx_to_class))]
    num_classes = len(class_names)
    
    print(f"\n📊 Dataset Statistics:")
    print(f"   Total videos: {len(video_paths)}")
    print(f"   Classes: {num_classes}")
    for name, idx in class_to_idx.items():
        count = labels.count(idx)
        print(f"   • {name}: {count} ({100*count/len(labels):.1f}%)")
    
    # Class weights
    class_weight_values = compute_class_weight('balanced', classes=np.unique(labels), y=labels)
    class_weights = dict(enumerate(class_weight_values))
    
    # Split data
    X_train_val, X_test, y_train_val, y_test = train_test_split(
        video_paths, labels, test_size=config["test_split"],
        stratify=labels, random_state=config["random_seed"]
    )
    X_train, X_val, y_train, y_val = train_test_split(
        X_train_val, y_train_val,
        test_size=config["val_split"] / (1 - config["test_split"]),
        stratify=y_train_val, random_state=config["random_seed"]
    )
    
    print(f"\n📊 Data Split:")
    print(f"   Train: {len(X_train)} | Val: {len(X_val)} | Test: {len(X_test)}")
    
    # Create datasets
    train_dataset = create_dataset(X_train, y_train, config, training=True)
    val_dataset = create_dataset(X_val, y_val, config, training=False)
    test_dataset = create_dataset(X_test, y_test, config, training=False)
    
    # ─── Build Model ───
    tf.keras.backend.clear_session()
    backbone = build_video_backbone(config)
    model = build_guardian_model(backbone, num_classes)
    
    # ─── Train ───
    history1, history2 = train_model(
        model, backbone, train_dataset, val_dataset, config,
        class_weights, model_dir, timestamp
    )
    
    # ─── Evaluate ───
    test_results = evaluate_model(model, test_dataset, class_names, model_dir, timestamp)
    plot_history(history1, history2, model_dir, timestamp)
    
    # ─── Save ───
    save_model(model, class_names, config, test_results, history1, history2,
               X_train, X_val, X_test, model_dir, timestamp)
    
    # ─── Done ───
    print("\n" + "=" * 70)
    print("🎉 TRAINING COMPLETE!")
    print("=" * 70)
    print(f"\n📊 Final Results:")
    print(f"   Test Accuracy: {test_results[1]*100:.1f}%")
    print(f"   Test Top-2:    {test_results[2]*100:.1f}%")
    print(f"\n📁 Models saved in: {model_dir}")
    print(f"\n💡 Next Steps:")
    print(f"   1. Copy model to backend/ml_models/guardian/")
    print(f"   2. Update guardian_service model loading")


if __name__ == "__main__":
    main()
