# Depth Camera Processing Flow (Stereo-Only)

## 项目概述

本项目实现**纯双目立体视觉深度相机算法**，通过DPU硬件引擎进行视差计算，结合AI算法增强，提供高精度的深度图像输出。

**核心理念**：
- **双目灰度相机**：立体视觉的核心传感器，依靠自然场景纹理
- **DPU引擎**：双目灰度图 → 视差图（硬件加速）
- **AI增强**：基于深度学习的视差优化与深度增强
- **现阶段重点**：流程梳理、算法评估、方案选型

---

## 硬件配置

| 组件 | 规格 | 说明 |
|------|------|------|
| **双目灰度相机** | 1280x800 @ 30fps, FOV 60°, 基线10cm | 立体视觉核心传感器 |
| **DPU** | 硬件视差计算引擎 | 加速立体匹配，输出视差图 |
| **NPU** | 2.5 TOPS@INT8 | AI推理加速（深度增强网络） |

**注**：相比散斑投影+RGB方案，本方案硬件更简洁，成本更低，但对场景纹理依赖更高。

---

## 主要处理流程

```
┌─────────────────────────────────────────────────────────────────┐
│                      1. 图像采集模块                             │
│  - 双目相机同步触发（左灰度、右灰度）                            │
│  - 时间戳对齐                                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
                    ┌─────────▼──────────┐
                    │   左右灰度图像      │
                    │  (自然场景纹理)     │
                    └─────────┬──────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│                    2. 图像预处理                               │
│  - 去噪 (Denoise)                                              │
│  - 畸变校正 (Undistortion)                                     │
│  - 立体校正 (Rectification)                                    │
│  - 亮度/对比度调整                                             │
│  - 对比度增强（弱纹理场景）                                    │
└─────────────────────────────┬─────────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│           3. DPU视差计算（硬件引擎）                           │
│                                                                │
│  【输入】左右校正灰度图 + 标定参数                             │
│  【输出】视差图 (Disparity Map)                                │
│                                                                │
│  - 算法: Semi-Global Matching (SGM) 或 Block Matching          │
│  - 视差范围: 0-128 像素（可配置）                              │
│  - 硬件加速: DPU专用引擎                                       │
│  - 后处理:                                                     │
│    • 左右一致性检查 (LR Check)                                 │
│    • 唯一性约束                                                │
│    • 亚像素精化                                                │
│                                                                │
│  【备选】DPU软件实现（算法对齐，方便硬件调优）                 │
│    - OpenCV: StereoBM / StereoSGBM                             │
│    - 自定义SGM实现（C++）                                      │
│    - 参数可调，输出格式与硬件一致                              │
│                                                                │
│  ⚠️ 纯双目方案依赖自然纹理，弱纹理区域易产生空洞               │
└─────────────────────────────┬─────────────────────────────────┘
                              │
                   ┌──────────▼──────────┐
                   │     视差图           │
                   │  (Disparity Map)    │
                   └──────────┬──────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│             4. 传统视差优化（基于几何）                         │
│                                                                │
│  【输入】视差图                                                 │
│  【输出】优化视差图                                             │
│                                                                │
│  - 中值滤波 (Median Filter, 去除椒盐噪声)                      │
│  - 双边滤波 (Bilateral Filter, 边缘保持平滑)                   │
│  - 孔洞填充（基于邻域插值）                                    │
│  - 飞点去除（深度不连续检测）                                  │
│  - 时间域滤波（IIR，运动检测）                                 │
│  - WLS滤波 (Weighted Least Squares, 边缘保持)                  │
│                                                                │
│  ⚠️ 传统方法无法恢复大面积无纹理区域的深度                     │
└─────────────────────────────┬─────────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│         5. AI深度增强（NPU加速，2.5 TOPS@INT8）                │
│                                                                │
│  【输入】灰度图 + 视差图                                        │
│  【输出】增强深度图                                             │
│                                                                │
│  核心思路：利用AI网络学习纹理-深度映射，增强弱纹理区域深度     │
│                                                                │
│  【候选算法】                                                  │
│                                                                │
│  A. 深度补全网络（Depth Completion）                           │
│     - Sparse-to-Dense CNN                                      │
│     - 输入: Left Grayscale + Sparse Disparity                  │
│     - 输出: Dense Depth                                        │
│     - 优点: 补全大面积空洞，学习场景先验                       │
│     - 适用: 弱纹理区域（白墙、桌面、地板等）                   │
│                                                                │
│  B. 视差细化网络（Disparity Refinement）                       │
│     - ResNet Encoder + U-Net Decoder                           │
│     - 输入: Left Grayscale + Right Grayscale + Raw Disparity   │
│     - 输出: Refined Disparity                                  │
│     - 优点: 端到端优化，边缘细化，噪声抑制                     │
│     - 适用: 整体精度提升                                       │
│                                                                │
│  C. 深度超分辨率（Depth Super-Resolution）                     │
│     - DKN (Deep Kalman Network)                                │
│     - FDSR (Fast Depth Super-Resolution)                       │
│     - 输入: Low-res Depth + Left Grayscale                     │
│     - 输出: High-res Depth                                     │
│     - 优点: 提升深度图分辨率和细节                             │
│     - 适用: 低分辨率DPU输出 → 高分辨率深度                     │
│                                                                │
│  D. 立体匹配网络（端到端替代DPU，算力充足时）                  │
│     - GwcNet / PSMNet / AANet                                  │
│     - 输入: Left Grayscale + Right Grayscale                   │
│     - 输出: Disparity Map                                      │
│     - 优点: 整体优化，精度更高，泛化性好                       │
│     - 缺点: 计算量大，需评估2.5T NPU能否实时                   │
│     - 适用: 高精度场景，或DPU性能不足时的替代方案              │
│                                                                │
│  E. 自监督/无监督深度学习（数据标注困难时）                    │
│     - Monodepth2 / StereoNet (Self-Supervised)                 │
│     - 输入: Left + Right Grayscale                             │
│     - 训练: 光度一致性损失（无需GT Depth）                     │
│     - 优点: 无需标注数据，可用自采集数据训练                   │
│     - 适用: GT数据获取困难的场景                               │
│                                                                │
│  【部署方案】                                                  │
│     - 训练: PyTorch + 自采集数据 + KITTI/SceneFlow             │
│     - 导出: ONNX格式                                           │
│     - 量化: FP32 → INT8 (PTQ/QAT)                              │
│     - 推理: ONNX Runtime (CPU) / NPU工具链 (INT8)              │
│     - 目标延迟: <30ms @ NPU                                    │
│                                                                │
│  ⚠️ 现阶段任务: 算法调研、精度vs性能评估、选型决策             │
└─────────────────────────────┬─────────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│                 6. 深度后处理                                  │
│                                                                │
│  - 深度范围限制 [min_depth, max_depth]                        │
│  - 单位转换: 视差 → 深度(mm)                                   │
│    depth_mm = (baseline * focal_length) / disparity           │
│  - 格式转换: float32 / uint16                                  │
│  - 置信度计算（可选）                                          │
└─────────────────────────────┬─────────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│                     7. 输出模块                                │
│                                                                │
│  - 深度图 (Depth Map, 16bit/float32)                          │
│  - 灰度图 (Left Grayscale, 8bit)                              │
│  - 点云 (Point Cloud, XYZ)                                     │
│  - 置信度图 (Confidence Map, 可选)                             │
└────────────────────────────────────────────────────────────────┘
```

---

## 详细处理步骤

### 1. 图像采集模块 (Image Acquisition)

**输入**: 硬件相机接口
**输出**: 左灰度图、右灰度图

**关键点**:
- 双目相机**硬件同步触发**（时间戳对齐）
- 帧缓冲管理（零拷贝传输）
- 曝光控制（自适应调整，保证纹理清晰）

**实现**:
```cpp
// src/core/image_capture.cpp
class ImageCapture {
public:
    struct Frame {
        cv::Mat left_gray;   // 1280x800, 8bit
        cv::Mat right_gray;  // 1280x800, 8bit
        uint64_t timestamp;  // 微秒级时间戳
    };

    bool capture(Frame& frame);
    void setExposure(int exposure_us);
    void setGain(float gain);
};
```

---

### 2. 图像预处理 (Image Preprocessing)

**输入**: 原始相机图像
**输出**: 校正后的图像

**步骤**:
1. **去噪处理**: 高斯滤波 (3x3 kernel, 保留纹理细节)
2. **畸变校正**: 使用相机内参和畸变系数 (Zhang标定)
3. **立体校正**: 双目图像行对齐 (Rectification)
4. **对比度增强**: CLAHE (对比度受限自适应直方图均衡化)
   - 弱纹理场景下增强局部对比度
   - 提升立体匹配成功率

**实现**:
```cpp
// src/core/preprocessing.cpp
void rectifyImages(const cv::Mat& left_raw, const cv::Mat& right_raw,
                   cv::Mat& left_rect, cv::Mat& right_rect,
                   const CalibParams& calib);

void enhanceContrast(cv::Mat& image, float clip_limit = 2.0, int tile_size = 8);
```

**优化**:
- OpenCV `remap()` 查找表 (LUT) 加速
- SIMD 优化 (SSE/NEON)

---

### 3. DPU视差计算 (Disparity Computation)

**输入**: 左右校正灰度图 + 标定参数
**输出**: 视差图 (Disparity Map)

#### 3.1 硬件方案（DPU引擎）

**特点**:
- **硬件加速**: DPU专用引擎，低延迟
- **算法**: Semi-Global Matching (SGM) 或优化的Block Matching
- **视差范围**: 0-128 像素（根据基线和场景深度配置）

**接口**:
```cpp
// src/hardware/dpu_driver.h
class DPUDriver {
public:
    struct Config {
        int min_disparity = 0;
        int max_disparity = 128;
        int block_size = 5;
        bool lr_check = true;
        int uniqueness_ratio = 15;
        int texture_threshold = 10;  // 低纹理区域阈值
    };

    bool compute(const cv::Mat& left, const cv::Mat& right,
                 cv::Mat& disparity, const Config& config);
};
```

**挑战**:
- 纯双目方案依赖自然纹理，**弱纹理区域易产生空洞**
- 需要后续AI算法弥补

---

#### 3.2 软件备选方案（算法对齐）

**目的**: 方便硬件调优、算法验证、参数对比

**方案A**: OpenCV StereoBM/StereoSGBM
```cpp
// src/core/stereo_matcher.cpp
class StereoMatcherSoftware {
public:
    cv::Ptr<cv::StereoBM> bm;
    cv::Ptr<cv::StereoSGBM> sgbm;

    void computeBM(const cv::Mat& left, const cv::Mat& right, cv::Mat& disparity);
    void computeSGBM(const cv::Mat& left, const cv::Mat& right, cv::Mat& disparity);
};
```

**方案B**: 自定义SGM实现
```cpp
// src/core/sgm.cpp
class CustomSGM {
    void compute(const uint8_t* left, const uint8_t* right,
                 float* disparity, int width, int height,
                 const SGMParams& params);
};
```

**对比测试**:
- 输入相同的左右灰度图和标定参数
- 输出格式一致（float32视差图）
- 评估指标：误差率、空洞率、边缘精度
- 用于硬件参数调优

---

### 4. 传统视差优化 (Traditional Disparity Refinement)

**输入**: 视差图
**输出**: 优化视差图

**方法**:

#### 4.1 中值滤波 (Median Filter)
```cpp
// 去除椒盐噪声
void medianFilter(cv::Mat& disparity, int kernel_size = 5);
```

#### 4.2 双边滤波 (Bilateral Filter)
```cpp
// 边缘保持平滑
void bilateralFilter(const cv::Mat& disparity_in, cv::Mat& disparity_out,
                     float sigma_color, float sigma_space);
```

#### 4.3 WLS滤波 (Weighted Least Squares Filter)
```cpp
// 更强的边缘保持能力
void wlsFilter(const cv::Mat& disparity, const cv::Mat& left_gray,
               cv::Mat& disparity_filtered, float lambda = 8000, float sigma = 1.5);
```

**OpenCV实现**:
```cpp
auto wls_filter = cv::ximgproc::createDisparityWLSFilter(left_matcher);
wls_filter->setLambda(8000);
wls_filter->setSigmaColor(1.5);
wls_filter->filter(disparity, left_gray, disparity_filtered);
```

#### 4.4 孔洞填充 (Hole Filling)
```cpp
// 基于邻域插值的孔洞填充
void holeFilling(cv::Mat& disparity, int max_hole_size = 50);
```

**逻辑**:
- 检测视差空洞（invalid值）
- 从邻近有效像素插值
- 避免深度不连续区域的错误填充

#### 4.5 飞点去除 (Outlier Removal)
```cpp
// 深度不连续检测
void removeFlyingPixels(cv::Mat& disparity, float depth_threshold = 50.0);
```

**逻辑**:
- 检测深度突变点
- 与邻域深度差异过大的点标记为无效

#### 4.6 时间域滤波 (Temporal Filtering)
```cpp
// IIR滤波，平滑时序抖动
void temporalFilter(cv::Mat& disparity_current, const cv::Mat& disparity_prev,
                    float alpha = 0.8);
```

**限制**:
- 传统方法无法恢复大面积无纹理区域的深度
- 需要AI算法增强

---

### 5. AI深度增强 (AI-Based Depth Enhancement)

**输入**: 灰度图 + 视差图
**输出**: 增强深度图

**核心目标**: 利用AI网络学习纹理-深度映射，弥补纯双目方案的弱纹理缺陷

---

#### 候选算法评估（现阶段重点）

##### A. 深度补全网络 (Depth Completion)

**代表算法**: Sparse-to-Dense CNN

**架构**:
```
Input: Left Grayscale (1 channel) + Sparse Disparity (1 channel)
Encoder: ResNet-18 (共享特征提取)
Decoder: U-Net风格上采样
Output: Dense Depth Map
```

**损失函数**:
```python
loss = L1_loss(pred, gt) + 0.5 * SSIM_loss(pred, gt) + 0.1 * Edge_loss(pred, gt)
```

**优点**:
- 补全大面积空洞
- 学习场景几何先验
- 适合弱纹理区域（白墙、桌面、地板等）

**缺点**:
- 需要大量训练数据
- 推理速度依赖NPU性能

**适用场景**: 弱纹理区域多的室内场景

**参考**: [Sparse-to-Dense, ICRA 2018]

---

##### B. 视差细化网络 (Disparity Refinement)

**架构**:
```
Input: Left Grayscale (1 channel) + Right Grayscale (1 channel) + Raw Disparity (1 channel)

Encoder (ResNet-34):
  - Conv1-5: 多尺度特征提取
  - 同时处理左右灰度图和粗略视差图

Decoder (U-Net):
  - Skip connections from encoder
  - Deconv layers: 1/16 → 1/8 → 1/4 → 1/2 → 1/1
  - Final Conv: Output refined disparity

Output: Refined Disparity Map (float32)
```

**训练策略**:
```python
# 损失函数
L1_loss = |pred - gt|
SSIM_loss = 1 - SSIM(pred, gt)
Edge_loss = |∇pred - ∇gt|  # 边缘梯度损失
Smoothness_loss = |∇²pred|  # 平滑正则化

total_loss = L1_loss + 0.5 * SSIM_loss + 0.2 * Edge_loss + 0.1 * Smoothness_loss

# 数据增强
- Random crop, flip
- Brightness/contrast jitter (灰度图)
- Gaussian noise (视差图)
```

**优点**:
- 端到端优化，整体精度提升
- 边缘细化效果好
- 噪声抑制能力强
- 适合实时部署（MobileNet替换ResNet）

**缺点**:
- 需要标注数据（Left + Right + GT Depth）
- 泛化能力取决于训练数据多样性

**适用场景**: 整体深度精度提升，边缘优化

---

##### C. 深度超分辨率 (Depth Super-Resolution)

**代表算法**: DKN (Deep Kalman Network), FDSR

**场景**:
- 低分辨率视差图 → 高分辨率深度图
- 灰度图提供高频细节引导

**架构**:
```
Input: Low-res Depth + Left Grayscale (High-res)
Feature Extraction: Grayscale Guide (CNN)
Upsampling: Deformable Conv + Guided Filtering
Output: High-res Depth
```

**优点**:
- 提升深度图分辨率
- 边缘细节更清晰
- 可与硬件DPU低分辨率输出配合

**缺点**:
- 对训练数据质量要求高
- 超分倍数有限（2x-4x）

**适用场景**: DPU输出分辨率较低，需要上采样

**参考**: [DKN, ECCV 2018], [FDSR, CVPR 2020]

---

##### D. 端到端立体匹配网络 (End-to-End Stereo Matching)

**代表算法**: GwcNet, PSMNet, AANet, RAFT-Stereo

**架构** (以PSMNet为例):
```
Input: Left Grayscale + Right Grayscale

Feature Extraction:
  - Shared CNN (ResNet/MobileNet)
  - 多尺度特征金字塔

Cost Volume Construction:
  - 4D Cost Volume (H x W x D x F)
  - Group-wise correlation (GwcNet)

Cost Aggregation:
  - 3D CNN (Stacked Hourglass / U-Net)
  - 全局上下文信息融合

Disparity Regression:
  - Soft-argmax (可微分)
  - Output: Disparity Map

Multi-scale Refinement:
  - 多尺度监督
  - 边缘细化
```

**训练**:
```python
# 损失函数
loss = smooth_L1(pred, gt) + 0.5 * Edge_loss(pred, gt)

# 数据集
- SceneFlow (合成数据，240k图像对)
- KITTI (真实数据，200图像对)
- 自采集数据（推荐）
```

**优点**:
- 整体优化，精度高于传统SGM
- 泛化性能好
- 边缘细节清晰
- 可完全替代DPU硬件（如果算力充足）

**缺点**:
- 计算量大（PSMNet: ~300 GOPs）
- **需评估2.5 TOPS NPU能否实时**
- 功耗较高

**算力评估**:
- PSMNet-tiny: ~50 GOPs @640x480
- MobileStereoNet: ~10 GOPs @640x480
- **推荐**: 轻量化网络（MobileStereoNet / FastACVNet）

**适用场景**:
- 高精度要求
- DPU性能不足
- 算力充足（需验证）

**参考**: [PSMNet, CVPR 2018], [GwcNet, CVPR 2019], [AANet, CVPR 2020], [RAFT-Stereo, 3DV 2021]

---

##### E. 自监督/无监督深度学习 (Self-Supervised Learning)

**代表算法**: Monodepth2, StereoNet (Self-Supervised)

**核心思路**: 无需Ground Truth深度，利用光度一致性损失训练

**架构**:
```
Input: Left Grayscale + Right Grayscale

Encoder-Decoder (DispNet):
  - 输入左图，输出视差图
  - U-Net架构

Training Loss (自监督):
  - 光度一致性: I_left = warp(I_right, disparity)
  - 平滑正则化: |∇disparity|
  - 左右一致性: disparity_left ≈ -disparity_right
```

**训练**:
```python
# 损失函数
photometric_loss = |I_left - warp(I_right, disp_left)|
smoothness_loss = |∇disp_left| * exp(-|∇I_left|)
lr_consistency_loss = |disp_left - warp(disp_right, disp_left)|

total_loss = photometric_loss + 0.1 * smoothness_loss + 0.01 * lr_consistency_loss

# 无需GT Depth！
```

**优点**:
- **无需标注数据**，只需左右图像对
- 可用自采集数据训练
- 部署灵活

**缺点**:
- 精度低于有监督方法
- 遮挡区域处理困难
- 需要大量无标注数据

**适用场景**: GT深度数据获取困难，或数据标注成本高

**参考**: [Monodepth2, ICCV 2019], [Self-Supervised Stereo, CVPR 2018]

---

#### 算法选型建议（现阶段评估）

| 算法 | 精度 | 速度 | 数据需求 | 实现复杂度 | 适用场景 | 优先级 |
|------|------|------|---------|-----------|---------|--------|
| 深度补全CNN | ⭐⭐⭐⭐ | ⭐⭐⭐ | 需GT | ⭐⭐⭐ | 弱纹理、大空洞 | **高** |
| 视差细化网络 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 需GT | ⭐⭐⭐ | 整体优化 | **高** |
| 深度超分辨率 | ⭐⭐⭐ | ⭐⭐⭐⭐ | 需GT | ⭐⭐⭐ | 低分辨率DPU | **中** |
| 端到端立体网络 | ⭐⭐⭐⭐⭐ | ⭐⭐ | 需GT | ⭐⭐⭐⭐ | 高精度/替代DPU | **中** |
| 自监督学习 | ⭐⭐⭐ | ⭐⭐⭐ | 无需GT | ⭐⭐⭐⭐ | 无标注数据 | **中** |

**推荐方案**:

1. **短期（快速验证）**:
   - **视差细化网络**（ResNet-18 + U-Net）
   - 原因：平衡精度和速度，易于部署到NPU
   - 输入：左灰度图 + 粗略视差图
   - 目标延迟：<20ms @ NPU

2. **中期（精度优化）**:
   - **深度补全网络**（针对弱纹理区域）
   - 原因：专门处理空洞问题
   - 训练自采集数据 + KITTI

3. **长期（算力充足时）**:
   - **轻量化端到端立体网络**（MobileStereoNet）
   - 原因：完全替代DPU，端到端优化
   - 需评估2.5 TOPS NPU实时性

4. **备选（无标注数据）**:
   - **自监督学习**
   - 原因：无需GT深度，可用自采集数据训练

---

#### 部署方案

**训练阶段** (Python/PyTorch):
```python
# python/training/train_disparity_refinement.py
import torch
import torch.nn as nn

class DisparityRefinementNet(nn.Module):
    def __init__(self):
        self.encoder = ResNetEncoder(layers=18, in_channels=3)  # left + right + raw_disp
        self.decoder = UNetDecoder(skip_connections=True)

    def forward(self, left_gray, right_gray, raw_disparity):
        x = torch.cat([left_gray, right_gray, raw_disparity], dim=1)
        features = self.encoder(x)
        refined_disparity = self.decoder(features)
        return refined_disparity

# 训练
model = DisparityRefinementNet()
optimizer = torch.optim.Adam(model.parameters(), lr=1e-4)
# ... 训练循环
torch.onnx.export(model, (left, right, disp), "disparity_refinement.onnx")
```

**量化** (INT8):
```python
# python/tools/quantize_onnx.py
from onnxruntime.quantization import quantize_dynamic, quantize_static

# 动态量化（快速）
quantize_dynamic("disparity_refinement.onnx",
                 "disparity_refinement_int8.onnx",
                 weight_type=QuantType.QInt8)

# 静态量化（精度更高，需校准数据）
quantize_static("disparity_refinement.onnx",
                "disparity_refinement_int8.onnx",
                calibration_data_reader=calib_data)
```

**推理阶段** (C++/ONNX Runtime):
```cpp
// src/core/ai_depth.cpp
class AIDepthEnhancer {
    Ort::Session session;

public:
    void loadModel(const std::string& onnx_path);
    void infer(const cv::Mat& left_gray, const cv::Mat& right_gray,
               const cv::Mat& raw_disparity, cv::Mat& enhanced_disparity);
};
```

**NPU部署**:
- 厂商工具链转换（ONNX → NPU格式）
- 算子优化、内存优化
- 目标延迟: <30ms @ 2.5 TOPS INT8

---

### 6. 深度后处理 (Depth Post-processing)

**输入**: 增强视差图
**输出**: 深度图

**步骤**:

#### 6.1 视差到深度转换
```cpp
// 公式: depth = (baseline * focal_length) / disparity
void disparityToDepth(const cv::Mat& disparity, cv::Mat& depth,
                      float baseline_mm, float focal_px) {
    for (int v = 0; v < disparity.rows; ++v) {
        for (int u = 0; u < disparity.cols; ++u) {
            float disp = disparity.at<float>(v, u);
            if (disp > 0) {
                depth.at<float>(v, u) = (baseline_mm * focal_px) / disp;
            } else {
                depth.at<float>(v, u) = 0;  // 无效深度
            }
        }
    }
}
```

#### 6.2 深度范围限制
```cpp
void clipDepth(cv::Mat& depth, float min_depth, float max_depth) {
    cv::threshold(depth, depth, max_depth, 0, cv::THRESH_TOZERO_INV);
    cv::threshold(depth, depth, min_depth, 0, cv::THRESH_TOZERO);
}
```

#### 6.3 格式转换
```cpp
// float32 → uint16 (单位: mm, 0-65535)
void convertDepthFormat(const cv::Mat& depth_f32, cv::Mat& depth_u16) {
    depth_f32.convertTo(depth_u16, CV_16U);
}
```

#### 6.4 置信度计算（可选）
```cpp
// 基于视差唯一性、纹理、左右一致性计算置信度
void computeConfidence(const cv::Mat& disparity, const cv::Mat& left_gray,
                       cv::Mat& confidence);
```

---

### 7. 输出模块 (Output)

**输出格式**:

| 类型 | 格式 | 说明 |
|------|------|------|
| **深度图** | 16bit PNG / 32bit TIFF | 单位：毫米，0表示无效 |
| **灰度图** | 8bit PNG | 左灰度图像 |
| **点云** | PLY / PCD | XYZ, ASCII/Binary |
| **置信度图** | 8bit PNG | 0-255, 可选输出 |

**示例代码**:
```cpp
// src/utils/io.cpp
void saveDepth(const cv::Mat& depth, const std::string& path);

void savePointCloud(const cv::Mat& depth, const cv::Mat& gray,
                    const Eigen::Matrix3f& K, const std::string& path) {
    // 生成XYZ点云
    std::ofstream ofs(path);
    ofs << "ply\n";
    // ... PLY格式写入
}
```

---

## 性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| **处理帧率** | ≥30 fps | 实时性要求 |
| **深度精度** | ≤1% @ 1m | 相对误差 |
| **深度范围** | 0.3m - 10m | 有效测量范围 |
| **端到端延迟** | ≤50ms | 采集到输出 |
| **功耗** | ≤4W | 整机功耗（无RGB相机/散斑） |

**性能分解** (估算):
- 图像采集: ~5ms
- 预处理: ~5ms
- DPU视差计算: ~15ms (硬件加速)
- 传统优化: ~5ms
- AI增强: ~15ms (NPU, INT8)
- 后处理: ~3ms
- **总计**: ~48ms ✅

---

## 纯双目方案的优势与挑战

### 优势
✅ **硬件简洁**: 无需散斑投影器和RGB相机，成本更低
✅ **功耗更低**: 减少硬件组件，降低整机功耗
✅ **结构紧凑**: 适合小型化设备
✅ **无需标定复杂**: 只需双目标定，无需多模态配准

### 挑战
⚠️ **弱纹理问题**: 白墙、桌面、地板等区域易产生空洞
⚠️ **空洞率较高**: 相比散斑方案，无纹理区域更多
⚠️ **重复纹理**: 周期性纹理易导致误匹配
⚠️ **光照敏感**: 低光、强光条件下性能下降

### 解决方案
✔️ **AI算法增强**: 利用2.5 TOPS NPU补全弱纹理区域深度
✔️ **自适应曝光**: 根据场景亮度动态调整曝光
✔️ **多帧融合**: 时间域滤波，提升稳定性
✔️ **场景优化**: 针对特定场景训练AI模型

---

## 现阶段工作重点：流程梳理与评估

### 1. 算法调研
- [ ] DPU硬件接口文档梳理
- [ ] DPU软件实现方案选型（OpenCV vs 自定义SGM）
- [ ] 传统视差优化算法调研（WLS, 孔洞填充等）
- [ ] AI深度增强网络调研
  - [ ] 深度补全网络（Sparse-to-Dense）
  - [ ] 视差细化网络（Refinement）
  - [ ] 深度超分辨率（DKN, FDSR）
  - [ ] 端到端立体网络（PSMNet, AANet, MobileStereoNet）
  - [ ] 自监督学习（Monodepth2）
- [ ] 算力评估（2.5 TOPS NPU能否支持端到端立体网络）

### 2. 数据准备
- [ ] 相机标定（内参+外参）
- [ ] 测试场景设计（弱纹理、重复纹理、边缘、动态等）
- [ ] Ground Truth深度数据采集（激光雷达/结构光扫描仪）
- [ ] 自采集数据集构建（Left + Right + GT Depth）
- [ ] 弱纹理场景专项测试数据

### 3. 基线实现
- [ ] 图像采集与预处理模块
- [ ] DPU软件模拟实现（对齐硬件输出）
- [ ] 传统视差优化（双边滤波、WLS、孔洞填充）
- [ ] 基础输出模块（深度图/点云）

### 4. 性能评估
- [ ] DPU硬件 vs 软件精度对比
- [ ] 弱纹理场景空洞率统计
- [ ] 传统优化方法效果评估
- [ ] 端到端延迟测试
- [ ] 内存/功耗profiling

### 5. AI方案选型
- [ ] 训练数据集准备（自采集+KITTI+SceneFlow）
- [ ] 候选网络训练与对比
  - [ ] 视差细化网络（优先）
  - [ ] 深度补全网络
  - [ ] 轻量化立体网络（MobileStereoNet）
  - [ ] 自监督方法（备选）
- [ ] NPU部署可行性验证（ONNX → INT8 → NPU）
- [ ] 精度 vs 速度 trade-off 评估
- [ ] 弱纹理区域增强效果验证

### 6. 文档输出
- [ ] 算法评估报告（精度、性能、复杂度）
- [ ] 方案选型建议
- [ ] 技术路线图（短期/中期/长期）
- [ ] 风险评估与备选方案
- [ ] 纯双目 vs 散斑+RGB方案对比分析

---

## 技术栈

### 开发阶段
| 组件 | 技术 |
|------|------|
| **语言** | Python 3.8+, C++17 |
| **深度学习** | PyTorch 2.0, ONNX |
| **计算机视觉** | OpenCV 4.x, Eigen |
| **数值计算** | NumPy, SciPy |
| **可视化** | Matplotlib, Open3D |

### 部署阶段
| 组件 | 技术 |
|------|------|
| **推理引擎** | ONNX Runtime |
| **嵌入式平台** | NPU工具链 (厂商SDK) |
| **构建系统** | CMake 3.15+ |
| **加速** | OpenMP, SIMD (SSE/NEON) |
| **DPU接口** | 厂商驱动API (C/C++) |

---

## 未来优化方向

1. **多帧融合**:
   - 时序信息融合，提升精度和稳定性
   - 运动估计 (Visual Odometry)
   - 动态场景深度估计

2. **SLAM集成**:
   - 相机位姿估计
   - 动态场景处理
   - 地图构建

3. **自适应算法**:
   - 场景检测（弱纹理 vs 强纹理）
   - 动态切换传统算法/AI算法
   - 自适应参数调整

4. **端到端学习**:
   - 整体pipeline神经网络化
   - 联合优化视差计算和深度细化
   - 轻量化网络设计（针对2.5 TOPS NPU）

5. **主动光源（可选）**:
   - 如果弱纹理问题严重，考虑增加激光纹理投影
   - 成本和功耗trade-off评估

---

## 参考文献

### 立体匹配
1. Hirschmuller, H. (2007). Stereo Processing by Semiglobal Matching and Mutual Information. TPAMI.
2. Chang, J.-R., & Chen, Y.-S. (2018). Pyramid Stereo Matching Network (PSMNet). CVPR.
3. Guo, X., et al. (2019). Group-wise Correlation Stereo Network (GwcNet). CVPR.
4. Xu, H., & Zhang, J. (2020). AANet: Adaptive Aggregation Network for Efficient Stereo Matching. CVPR.
5. Lipson, L., et al. (2021). RAFT-Stereo: Multilevel Recurrent Field Transforms for Stereo Matching. 3DV.

### 深度补全
6. Ma, F., & Karaman, S. (2018). Sparse-to-Dense: Depth Prediction from Sparse Depth Samples and a Single Image. ICRA.
7. Uhrig, J., et al. (2017). Sparsity Invariant CNNs for Depth Completion. 3DV.

### 深度超分辨率
8. Kim, B., et al. (2018). Deep Kalman Network: Learning Depth Super-Resolution from RGB-D Data. ECCV.
9. He, L., et al. (2020). Fast Depth Super-Resolution (FDSR). CVPR.

### 自监督学习
10. Godard, C., et al. (2019). Digging Into Self-Supervised Monocular Depth Estimation (Monodepth2). ICCV.
11. Zhou, C., et al. (2017). Unsupervised Learning of Depth and Ego-Motion from Video. CVPR.

### 视差优化
12. He, K., et al. (2013). Guided Image Filtering. TPAMI.
13. Hosni, A., et al. (2013). Fast Cost-Volume Filtering for Visual Correspondence. TPAMI.

### 数据集
14. KITTI Stereo Dataset: http://www.cvlibs.net/datasets/kitti/
15. SceneFlow Dataset: https://lmb.informatik.uni-freiburg.de/resources/datasets/SceneFlowDatasets.en.html
16. Middlebury Stereo Dataset: https://vision.middlebury.edu/stereo/

---

## 版本管理

- **格式**: vx.yy.zzz
  - `x`: 大版本 (架构变更)
  - `yy`: 次版本 (功能增加)
  - `zzz`: 小版本 (Bug修复/优化)

- **Git工作流**:
  - 每次实现前提交 (保持可回退)
  - 清晰的commit message
  - 分支策略: `main` (稳定) / `develop` (开发) / `feature/*` (特性)

---

*文档版本: v0.01.001*
*最后更新: 2025-11-12*
*状态: 流程梳理与评估阶段*
