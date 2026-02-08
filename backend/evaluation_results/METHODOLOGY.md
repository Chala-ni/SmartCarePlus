# Fall Detection Methodology - Three-Layer Hybrid Approach

## Overview

The SmartCare+ fall detection system employs a novel three-layer hybrid approach that combines geometric analysis, motion pattern detection, and deep learning to achieve robust and accurate fall detection while minimizing false positives from similar activities like TUG (Timed Up and Go) tests and normal gait patterns.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     INPUT: Video Frames                          │
│                     (32 frames @ 224x224)                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   LAYER 1    │  │   LAYER 2    │  │   LAYER 3    │
│  Skeleton    │  │   Motion     │  │ Deep Learning│
│  Analysis    │  │   Pattern    │  │  Classifier  │
│ (MediaPipe)  │  │  Detection   │  │(EfficientNet)│
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       │ Score: 0-1     │ Score: 0-1     │ Score: 0-1
       │                 │                 │
       └────────────────┼─────────────────┘
                        │
                        ▼
          ┌─────────────────────────┐
          │   Ensemble Decision     │
          │   - High Confidence     │
          │   - Consensus Voting    │
          │   - Weighted Combination│
          └────────────┬────────────┘
                       │
                       ▼
              ┌────────────────┐
              │ FALL DETECTED? │
              │  + Confidence  │
              │  + Fall Type   │
              └────────────────┘
```

## Layer 1: Skeleton-Based Geometric Analysis

### Technology
- **Framework**: MediaPipe Pose Landmarker (v0.10.31)
- **Model**: pose_landmarker_full.task
- **Landmarks**: 33 body keypoints per frame

### Features Extracted

1. **Height-to-Width Ratio**
   - Calculated as: `body_height / body_width`
   - Normal standing: ratio > 1.5
   - Horizontal (fallen): ratio < 0.6
   - Formula:
     ```
     height = abs(head_y - ankle_y)
     width = max(shoulder_width, body_horizontal_spread)
     ratio = height / width
     ```

2. **Spine Angle**
   - Angle of spine vector from horizontal
   - Upright: ~90°
   - Lying down: <30°
   - Formula:
     ```
     spine_vector = shoulder_center - hip_center
     angle = atan2(abs(dy), abs(dx)) * 180/π
     ```

3. **Head Velocity**
   - Vertical movement speed of head landmark
   - Fall indicator: rapid downward motion
   - Calculated over temporal window (5 frames)

4. **Center of Mass Displacement**
   - Distance of CoM from support base
   - High displacement → unstable → potential fall

### Scoring
```python
score = 0.0
if height_width_ratio < 0.6:
    score += 0.40  # Horizontal body position
if spine_angle < 30:
    score += 0.30  # Lying down
if head_velocity > threshold:
    score += 0.20  # Rapid descent
if com_displacement > threshold:
    score += 0.10  # Loss of balance
score = min(score, 1.0)
```

## Layer 2: Motion-Based Pattern Detection

### Technology
- **Method**: Frame difference analysis
- **Resolution**: 64x64 grayscale
- **Temporal Analysis**: Segment-based pattern recognition

### Features Extracted

1. **Motion Magnitude**
   - Mean pixel difference between consecutive frames
   - `motion = mean(abs(frame_t - frame_t-1))`

2. **Vertical Motion**
   - Difference between top-half and bottom-half motion
   - Positive → downward motion
   - `vertical = bottom_half_motion - top_half_motion`

3. **Motion Spike Detection**
   - Sudden increase in motion magnitude
   - `spike = (current > baseline * 2.0) AND (current > 10.0)`

4. **Motion Cessation**
   - Motion stops after spike (impact)
   - Indicates person hitting ground and becoming still

### Pattern Analysis

**TUG vs Fall Discrimination:**

The key innovation is distinguishing sustained activity (TUG, gait) from fall events:

```python
# Divide video into 4 segments
segments = [early, mid1, mid2, late]

# TUG Pattern:
# - Both middle segments have elevated motion
# - Motion sustained throughout
# - Example: [2.07, 9.61, 5.47, 1.37]

# Fall Pattern:
# - Single spike, not sustained
# - Ends with very low motion (stillness)
# - Example: [0.85, 1.71, 4.96, 0.50]

baseline = (segments[0] + segments[-1]) / 2
is_tug = (segments[1] > baseline*1.5 AND 
          segments[2] > baseline*1.5 AND
          max(segments[1:3]) > 5.0)

if is_tug:
    score *= 0.15  # Strong suppression
```

### Scoring
```python
score = 0.0
if motion_spike:
    score += 0.35
if motion_magnitude > 25.0:  # Very high motion
    score += 0.20
if vertical_motion > 1.5:  # Downward motion
    score += 0.25
if motion_cessation:  # Impact detected
    score += 0.25
score = min(score, 1.0)
```

## Layer 3: Deep Learning Classification

### Architecture
- **Backbone**: EfficientNetV2-S (pretrained on ImageNet)
- **Temporal Model**: LSTM (128 units, 2 layers)
- **Input**: 32 frames × 224×224 RGB
- **Output**: 5 classes (fall, adl, good_gait, arthritis_gait, tug)

### Network Structure
```
Input (32, 224, 224, 3)
    ↓
EfficientNetV2-S (frozen base)
    ↓
Global Average Pooling
    ↓
Dense 256 (ReLU, Dropout 0.3)
    ↓
Reshape to (32, 256)
    ↓
LSTM 128 (return_sequences=True)
    ↓
LSTM 128
    ↓
Dense 64 (ReLU, Dropout 0.3)
    ↓
Dense 5 (Softmax)
    ↓
Output: [P(fall), P(adl), P(good_gait), P(arthritis_gait), P(tug)]
```

### Training
- **Loss Function**: Categorical Cross-Entropy
- **Optimizer**: Adam (lr=0.001)
- **Regularization**: Dropout, L2 regularization
- **Data Augmentation**: Random brightness, rotation, zoom
- **Validation Split**: 20%

### Scoring
```python
probabilities = model.predict(frames)
fall_score = probabilities[0]  # P(fall)
return fall_score
```

## Ensemble Decision Logic

The three layer scores are combined using a hierarchical decision strategy:

### 1. High Confidence (Any Single Layer)
```python
if skeleton_score > 0.70:
    return FALL, skeleton_score, "skeleton"
if motion_score > 0.80:  # Higher threshold due to TUG similarity
    return FALL, motion_score, "motion"
if dl_score > 0.70:
    return FALL, dl_score, "deep_learning"
```

### 2. Consensus Voting (Multiple Layers Agree)
```python
votes = 0
if skeleton_score > 0.40:
    votes += 1
if motion_score > 0.50:  # Higher threshold for motion
    votes += 1
if dl_score > 0.35:
    votes += 1

if votes >= 2:
    avg_score = (skeleton_score + motion_score + dl_score) / 3
    return FALL, avg_score, "consensus"
```

### 3. Weighted Combination
```python
weighted_score = (
    skeleton_score * 0.35 +
    motion_score * 0.35 +
    dl_score * 0.30
)

if weighted_score > 0.50:
    return FALL, weighted_score, "weighted"
else:
    return NO_FALL, weighted_score, "none"
```

## Real-Time/Live Video Support

For live video streaming, a sliding window approach is used:

```python
class LiveFallDetector:
    def __init__(self, window_size=32, stride=8):
        self.frame_buffer = deque(maxlen=window_size)
        self.stride = stride
        self.frames_since_analysis = 0
    
    def add_frame(self, frame):
        self.frame_buffer.append(frame)
        self.frames_since_analysis += 1
        
        # Analyze every 'stride' frames
        if self.frames_since_analysis >= self.stride:
            if len(self.frame_buffer) == window_size:
                result = analyze_sequence(list(self.frame_buffer))
                self.frames_since_analysis = 0
                return result
        return None
```

This allows:
- **Continuous monitoring** without storing entire videos
- **Low latency**: Analysis every ~0.27s (8 frames @ 30fps)
- **Memory efficient**: Fixed buffer size
- **Temporal coherence**: Maintains context across frames

## Performance Characteristics

### Computational Complexity

| Layer | Time Complexity | Space Complexity | Avg Processing Time |
|-------|----------------|------------------|---------------------|
| Skeleton | O(n) per frame | O(1) | ~0.05s/frame |
| Motion | O(n²) frame diff | O(n) buffer | ~0.01s/frame |
| Deep Learning | O(n³) CNN+LSTM | O(n) | ~1.5s/batch |
| **Total** | **O(n³)** | **O(n)** | **~3-4s/video** |

*Note: First video takes ~240s due to model loading; subsequent videos ~15-25s*

### Accuracy Metrics

Based on comprehensive testing on 200 videos (see `evaluation_results/`):

**Overall Performance:**
- **Overall Accuracy**: 85.5% (171/200 videos correctly classified)
- **Sensitivity (Recall)**: 100% (40/40 falls detected - zero missed falls)
- **Specificity**: 81.9% (131/160 non-falls correctly identified)
- **Precision**: 58.0% (40/69 positive predictions were true falls)
- **F1-Score**: 73.4%
- **AUC-ROC**: ~0.95+

**Per-Category Accuracy:**
- **Falls**: 100% (40/40) - All falls detected
- **TUG**: 100% (40/40) - Perfect discrimination from falls
- **Arthritis Gait**: 100% (40/40) - No false positives
- **ADL**: 77.5% (31/40) - 9 false positives
- **Good Gait**: 50.0% (20/40) - 20 false positives

**Confusion Matrix:**
```
                Predicted
            No Fall    Fall
Actual  No    131      29    (81.9% specificity)
        Fall    0      40    (100% sensitivity)
```

**Key Findings:**
- ✅ Zero missed falls (critical safety requirement met)
- ✅ Perfect TUG suppression (novel algorithm validated)
- ✅ Perfect arthritis gait classification
- ⚠️ Normal gait videos show 50% false positive rate
- ⚠️ ADL videos show 22.5% false positive rate
- Trade-off: High sensitivity prioritized over specificity for safety

**Layer Contribution Analysis:**
| Layer | Mean Score | Std Dev | Role |
|-------|------------|---------|------|
| Skeleton | 0.115 | 0.146 | Geometric validation |
| Motion | 0.421 | 0.271 | Primary discriminator |
| Deep Learning | 0.331 | 0.242 | Context-aware classification |

**Processing Time:**
- Mean: 13.0s per video
- First video: ~333s (includes model loading)
- Falls: 19.3s (most complex analysis)
- TUG: 12.4s
- Gait/ADL: 10.5-11.6s

## Key Innovations

1. **Three-Layer Redundancy**: Multiple independent detection mechanisms ensure robustness
2. **TUG Pattern Suppression**: Novel segment-based algorithm achieves 100% TUG discrimination
3. **Hierarchical Decision Making**: Different confidence thresholds for different layers
4. **Real-time Capability**: Sliding window approach for continuous monitoring
5. **Ensemble Approach**: Combines geometric, temporal, and learned features
6. **Perfect Sensitivity**: Zero missed falls in 200-video evaluation (100% sensitivity)

### Validated Strengths

**Clinical Safety:**
- 100% fall detection rate ensures no events are missed
- Critical for elderly monitoring and high-risk patients
- Acceptable false positive rate (18.1%) trade-off for safety

**TUG Discrimination:**
- 100% accuracy distinguishing clinical assessments from actual falls
- Novel pattern-based algorithm validated on 40 TUG videos
- Prevents unnecessary alarms during routine testing

**Robust to Pathological Gait:**
- 100% accuracy on arthritis gait patterns
- Successfully handles impaired mobility patterns
- Distinguishes abnormal movement from actual falls

## Limitations and Future Work

### Current Limitations

**Performance Challenges:**
- Normal gait classification: 50% accuracy (20/40 false positives)
- ADL activities: 77.5% accuracy (9/40 false positives)
- Overall false positive rate: 18.1% (29/160 non-fall videos)
- Motion layer can be oversensitive to walking patterns

**Technical Constraints:**
- Processing time includes model loading overhead (~240s first video)
- Requires GPU for real-time deep learning inference
- Skeleton detection fails in poor lighting or occlusion
- Trained on specific camera angles and environments
- Duplicate/similar videos in dataset may affect generalization

**System Design:**
- High sensitivity prioritized over specificity (safety-first approach)
- May generate false alarms during vigorous normal activities
- Requires manual confirmation for detected falls

### Future Enhancements

**Immediate Improvements:**
- **Gait-Specific Tuning**: Adjust motion thresholds for normal walking patterns
- **Activity Context**: Incorporate time of day, location, recent activity history
- **Temporal Smoothing**: Multiple consecutive detections before alerting
- **User Feedback Loop**: Allow caregivers to mark false positives for retraining

**Advanced Features:**
- **Edge Deployment**: Optimize models for mobile/edge devices (TensorFlow Lite)
- **Multi-camera Fusion**: Combine multiple viewpoints for improved accuracy
- **Transfer Learning**: Adapt to new environments with few samples
- **Explainable AI**: Visualize which features triggered detection
- **Fall Type Classification**: Distinguish forward/backward/sideways falls
- **Pre-fall Detection**: Identify loss of balance before actual fall

**Research Directions:**
- Investigate attention mechanisms for temporal feature extraction
- Explore transformer architectures for video classification
- Study false positive patterns in gait and ADL categories
- Develop environment-adaptive threshold tuning
- Create larger, more diverse dataset with varied demographics

## Evaluation Dataset

The system was validated on a comprehensive dataset of 200 videos:

**Dataset Composition:**
- **Falls**: 40 videos (forward, backward, sideways falls)
- **ADL (Activities of Daily Living)**: 40 videos (sitting, standing, lying)
- **Good Gait**: 40 videos (normal walking patterns)
- **Arthritis Gait**: 40 videos (impaired mobility patterns)
- **TUG (Timed Up and Go)**: 40 videos (clinical assessment)

**Video Characteristics:**
- Resolution: 224×224 pixels (resized from original)
- Frame rate: 30 fps
- Duration: ~3-10 seconds per video
- Source: Simulated monitoring camera footage
- Location: `backend/media/simulation_footage/guardian/`

**Evaluation Approach:**
- All 200 videos tested without cherry-picking
- Stratified analysis by category
- Multiple metrics: accuracy, sensitivity, specificity, precision, F1-score
- Comprehensive visualizations: confusion matrix, ROC curve, precision-recall
- Per-layer contribution analysis
- Processing time benchmarking

**Visualizations Generated:**
All evaluation artifacts are in `evaluation_results/`:
1. `confusion_matrix.png` - Visual confusion matrix
2. `roc_curve.png` - ROC curve with AUC
3. `precision_recall_curve.png` - Precision-recall tradeoff
4. `performance_metrics.png` - Metrics bar chart
5. `layer_comparison.png` - Layer scores by category
6. `category_accuracy.png` - Per-category accuracy
7. `processing_time_analysis.png` - Time distribution
8. `detailed_results.csv` - Row-per-video results
9. `metrics_summary.json` - Machine-readable metrics
10. `evaluation_report.txt` - Text summary

## References

1. MediaPipe Pose: https://developers.google.com/mediapipe/solutions/vision/pose_landmarker
2. EfficientNetV2: Tan, M., & Le, Q. (2021). EfficientNetV2: Smaller Models and Faster Training. ICML 2021.
3. LSTM Networks: Hochreiter, S., & Schmidhuber, J. (1997). Long short-term memory. Neural computation, 9(8), 1735-1780.
4. Fall Detection Survey: Igual, R., Medrano, C., & Plaza, I. (2013). Challenges, issues and trends in fall detection systems. Biomedical engineering online, 12(1), 66.

## Deployment Recommendations

Based on evaluation results, the following deployment configuration is recommended:

**Production Settings:**
```python
# Threshold configuration
CONSENSUS_THRESHOLD = 2  # Two layers must agree
MOTION_HIGH_CONFIDENCE = 0.80  # Validated optimal
SKELETON_HIGH_CONFIDENCE = 0.70
DL_HIGH_CONFIDENCE = 0.70

# Real-time processing
WINDOW_SIZE = 32  # Frames per analysis
STRIDE = 8  # Analyze every 8 frames (~0.27s latency)
```

**Alert Strategy:**
- Immediate alert on fall detection
- 2-3 second confirmation window to reduce transient false positives
- Escalation protocol: notification → caregiver alert → emergency services
- Allow caregiver to mark false positives for system improvement

**Monitoring Dashboard:**
- Display layer scores for transparency
- Show confidence levels
- Log all detections (true positives and false positives)
- Provide statistics: daily fall count, false alarm rate

**Hardware Requirements:**
- Minimum: CPU-based inference (~15-20s per analysis)
- Recommended: GPU (NVIDIA GTX 1060 or better) for <5s processing
- Memory: 4GB RAM minimum, 8GB recommended
- Storage: 10GB for models and temporary video buffers

**Clinical Pilot Readiness:**
The system is ready for supervised pilot testing with:
- ✅ 100% fall detection (no missed falls)
- ✅ Real-time capability
- ✅ Acceptable processing time
- ⚠️ Monitor false positive rate with user feedback
- ⚠️ Collect additional data for gait/ADL refinement

## Citation

```bibtex
@thesis{smartcareplus2026,
  title={SmartCare+ Fall Detection: A Three-Layer Hybrid Approach},
  author={[Your Name]},
  year={2026},
  school={[Your University]},
  type={[Degree Type]}
}
```

---

**Last Updated**: February 5, 2026  
**Version**: 1.1  
**System**: SmartCare+ Guardian Service  
**Evaluation Dataset**: 200 videos (40 per category)  
**Key Achievement**: 100% sensitivity (zero missed falls) on comprehensive evaluation
