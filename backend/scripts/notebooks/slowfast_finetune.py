"""
================================================================================
SMARTCARE+ SlowFast Fine-Tuning Script for Google Colab
================================================================================
Owner: Madhushani (Guardian Service)
Purpose: Fine-tune SlowFast model for fall detection and gait analysis

This script is designed to be run in Google Colab with GPU acceleration.
Copy each section into separate Colab cells for better organization.

Dataset Structure Expected:
    dataset/
    ├── ADL/          # Activities of Daily Living (walking, sitting, etc.)
    ├── Fall/         # Various fall types
    ├── arthritis_gait/  # Abnormal gait patterns
    ├── good_gait/    # Normal gait patterns
    └── tug/          # Timed Up and Go test videos
================================================================================
"""

# ==============================================================================
# SECTION 1: SETUP & INSTALLATION
# ==============================================================================
# Run this cell first to install all required packages

"""
!pip install -q tensorflow==2.15.0
!pip install -q tensorflow-hub
!pip install -q opencv-python-headless
!pip install -q scikit-learn
!pip install -q matplotlib seaborn
!pip install -q tqdm
"""

# ==============================================================================
# SECTION 2: IMPORTS
# ==============================================================================

import tensorflow as tf
import tensorflow_hub as hub
import numpy as np
import cv2
import os
import random
from pathlib import Path
from typing import Tuple, List, Dict
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt
import seaborn as sns
from tqdm.auto import tqdm
import warnings
warnings.filterwarnings('ignore')

# Enable mixed precision for faster training on GPU
from tensorflow.keras import mixed_precision
mixed_precision.set_global_policy('mixed_float16')

print(f"TensorFlow version: {tf.__version__}")
print(f"GPU available: {tf.config.list_physical_devices('GPU')}")
print(f"Mixed precision policy: {mixed_precision.global_policy().name}")

# ==============================================================================
# SECTION 3: MOUNT GOOGLE DRIVE & CONFIGURATION
# ==============================================================================

# Mount Google Drive
from google.colab import drive
drive.mount('/content/drive')

# ==================== CONFIGURATION ====================
# Modify these paths according to your Google Drive structure

CONFIG = {
    # Paths
    "dataset_path": "/content/drive/MyDrive/SmartCarePlus/datasets/guardian",
    "model_save_path": "/content/drive/MyDrive/SmartCarePlus/models/slowfast_guardian",
    "checkpoint_path": "/content/drive/MyDrive/SmartCarePlus/checkpoints",
    
    # Video Processing
    "num_frames_slow": 8,      # Frames for slow pathway
    "num_frames_fast": 32,     # Frames for fast pathway
    "frame_height": 224,
    "frame_width": 224,
    "channels": 3,
    
    # Training
    "batch_size": 4,           # Small batch due to video memory
    "epochs": 20,
    "learning_rate": 1e-4,
    "warmup_epochs": 2,
    "weight_decay": 1e-5,
    
    # Data Split
    "test_split": 0.2,
    "val_split": 0.1,
    "random_seed": 42,
}

# Create directories if they don't exist
os.makedirs(CONFIG["model_save_path"], exist_ok=True)
os.makedirs(CONFIG["checkpoint_path"], exist_ok=True)

print("Configuration loaded successfully!")
print(f"Dataset path: {CONFIG['dataset_path']}")

# ==============================================================================
# SECTION 4: DATA DISCOVERY & CLASS MAPPING
# ==============================================================================

def discover_dataset(dataset_path: str) -> Tuple[List[str], List[int], Dict[str, int], Dict[int, str]]:
    """
    Scan the dataset directory and create file lists with labels.
    
    Returns:
        video_paths: List of video file paths
        labels: List of integer labels
        class_to_idx: Dictionary mapping class names to indices
        idx_to_class: Dictionary mapping indices to class names
    """
    dataset_path = Path(dataset_path)
    
    # Get all class folders
    class_folders = sorted([d for d in dataset_path.iterdir() if d.is_dir()])
    
    # Create class mappings
    class_to_idx = {folder.name: idx for idx, folder in enumerate(class_folders)}
    idx_to_class = {idx: name for name, idx in class_to_idx.items()}
    
    video_paths = []
    labels = []
    
    # Valid video extensions
    video_extensions = {'.mp4', '.avi', '.mov', '.mkv', '.MP4', '.AVI', '.MOV'}
    
    for class_folder in class_folders:
        class_name = class_folder.name
        class_idx = class_to_idx[class_name]
        
        # Find all video files in this class folder
        for video_file in class_folder.iterdir():
            if video_file.suffix in video_extensions:
                video_paths.append(str(video_file))
                labels.append(class_idx)
    
    print(f"\n📊 Dataset Statistics:")
    print(f"{'='*50}")
    print(f"Total videos: {len(video_paths)}")
    print(f"Number of classes: {len(class_to_idx)}")
    print(f"\nClass distribution:")
    for class_name, idx in class_to_idx.items():
        count = labels.count(idx)
        print(f"  {class_name}: {count} videos ({100*count/len(labels):.1f}%)")
    
    return video_paths, labels, class_to_idx, idx_to_class


# Discover dataset
video_paths, labels, class_to_idx, idx_to_class = discover_dataset(CONFIG["dataset_path"])
NUM_CLASSES = len(class_to_idx)

print(f"\n✅ Found {NUM_CLASSES} classes")

# ==============================================================================
# SECTION 5: VIDEO LOADING & PREPROCESSING
# ==============================================================================

def load_video_frames(video_path: str, 
                      num_frames: int, 
                      resize_height: int,
                      resize_width: int) -> np.ndarray:
    """
    Load and sample frames from a video file.
    
    Args:
        video_path: Path to video file
        num_frames: Number of frames to sample
        resize_height: Target frame height
        resize_width: Target frame width
    
    Returns:
        numpy array of shape (num_frames, height, width, channels)
    """
    cap = cv2.VideoCapture(video_path)
    
    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {video_path}")
    
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    # Calculate frame indices to sample (uniform sampling with jitter)
    if total_frames >= num_frames:
        # Uniform sampling
        indices = np.linspace(0, total_frames - 1, num_frames, dtype=int)
    else:
        # If video has fewer frames, repeat last frame
        indices = list(range(total_frames))
        indices.extend([total_frames - 1] * (num_frames - total_frames))
        indices = np.array(indices[:num_frames])
    
    frames = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        
        if ret:
            # Convert BGR to RGB
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            # Resize
            frame = cv2.resize(frame, (resize_width, resize_height))
            # Normalize to [0, 1]
            frame = frame.astype(np.float32) / 255.0
            frames.append(frame)
        else:
            # If frame read fails, use last valid frame or zeros
            if frames:
                frames.append(frames[-1])
            else:
                frames.append(np.zeros((resize_height, resize_width, 3), dtype=np.float32))
    
    cap.release()
    
    return np.array(frames)


def load_video_slowfast(video_path: str) -> Tuple[np.ndarray, np.ndarray]:
    """
    Load video and create both slow and fast pathway inputs.
    
    The slow pathway samples fewer frames (temporal stride = 4).
    The fast pathway samples more frames (temporal stride = 1).
    
    Returns:
        slow_frames: (num_frames_slow, H, W, C)
        fast_frames: (num_frames_fast, H, W, C)
    """
    # Load frames for fast pathway (more frames)
    fast_frames = load_video_frames(
        video_path,
        CONFIG["num_frames_fast"],
        CONFIG["frame_height"],
        CONFIG["frame_width"]
    )
    
    # Slow pathway: subsample from fast frames (every 4th frame)
    slow_indices = np.linspace(0, CONFIG["num_frames_fast"] - 1, 
                               CONFIG["num_frames_slow"], dtype=int)
    slow_frames = fast_frames[slow_indices]
    
    return slow_frames, fast_frames


def apply_augmentation(frames: np.ndarray, training: bool = True) -> np.ndarray:
    """
    Apply data augmentation to video frames.
    
    Args:
        frames: numpy array of shape (num_frames, H, W, C)
        training: Whether in training mode (apply augmentation)
    
    Returns:
        Augmented frames
    """
    if not training:
        return frames
    
    # Random horizontal flip (50% chance)
    if random.random() > 0.5:
        frames = frames[:, :, ::-1, :]
    
    # Random brightness adjustment
    brightness_factor = random.uniform(0.8, 1.2)
    frames = np.clip(frames * brightness_factor, 0, 1)
    
    # Random contrast adjustment
    contrast_factor = random.uniform(0.8, 1.2)
    mean = np.mean(frames, axis=(1, 2, 3), keepdims=True)
    frames = np.clip((frames - mean) * contrast_factor + mean, 0, 1)
    
    return frames.astype(np.float32)


# Test video loading
print("\n🎬 Testing video loading...")
test_path = video_paths[0]
slow, fast = load_video_slowfast(test_path)
print(f"Slow pathway shape: {slow.shape}")
print(f"Fast pathway shape: {fast.shape}")
print("✅ Video loading works!")

# ==============================================================================
# SECTION 6: TF.DATA PIPELINE
# ==============================================================================

def create_dataset(video_paths: List[str], 
                   labels: List[int], 
                   training: bool = True,
                   batch_size: int = 4) -> tf.data.Dataset:
    """
    Create a tf.data.Dataset for efficient data loading.
    
    Args:
        video_paths: List of video file paths
        labels: List of integer labels
        training: Whether this is training data (apply augmentation)
        batch_size: Batch size
    
    Returns:
        tf.data.Dataset yielding ((slow_frames, fast_frames), labels)
    """
    
    def load_video_tf(video_path, label):
        """TensorFlow wrapper for video loading."""
        def _load(path):
            path_str = path.numpy().decode('utf-8')
            slow, fast = load_video_slowfast(path_str)
            
            if training:
                # Apply same augmentation to both pathways
                seed = random.randint(0, 2**31)
                random.seed(seed)
                slow = apply_augmentation(slow, training=True)
                random.seed(seed)
                fast = apply_augmentation(fast, training=True)
            
            return slow.astype(np.float32), fast.astype(np.float32)
        
        slow, fast = tf.py_function(
            _load, 
            [video_path], 
            [tf.float32, tf.float32]
        )
        
        # Set shapes explicitly
        slow.set_shape([CONFIG["num_frames_slow"], 
                        CONFIG["frame_height"], 
                        CONFIG["frame_width"], 
                        CONFIG["channels"]])
        fast.set_shape([CONFIG["num_frames_fast"], 
                        CONFIG["frame_height"], 
                        CONFIG["frame_width"], 
                        CONFIG["channels"]])
        
        return (slow, fast), label
    
    # Create dataset from tensor slices
    dataset = tf.data.Dataset.from_tensor_slices((video_paths, labels))
    
    if training:
        dataset = dataset.shuffle(buffer_size=len(video_paths), seed=CONFIG["random_seed"])
    
    # Map the loading function
    dataset = dataset.map(
        load_video_tf,
        num_parallel_calls=tf.data.AUTOTUNE
    )
    
    # Batch and prefetch
    dataset = dataset.batch(batch_size)
    dataset = dataset.prefetch(tf.data.AUTOTUNE)
    
    return dataset


# Split dataset
X_train_val, X_test, y_train_val, y_test = train_test_split(
    video_paths, labels,
    test_size=CONFIG["test_split"],
    stratify=labels,
    random_state=CONFIG["random_seed"]
)

X_train, X_val, y_train, y_val = train_test_split(
    X_train_val, y_train_val,
    test_size=CONFIG["val_split"] / (1 - CONFIG["test_split"]),
    stratify=y_train_val,
    random_state=CONFIG["random_seed"]
)

print(f"\n📊 Data Split:")
print(f"  Training:   {len(X_train)} videos")
print(f"  Validation: {len(X_val)} videos")
print(f"  Test:       {len(X_test)} videos")

# Create datasets
train_dataset = create_dataset(X_train, y_train, training=True, batch_size=CONFIG["batch_size"])
val_dataset = create_dataset(X_val, y_val, training=False, batch_size=CONFIG["batch_size"])
test_dataset = create_dataset(X_test, y_test, training=False, batch_size=CONFIG["batch_size"])

print("✅ Datasets created!")

# ==============================================================================
# SECTION 7: BUILD SLOWFAST MODEL
# ==============================================================================

class SlowFastClassifier(tf.keras.Model):
    """
    SlowFast-based video classifier.
    
    Architecture:
    - SlowFast feature extractor from TensorFlow Hub
    - Global average pooling
    - Dense classification head
    """
    
    def __init__(self, num_classes: int, dropout_rate: float = 0.5):
        super().__init__()
        
        # Load SlowFast from TensorFlow Hub
        # Note: This model expects input shape (batch, frames, height, width, channels)
        self.slowfast = hub.KerasLayer(
            "https://tfhub.dev/tensorflow/movinet/a2/base/kinetics-600/classification/3",
            trainable=True,
            name="movinet_base"
        )
        
        # Classification head
        self.dropout = tf.keras.layers.Dropout(dropout_rate)
        self.classifier = tf.keras.layers.Dense(
            num_classes, 
            activation='softmax',
            dtype='float32',  # Keep output in float32 for stability
            name="classifier"
        )
    
    def call(self, inputs, training=False):
        # Combine slow and fast pathways
        slow_input, fast_input = inputs
        
        # Use fast pathway for MoViNet (more frames = better temporal info)
        # MoViNet expects (batch, frames, height, width, channels)
        features = self.slowfast(fast_input)
        
        x = self.dropout(features, training=training)
        output = self.classifier(x)
        
        return output


def build_model(num_classes: int) -> tf.keras.Model:
    """
    Build the complete SlowFast classifier model.
    
    Note: We're using MoViNet-A2 as an alternative to SlowFast since
    TF Hub's SlowFast model has compatibility issues. MoViNet is 
    actually more efficient and achieves similar accuracy.
    """
    # Input layers
    slow_input = tf.keras.Input(
        shape=(CONFIG["num_frames_slow"], CONFIG["frame_height"], 
               CONFIG["frame_width"], CONFIG["channels"]),
        name="slow_input"
    )
    fast_input = tf.keras.Input(
        shape=(CONFIG["num_frames_fast"], CONFIG["frame_height"], 
               CONFIG["frame_width"], CONFIG["channels"]),
        name="fast_input"
    )
    
    # Load MoViNet (more stable alternative to SlowFast on TF Hub)
    movinet = hub.KerasLayer(
        "https://tfhub.dev/tensorflow/movinet/a2/base/kinetics-600/classification/3",
        trainable=True,
        name="movinet"
    )
    
    # Use fast pathway (32 frames) for better temporal modeling
    features = movinet(fast_input)
    
    # Classification head with regularization
    x = tf.keras.layers.Dropout(0.5)(features)
    x = tf.keras.layers.Dense(256, activation='relu', 
                              kernel_regularizer=tf.keras.regularizers.l2(CONFIG["weight_decay"]))(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    
    # Output layer (float32 for numerical stability)
    outputs = tf.keras.layers.Dense(num_classes, activation='softmax', dtype='float32')(x)
    
    model = tf.keras.Model(inputs=[slow_input, fast_input], outputs=outputs)
    
    return model


# Build model
print("\n🔧 Building model...")
model = build_model(NUM_CLASSES)
model.summary()

# ==============================================================================
# SECTION 8: LEARNING RATE SCHEDULE & OPTIMIZER
# ==============================================================================

class WarmupCosineDecay(tf.keras.optimizers.schedules.LearningRateSchedule):
    """
    Warmup + Cosine Decay learning rate schedule.
    """
    def __init__(self, initial_lr, warmup_steps, total_steps):
        super().__init__()
        self.initial_lr = initial_lr
        self.warmup_steps = warmup_steps
        self.total_steps = total_steps
    
    def __call__(self, step):
        step = tf.cast(step, tf.float32)
        
        # Warmup phase
        warmup_lr = self.initial_lr * (step / self.warmup_steps)
        
        # Cosine decay phase
        progress = (step - self.warmup_steps) / (self.total_steps - self.warmup_steps)
        cosine_decay = 0.5 * (1 + tf.cos(np.pi * progress))
        cosine_lr = self.initial_lr * cosine_decay
        
        # Use warmup if in warmup phase, else use cosine decay
        return tf.cond(step < self.warmup_steps, lambda: warmup_lr, lambda: cosine_lr)


# Calculate steps
steps_per_epoch = len(X_train) // CONFIG["batch_size"]
total_steps = steps_per_epoch * CONFIG["epochs"]
warmup_steps = steps_per_epoch * CONFIG["warmup_epochs"]

# Create learning rate schedule
lr_schedule = WarmupCosineDecay(
    initial_lr=CONFIG["learning_rate"],
    warmup_steps=warmup_steps,
    total_steps=total_steps
)

# Create optimizer
optimizer = tf.keras.optimizers.AdamW(
    learning_rate=lr_schedule,
    weight_decay=CONFIG["weight_decay"]
)

print(f"✅ Learning rate schedule configured:")
print(f"   Initial LR: {CONFIG['learning_rate']}")
print(f"   Warmup steps: {warmup_steps}")
print(f"   Total steps: {total_steps}")

# ==============================================================================
# SECTION 9: COMPILE MODEL
# ==============================================================================

model.compile(
    optimizer=optimizer,
    loss=tf.keras.losses.SparseCategoricalCrossentropy(),
    metrics=[
        'accuracy',
        tf.keras.metrics.SparseTopKCategoricalAccuracy(k=2, name='top2_accuracy')
    ]
)

print("✅ Model compiled!")

# ==============================================================================
# SECTION 10: CALLBACKS
# ==============================================================================

# Model checkpoint - save best model
checkpoint_callback = tf.keras.callbacks.ModelCheckpoint(
    filepath=os.path.join(CONFIG["checkpoint_path"], "best_model.keras"),
    monitor='val_accuracy',
    save_best_only=True,
    save_weights_only=False,
    mode='max',
    verbose=1
)

# Early stopping
early_stopping = tf.keras.callbacks.EarlyStopping(
    monitor='val_loss',
    patience=5,
    restore_best_weights=True,
    verbose=1
)

# Reduce LR on plateau (backup)
reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
    monitor='val_loss',
    factor=0.5,
    patience=3,
    min_lr=1e-7,
    verbose=1
)

# TensorBoard logging
tensorboard_callback = tf.keras.callbacks.TensorBoard(
    log_dir=os.path.join(CONFIG["checkpoint_path"], "logs"),
    histogram_freq=1
)

callbacks = [
    checkpoint_callback,
    early_stopping,
    reduce_lr,
    tensorboard_callback
]

print("✅ Callbacks configured!")

# ==============================================================================
# SECTION 11: TRAINING
# ==============================================================================

print("\n" + "="*60)
print("🚀 STARTING TRAINING")
print("="*60)

history = model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=CONFIG["epochs"],
    callbacks=callbacks,
    verbose=1
)

print("\n✅ Training completed!")

# ==============================================================================
# SECTION 12: PLOT TRAINING HISTORY
# ==============================================================================

def plot_training_history(history):
    """Plot training and validation metrics."""
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    
    # Accuracy
    axes[0].plot(history.history['accuracy'], label='Train Accuracy', linewidth=2)
    axes[0].plot(history.history['val_accuracy'], label='Val Accuracy', linewidth=2)
    axes[0].set_title('Model Accuracy', fontsize=14)
    axes[0].set_xlabel('Epoch')
    axes[0].set_ylabel('Accuracy')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)
    
    # Loss
    axes[1].plot(history.history['loss'], label='Train Loss', linewidth=2)
    axes[1].plot(history.history['val_loss'], label='Val Loss', linewidth=2)
    axes[1].set_title('Model Loss', fontsize=14)
    axes[1].set_xlabel('Epoch')
    axes[1].set_ylabel('Loss')
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(os.path.join(CONFIG["model_save_path"], "training_history.png"), dpi=150)
    plt.show()

plot_training_history(history)

# ==============================================================================
# SECTION 13: EVALUATION
# ==============================================================================

print("\n" + "="*60)
print("📊 EVALUATING ON TEST SET")
print("="*60)

# Evaluate on test set
test_loss, test_acc, test_top2_acc = model.evaluate(test_dataset, verbose=1)

print(f"\n📈 Test Results:")
print(f"   Loss:          {test_loss:.4f}")
print(f"   Accuracy:      {test_acc:.4f} ({test_acc*100:.2f}%)")
print(f"   Top-2 Accuracy: {test_top2_acc:.4f} ({test_top2_acc*100:.2f}%)")

# ==============================================================================
# SECTION 14: CONFUSION MATRIX & CLASSIFICATION REPORT
# ==============================================================================

def generate_predictions(model, dataset):
    """Generate predictions for the entire dataset."""
    all_preds = []
    all_labels = []
    
    for (slow, fast), labels in tqdm(dataset, desc="Generating predictions"):
        preds = model.predict((slow, fast), verbose=0)
        pred_classes = np.argmax(preds, axis=1)
        
        all_preds.extend(pred_classes)
        all_labels.extend(labels.numpy())
    
    return np.array(all_preds), np.array(all_labels)


print("\n🔍 Generating predictions for confusion matrix...")
y_pred, y_true = generate_predictions(model, test_dataset)

# Classification Report
print("\n📋 Classification Report:")
print("="*60)
print(classification_report(y_true, y_pred, target_names=list(idx_to_class.values())))

# Confusion Matrix
plt.figure(figsize=(10, 8))
cm = confusion_matrix(y_true, y_pred)
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=list(idx_to_class.values()),
            yticklabels=list(idx_to_class.values()))
plt.title('Confusion Matrix', fontsize=14)
plt.xlabel('Predicted')
plt.ylabel('Actual')
plt.xticks(rotation=45, ha='right')
plt.tight_layout()
plt.savefig(os.path.join(CONFIG["model_save_path"], "confusion_matrix.png"), dpi=150)
plt.show()

# ==============================================================================
# SECTION 15: SAVE FINAL MODEL
# ==============================================================================

# Save the complete model
model_path = os.path.join(CONFIG["model_save_path"], "guardian_movinet_final")
model.save(model_path)
print(f"\n✅ Model saved to: {model_path}")

# Save weights only (smaller file)
weights_path = os.path.join(CONFIG["model_save_path"], "guardian_movinet_weights.h5")
model.save_weights(weights_path)
print(f"✅ Weights saved to: {weights_path}")

# Save class mappings
import json
mappings_path = os.path.join(CONFIG["model_save_path"], "class_mappings.json")
with open(mappings_path, 'w') as f:
    json.dump({
        "class_to_idx": class_to_idx,
        "idx_to_class": idx_to_class,
        "config": CONFIG
    }, f, indent=2)
print(f"✅ Class mappings saved to: {mappings_path}")

# ==============================================================================
# SECTION 16: INFERENCE FUNCTION (FOR DEPLOYMENT)
# ==============================================================================

def predict_video(video_path: str, model, idx_to_class: Dict[int, str]) -> Tuple[str, float]:
    """
    Predict the action class for a single video.
    
    Args:
        video_path: Path to video file
        model: Trained model
        idx_to_class: Index to class name mapping
    
    Returns:
        Tuple of (predicted_class_name, confidence)
    """
    # Load video
    slow, fast = load_video_slowfast(video_path)
    
    # Add batch dimension
    slow = np.expand_dims(slow, axis=0)
    fast = np.expand_dims(fast, axis=0)
    
    # Predict
    predictions = model.predict((slow, fast), verbose=0)
    
    # Get top prediction
    pred_idx = np.argmax(predictions[0])
    confidence = predictions[0][pred_idx]
    pred_class = idx_to_class[pred_idx]
    
    return pred_class, confidence


# Test inference
print("\n🧪 Testing inference on a sample video...")
test_video = X_test[0]
pred_class, confidence = predict_video(test_video, model, idx_to_class)
actual_class = idx_to_class[y_test[0]]

print(f"   Video: {os.path.basename(test_video)}")
print(f"   Actual:    {actual_class}")
print(f"   Predicted: {pred_class} (confidence: {confidence:.2%})")

# ==============================================================================
# SECTION 17: SUMMARY
# ==============================================================================

print("\n" + "="*60)
print("🎉 TRAINING COMPLETE!")
print("="*60)
print(f"""
📊 Final Results:
   - Test Accuracy:     {test_acc*100:.2f}%
   - Test Top-2 Acc:    {test_top2_acc*100:.2f}%
   - Classes:           {NUM_CLASSES}
   - Training Samples:  {len(X_train)}
   - Validation Samples: {len(X_val)}
   - Test Samples:      {len(X_test)}

📁 Saved Files:
   - Model:            {model_path}
   - Weights:          {weights_path}
   - Class Mappings:   {mappings_path}
   - Training History: {CONFIG["model_save_path"]}/training_history.png
   - Confusion Matrix: {CONFIG["model_save_path"]}/confusion_matrix.png

🚀 Next Steps:
   1. Download the model from Google Drive
   2. Place in backend/ml_models/guardian/
   3. Use the predict_video() function for inference
""")
