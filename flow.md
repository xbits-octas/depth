# Depth Camera Processing Flow

## 项目概述

本项目实现**双目+散斑投影+RGB深度相机算法**，通过DPU硬件引擎进行视差计算，结合RGB纹理信息进行深度优化与AI增强，提供高精度的深度图像输出。

**核心理念**：
- **散斑投影器**：增强弱纹理区域的纹理信息，减少视差计算的空洞，不单独处理
- **DPU引擎**：双目灰度图（带/不带散斑）→ 视差图（硬件加速）
- **RGB纹理**：提供丰富的纹理信息用于AI增强和深度优化
- **现阶段重点**：流程梳理、算法评估、方案选型

---

## 硬件配置

| 组件 | 规格 | 说明 |
|------|------|------|
| **双目灰度相机** | 1280x800 @ 30fps, FOV 60°, 基线10cm | 立体视觉核心传感器 |
| **散斑投影器** | 近红外斑点, 2万个斑点 | 增强弱纹理区域，减少视差空洞 |
| **RGB彩色相机** | 1280x800 @ 30fps, FOV 60° | 提供纹理信息，用于AI增强 |
| **DPU** | 硬件视差计算引擎 | 加速立体匹配，输出视差图 |
| **NPU** | 2.5 TOPS@INT8 | AI推理加速（深度增强网络） |

---

## 主要处理流程

```
┌─────────────────────────────────────────────────────────────────┐
│                      1. 图像采集模块                             │
│  - 三路相机同步触发（左灰度、右灰度、RGB）                       │
│  - 散斑投影器同步控制（开/关）                                   │
│  - 时间戳对齐                                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
        ┌───────▼──────┐            ┌───────▼──────┐
        │ 左右灰度图像  │            │   RGB图像     │
        │ (带散斑纹理)  │            │ (纹理丰富)    │
        └───────┬──────┘            └───────┬──────┘
                │                           │
┌───────────────▼───────────────┐           │
│    2. 图像预处理               │           │
│  - 去噪 (Denoise)              │           │
│  - 畸变校正 (Undistortion)     │           │
│  - 立体校正 (Rectification)    │           │
│  - 亮度/对比度调整             │           │
└───────────────┬───────────────┘           │
                │                           │
┌───────────────▼───────────────────────────────────────────────┐
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
└────────────────────────────────────┬──────────────────────────┘
                                     │
                          ┌──────────▼──────────┐
                          │     视差图           │
                          │  (Disparity Map)    │
                          └──────────┬──────────┘
                                     │
┌────────────────────────────────────▼──────────────────────────┐
│             4. RGB引导深度优化（传统方法）                      │
│                                                                │
│  【输入】视差图 + RGB图                                         │
│  【输出】优化视差图                                             │
│                                                                │
│  - Joint Bilateral Filter（RGB引导滤波）                       │
│  - Guided Filter（导向滤波，边缘保持）                         │
│  - 孔洞填充（基于RGB纹理扩散）                                 │
│  - 飞点去除（RGB边缘辅助检测）                                 │
│  - 时间域滤波（IIR，运动检测）                                 │
│                                                                │
│  ⚠️ RGB纹理丰富，可提供更准确的边缘信息                        │
└────────────────────────────────────┬──────────────────────────┘
                                     │
┌────────────────────────────────────▼──────────────────────────┐
│         5. AI深度增强（RGB+视差融合，NPU加速）                 │
│                                                                │
│  【输入】优化视差图 + RGB图                                     │
│  【输出】增强深度图                                             │
│                                                                │
│  核心思路：利用RGB丰富纹理增强深度精度                         │
│                                                                │
│  【候选算法】                                                  │
│                                                                │
│  A. 深度补全网络                                               │
│     - Sparse-to-Dense CNN                                      │
│     - 输入: RGB + Sparse Disparity                             │
│     - 输出: Dense Depth                                        │
│     - 优点: 补全大面积空洞                                     │
│                                                                │
│  B. 深度超分辨率                                               │
│     - DKN (Deep Kalman Network)                                │
│     - FDSR (Fast Depth Super-Resolution)                       │
│     - 输入: Low-res Depth + High-res RGB                       │
│     - 输出: High-res Depth                                     │
│     - 优点: 提升深度图分辨率和细节                             │
│                                                                │
│  C. 端到端深度细化                                             │
│     - ResNet/MobileNet Encoder + U-Net Decoder                 │
│     - 输入: RGB + Raw Disparity                                │
│     - 输出: Refined Depth                                      │
│     - 损失函数: L1 + SSIM + Edge Loss                          │
│     - 优点: 整体优化，边缘细化                                 │
│                                                                │
│  D. 高斯泼溅 (Gaussian Splatting, 实验性)                      │
│     - 3D Gaussian Splatting for Depth Enhancement              │
│     - 输入: RGB + Point Cloud (from Disparity)                 │
│     - 过程: 构建3D高斯场 → 优化 → 重投影深度                   │
│     - 优点: 平滑且保持几何一致性                               │
│     - 缺点: 计算量大，需评估实时性                             │
│                                                                │
│  【部署方案】                                                  │
│     - 训练: PyTorch + 自采集数据 + KITTI/NYU Depth             │
│     - 导出: ONNX格式                                           │
│     - 推理: ONNX Runtime (CPU) / NPU工具链 (INT8量化)          │
│                                                                │
│  ⚠️ 现阶段任务: 算法调研、精度vs性能评估、选型决策             │
└────────────────────────────────────┬──────────────────────────┘
                                     │
┌────────────────────────────────────▼──────────────────────────┐
│                 6. RGB配准与后处理                             │
│                                                                │
│  - 深度图到RGB视角的配准（外参标定）                           │
│  - 深度范围限制 [min_depth, max_depth]                        │
│  - 单位转换: 视差 → 深度(mm)                                   │
│    depth_mm = (baseline * focal_length) / disparity           │
│  - 格式转换: float32 / uint16                                  │
└────────────────────────────────────┬──────────────────────────┘
                                     │
┌────────────────────────────────────▼──────────────────────────┐
│                     7. 输出模块                                │
│                                                                │
│  - 深度图 (Depth Map, 16bit/float32)                          │
│  - RGB图 (Color Image, 8bit)                                  │
│  - 点云 (Point Cloud, XYZ+RGB)                                 │
│  - 置信度图 (Confidence Map, 可选)                             │
└────────────────────────────────────────────────────────────────┘
```

---

## 详细处理步骤

### 1. 图像采集模块 (Image Acquisition)

**输入**: 硬件相机接口
**输出**: 左灰度图、右灰度图、RGB图

**关键点**:
- 三路相机**硬件同步触发**（时间戳对齐）
- 散斑投影器同步控制（可选开/关，用于对比测试）
- 帧缓冲管理（零拷贝传输）

**实现**:
```cpp
// src/core/image_capture.cpp
class ImageCapture {
public:
    struct Frame {
        cv::Mat left_gray;   // 1280x800, 8bit
        cv::Mat right_gray;  // 1280x800, 8bit
        cv::Mat rgb;         // 1280x800, 8bit x3
        uint64_t timestamp;  // 微秒级时间戳
    };

    bool capture(Frame& frame);
    void enableStructuredLight(bool enable);
};
```

---

### 2. 图像预处理 (Image Preprocessing)

**输入**: 原始相机图像
**输出**: 校正后的图像

**步骤**:
1. **去噪处理**: 高斯滤波 (5x5 kernel)
2. **畸变校正**: 使用相机内参和畸变系数 (Zhang标定)
3. **立体校正**: 双目图像行对齐 (Rectification)
4. **亮度调整**: 自动曝光补偿 (直方图均衡化)

**实现**:
- OpenCV `remap()` 查找表 (LUT) 加速
- SIMD 优化 (SSE/NEON)

```cpp
// src/core/preprocessing.cpp
void rectifyImages(const cv::Mat& left_raw, const cv::Mat& right_raw,
                   cv::Mat& left_rect, cv::Mat& right_rect,
                   const CalibParams& calib);
```

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
    };

    bool compute(const cv::Mat& left, const cv::Mat& right,
                 cv::Mat& disparity, const Config& config);
};
```

**散斑作用**:
- 散斑投影器**增强弱纹理区域**（白墙、桌面等）的纹理信息
- **减少视差空洞**，提高匹配成功率
- **不需要单独处理**，直接输入DPU即可

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
    // 参数与DPU硬件对齐
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

### 4. RGB引导深度优化 (RGB-Guided Depth Refinement)

**输入**: 视差图 + RGB图
**输出**: 优化视差图

**核心思路**: RGB图纹理丰富，可提供更准确的边缘和结构信息

**方法**:

#### 4.1 Joint Bilateral Filter（联合双边滤波）
```cpp
// 以RGB图为引导，平滑视差图同时保持边缘
void jointBilateralFilter(const cv::Mat& disparity, const cv::Mat& rgb,
                          cv::Mat& disparity_filtered,
                          float sigma_color, float sigma_space);
```

**优点**:
- 利用RGB边缘信息，避免深度边缘模糊
- 去除噪声，保持物体边界

#### 4.2 Guided Filter（导向滤波）
```cpp
// 更快的边缘保持滤波
void guidedFilter(const cv::Mat& disparity, const cv::Mat& rgb,
                  cv::Mat& disparity_filtered, int radius, float eps);
```

**优点**:
- 复杂度 O(N)，比双边滤波快
- 边缘保持效果好

#### 4.3 孔洞填充（RGB辅助）
```cpp
// 基于RGB纹理相似性的扩散填充
void holeFilling(cv::Mat& disparity, const cv::Mat& rgb,
                 int max_hole_size, float color_threshold);
```

**逻辑**:
- 检测视差空洞（invalid值）
- 从邻近有效像素扩散，优先选择RGB颜色相似的像素
- 避免深度不连续区域的错误填充

#### 4.4 飞点去除（Outlier Removal）
```cpp
// 结合RGB边缘检测的飞点去除
void removeFlyingPixels(cv::Mat& disparity, const cv::Mat& rgb,
                        float depth_threshold, float edge_threshold);
```

**逻辑**:
- 检测深度不连续边缘
- 如果RGB图也存在边缘 → 保留（物体边界）
- 如果RGB图无边缘 → 去除（飞点噪声）

---

### 5. AI深度增强 (AI-Based Depth Enhancement)

**输入**: 优化视差图 + RGB图
**输出**: 增强深度图

**核心目标**: 利用RGB丰富纹理，通过AI网络进一步提升深度精度和完整性

---

#### 候选算法评估（现阶段重点）

##### A. 深度补全网络 (Depth Completion)

**代表算法**: Sparse-to-Dense CNN

**架构**:
```
Input: RGB (3 channels) + Sparse Disparity (1 channel)
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
- RGB纹理提供语义信息
- 适合弱纹理区域

**缺点**:
- 需要大量训练数据
- 推理速度依赖NPU性能

**参考**: [Sparse-to-Dense, ICRA 2018]

---

##### B. 深度超分辨率 (Depth Super-Resolution)

**代表算法**: DKN (Deep Kalman Network), FDSR

**场景**:
- 低分辨率视差图 → 高分辨率深度图
- RGB图提供高频细节

**架构**:
```
Input: Low-res Depth + High-res RGB
Feature Extraction: RGB Guide (CNN)
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

**参考**: [DKN, ECCV 2018]

---

##### C. 端到端深度细化 (End-to-End Refinement)

**架构**:
```
Input: RGB (3 channels) + Raw Disparity (1 channel)

Encoder (ResNet-34):
  - Conv1-5: 共享RGB和视差特征
  - Multi-scale feature extraction

Decoder (U-Net):
  - Skip connections from encoder
  - Deconv layers: 1/16 → 1/8 → 1/4 → 1/2 → 1/1
  - Final Conv: Output refined depth

Output: Refined Depth Map (float32)
```

**训练策略**:
```python
# 损失函数
L1_loss = |pred - gt|
SSIM_loss = 1 - SSIM(pred, gt)
Edge_loss = |∇pred - ∇gt|  # 边缘梯度损失

total_loss = L1_loss + 0.5 * SSIM_loss + 0.2 * Edge_loss

# 数据增强
- Random crop, flip, rotate
- Color jitter (RGB only)
- Gaussian noise (Disparity only)
```

**优点**:
- 整体优化，端到端学习
- 边缘细化效果好
- 适合实时部署（MobileNet替换ResNet）

**缺点**:
- 需要大量标注数据（RGB + GT Depth）
- 泛化能力取决于训练数据多样性

**参考**: [Depth Refinement Network]

---

##### D. 高斯泼溅 (Gaussian Splatting, 实验性)

**方法**: 3D Gaussian Splatting for Depth Enhancement

**流程**:
```
1. 视差图 → 3D点云 (Sparse)
   P_3d = inverse_project(disparity, calib)

2. RGB引导3D高斯场构建
   For each 3D point:
       - 位置: (x, y, z)
       - 颜色: RGB值
       - 协方差: 基于邻域点拟合

3. 优化高斯场
   - 最小化重投影误差
   - RGB一致性约束
   - 平滑正则化

4. 重投影深度图
   Render depth from optimized Gaussian field
```

**优点**:
- 3D几何一致性强
- 平滑且保持结构
- 可处理多视角融合（如果有多个视角）

**缺点**:
- 计算量大（需评估实时性）
- 工程实现复杂
- 初始点云质量要求高

**适用场景**:
- 后处理优化（非实时）
- 多帧融合深度估计
- 高精度应用（如3D重建）

**参考**: [3D Gaussian Splatting, SIGGRAPH 2023]

---

#### 算法选型建议（现阶段评估）

| 算法 | 精度 | 速度 | 实现复杂度 | 适用场景 | 优先级 |
|------|------|------|-----------|---------|--------|
| 深度补全CNN | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | 弱纹理、大空洞 | **高** |
| 深度超分辨率 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | 低分辨率DPU输出 | **中** |
| 端到端细化 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | 整体优化 | **高** |
| 高斯泼溅 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | 高精度/多帧融合 | **低** |

**推荐方案**:
1. **短期**: 端到端深度细化网络（ResNet/MobileNet + U-Net）
   - 快速原型验证
   - 平衡精度和速度
   - 易于部署到NPU

2. **中期**: 深度补全网络（针对性优化）
   - 专门处理空洞问题
   - 训练自采集数据

3. **长期**: 高斯泼溅（研究方向）
   - 用于多帧融合
   - 高精度场景

---

#### 部署方案

**训练阶段** (Python/PyTorch):
```python
# python/training/train_depth_refinement.py
import torch
import torch.nn as nn

class DepthRefinementNet(nn.Module):
    def __init__(self):
        self.encoder = ResNetEncoder(layers=34)
        self.decoder = UNetDecoder(skip_connections=True)

    def forward(self, rgb, disparity):
        features = self.encoder(torch.cat([rgb, disparity], dim=1))
        refined_depth = self.decoder(features)
        return refined_depth

# 训练
model = DepthRefinementNet()
optimizer = torch.optim.Adam(model.parameters(), lr=1e-4)
# ... 训练循环
torch.onnx.export(model, (rgb, disparity), "depth_refinement.onnx")
```

**推理阶段** (C++/ONNX Runtime):
```cpp
// src/core/ai_depth.cpp
class AIDepthEnhancer {
    Ort::Session session;

public:
    void loadModel(const std::string& onnx_path);
    void infer(const cv::Mat& rgb, const cv::Mat& disparity,
               cv::Mat& enhanced_depth);
};
```

**NPU部署**:
- 量化: FP32 → INT8 (ONNX Quantization / 厂商工具链)
- 优化: 算子融合、内存优化
- 目标延迟: <30ms @ NPU

---

### 6. RGB配准与后处理 (RGB Registration & Post-processing)

**输入**: 增强深度图 (参考左灰度相机) + RGB图
**输出**: 配准深度图 (对齐到RGB相机视角)

**步骤**:

#### 6.1 相机外参标定
```cpp
// 获取RGB相机相对于左灰度相机的旋转和平移
cv::Mat R_rgb_to_left;  // 3x3 旋转矩阵
cv::Mat T_rgb_to_left;  // 3x1 平移向量
```

#### 6.2 坐标变换
```cpp
void registerDepthToRGB(const cv::Mat& depth_left, cv::Mat& depth_rgb,
                        const Eigen::Matrix3f& K_left,
                        const Eigen::Matrix3f& K_rgb,
                        const Eigen::Matrix3f& R,
                        const Eigen::Vector3f& T) {
    for (int v = 0; v < depth_left.rows; ++v) {
        for (int u = 0; u < depth_left.cols; ++u) {
            float d = depth_left.at<float>(v, u);
            if (d <= 0) continue;

            // 反投影到3D (左相机坐标系)
            Eigen::Vector3f P_left = K_left.inverse() * Eigen::Vector3f(u*d, v*d, d);

            // 变换到RGB相机坐标系
            Eigen::Vector3f P_rgb = R * P_left + T;

            // 投影到RGB图像平面
            Eigen::Vector3f p_rgb = K_rgb * P_rgb;
            int u_rgb = p_rgb.x() / p_rgb.z();
            int v_rgb = p_rgb.y() / p_rgb.z();

            // 写入配准深度图
            if (u_rgb >= 0 && u_rgb < depth_rgb.cols &&
                v_rgb >= 0 && v_rgb < depth_rgb.rows) {
                depth_rgb.at<float>(v_rgb, u_rgb) = P_rgb.z();
            }
        }
    }
}
```

#### 6.3 后处理
```cpp
// 深度范围限制
void clipDepth(cv::Mat& depth, float min_depth, float max_depth);

// 单位转换: 视差 → 深度(mm)
float disparityToDepth(float disparity, float baseline, float focal_length) {
    return (baseline * focal_length) / disparity;
}

// 格式转换
void convertDepthFormat(const cv::Mat& depth_f32, cv::Mat& depth_u16, float scale);
```

---

### 7. 输出模块 (Output)

**输出格式**:

| 类型 | 格式 | 说明 |
|------|------|------|
| **深度图** | 16bit PNG / 32bit TIFF | 单位：毫米，0表示无效 |
| **RGB图** | 8bit PNG / JPEG | 彩色图像 |
| **点云** | PLY / PCD | XYZ + RGB, ASCII/Binary |
| **置信度图** | 8bit PNG | 0-255, 可选输出 |

**示例代码**:
```cpp
// src/utils/io.cpp
void saveDepth(const cv::Mat& depth, const std::string& path);
void savePointCloud(const cv::Mat& depth, const cv::Mat& rgb,
                    const Eigen::Matrix3f& K, const std::string& path);
```

---

## 性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| **处理帧率** | ≥30 fps | 实时性要求 |
| **深度精度** | ≤1% @ 1m | 相对误差 |
| **深度范围** | 0.3m - 10m | 有效测量范围 |
| **端到端延迟** | ≤50ms | 采集到输出 |
| **功耗** | ≤5W | 整机功耗 |

**性能分解** (估算):
- 图像采集: ~5ms
- 预处理: ~5ms
- DPU视差计算: ~15ms (硬件加速)
- RGB引导优化: ~10ms
- AI增强: ~20ms (NPU)
- 配准与后处理: ~5ms
- **总计**: ~60ms (需优化到50ms)

---

## 现阶段工作重点：流程梳理与评估

### 1. 算法调研
- [ ] DPU硬件接口文档梳理
- [ ] DPU软件实现方案选型（OpenCV vs 自定义SGM）
- [ ] RGB引导优化算法文献调研
- [ ] AI深度增强网络调研（Depth Completion, Super-Resolution, Refinement）
- [ ] 高斯泼溅可行性评估

### 2. 数据准备
- [ ] 相机标定（内参+外参）
- [ ] 测试场景设计（弱纹理、重复纹理、边缘、动态等）
- [ ] 散斑开/关对比测试数据采集
- [ ] Ground Truth深度数据采集（激光雷达/结构光扫描仪）

### 3. 基线实现
- [ ] 图像采集与预处理模块
- [ ] DPU软件模拟实现（对齐硬件输出）
- [ ] RGB引导滤波（Joint Bilateral / Guided Filter）
- [ ] 基础输出模块（深度图/点云）

### 4. 性能评估
- [ ] DPU硬件 vs 软件精度对比
- [ ] 散斑开/关效果对比
- [ ] RGB引导优化效果评估
- [ ] 端到端延迟测试
- [ ] 内存/功耗profiling

### 5. AI方案选型
- [ ] 训练数据集准备（自采集+公开数据集）
- [ ] 候选网络训练与对比（Completion / Super-Res / Refinement）
- [ ] NPU部署可行性验证（ONNX → NPU工具链）
- [ ] 精度 vs 速度 trade-off 评估

### 6. 文档输出
- [ ] 算法评估报告（精度、性能、复杂度）
- [ ] 方案选型建议
- [ ] 技术路线图（短期/中期/长期）
- [ ] 风险评估与备选方案

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

2. **SLAM集成**:
   - 相机位姿估计
   - 动态场景处理
   - 地图构建

3. **语义分割**:
   - 物体类别信息辅助深度优化
   - 不同类别不同深度优化策略

4. **端到端学习**:
   - 整体pipeline神经网络化
   - 联合优化视差计算和深度细化

5. **ToF融合**:
   - 如果硬件增加ToF传感器
   - 多模态深度融合

---

## 参考文献

### 立体匹配
1. Hirschmuller, H. (2007). Stereo Processing by Semiglobal Matching and Mutual Information. TPAMI.

### 深度补全
2. Ma, F., & Karaman, S. (2018). Sparse-to-Dense: Depth Prediction from Sparse Depth Samples and a Single Image. ICRA.

### 深度超分辨率
3. Kim, B., et al. (2018). Deep Kalman Network: Learning Depth Super-Resolution from RGB-D Data. ECCV.

### RGB引导滤波
4. He, K., et al. (2013). Guided Image Filtering. TPAMI.

### 高斯泼溅
5. Kerbl, B., et al. (2023). 3D Gaussian Splatting for Real-Time Radiance Field Rendering. SIGGRAPH.

### 数据集
6. KITTI Stereo Dataset: http://www.cvlibs.net/datasets/kitti/
7. NYU Depth V2: https://cs.nyu.edu/~silberman/datasets/nyu_depth_v2.html

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

*文档版本: v0.02.001*
*最后更新: 2025-11-12*
*状态: 流程梳理与评估阶段*
