# Depth - 深度相机算法项目

## 项目简介

Depth 是一个融合双目立体视觉、结构光和RGB相机的高精度深度感知系统。通过多模态深度计算和融合算法，提供高质量的深度图像输出。

## 硬件规格

### 相机配置
- **双目灰度相机**: 1280x800 @ 30fps, FOV 60°
  - 基线距离: 10cm
  - 用于立体匹配计算视差

- **结构光投射器**: 近红外激光斑点
  - 斑点数量: 20,000个
  - 用于弱纹理区域深度计算

- **RGB彩色相机**: 1280x800 @ 30fps, FOV 60°
  - 用于彩色图像采集和RGB配准

### 计算单元
- **DPU**: 专用视差计算硬件加速器
- **NPU**: 2.5 TOPS @ INT8, AI推理加速

## 系统架构

详细的处理流程请参考 [depth-rgb-flow.md](depth-rgb-flow.md)

```
图像采集 → 预处理 → 双目匹配(DPU) ┐
                                  ├→ 深度融合 → 优化 → AI增强(NPU) → RGB配准 → 输出
结构光深度计算 ─────────────────────┘
```

## 目录结构

```
depth/
├── README.md                 # 本文件
├── depth-rgb-flow.md         # 详细处理流程
├── CMakeLists.txt           # CMake构建配置
├── .gitignore               # Git忽略文件
├── VERSION                  # 版本号文件
│
├── src/                     # C++源代码
│   ├── core/                # 核心算法实现
│   │   ├── stereo.cpp       # 双目立体匹配
│   │   ├── structured_light.cpp  # 结构光处理
│   │   ├── fusion.cpp       # 深度融合
│   │   └── ai_depth.cpp     # AI深度增强
│   ├── hardware/            # 硬件接口
│   │   ├── camera.cpp       # 相机驱动
│   │   ├── dpu.cpp          # DPU接口
│   │   └── npu.cpp          # NPU接口
│   ├── preprocessing/       # 图像预处理
│   ├── postprocessing/      # 后处理
│   └── utils/               # 工具函数
│
├── include/                 # C++头文件
│   └── depth/
│       ├── core/
│       ├── hardware/
│       └── utils/
│
├── python/                  # Python开发代码
│   ├── models/              # 深度学习模型
│   │   ├── depth_completion.py
│   │   └── depth_refinement.py
│   ├── training/            # 训练脚本
│   │   ├── train.py
│   │   └── dataset.py
│   ├── evaluation/          # 评估脚本
│   └── export/              # 模型导出到ONNX
│
├── config/                  # 配置文件
│   ├── camera_calib.yaml    # 相机标定参数
│   └── depth_config.yaml    # 深度计算配置
│
├── tests/                   # 测试代码
│   ├── unit/                # 单元测试
│   └── integration/         # 集成测试
│
├── scripts/                 # 脚本工具
│   ├── calibration.py       # 相机标定
│   ├── version_bump.sh      # 版本号管理
│   └── build.sh             # 构建脚本
│
├── third_party/             # 第三方库
│   └── (submodules)
│
├── data/                    # 数据目录(不提交到git)
│   ├── raw/                 # 原始图像
│   ├── calibration/         # 标定数据
│   └── models/              # 训练好的模型
│
├── build/                   # 编译输出(不提交到git)
│
└── docs/                    # 文档
    ├── api/                 # API文档
    └── tutorials/           # 教程
```

## 快速开始

### 环境要求

**开发环境**:
- Python 3.8+
- PyTorch 1.10+
- OpenCV 4.5+
- CMake 3.16+
- C++14/17编译器

**嵌入式部署**:
- ONNX Runtime
- NPU工具链 (厂商提供)
- DPU驱动

### 构建项目

```bash
# 创建构建目录
mkdir build && cd build

# 配置CMake
cmake ..

# 编译
make -j$(nproc)

# 运行测试
ctest
```

### Python开发

```bash
# 安装依赖
pip install -r python/requirements.txt

# 训练深度补全模型
python python/training/train.py --config config/depth_config.yaml

# 导出为ONNX
python python/export/export_onnx.py --model checkpoints/best.pth --output models/depth.onnx
```

## 性能指标

| 指标 | 目标值 | 当前值 |
|------|--------|--------|
| 处理帧率 | ≥30 fps | TBD |
| 深度精度 | ≤1% @ 1m | TBD |
| 深度范围 | 0.3m - 10m | TBD |
| 延迟 | ≤50ms | TBD |
| 功耗 | ≤5W | TBD |

## 版本管理

版本号格式: **vX.YY.ZZZ**

- **X**: 大版本号 (架构重大变更)
- **YY**: 次版本号 (新功能添加)
- **ZZZ**: 小版本号 (Bug修复, 小改进)

当前版本: **v0.01.001**

### Git工作流
- 每次重要操作前提交代码
- 保持每一步可回退
- 清晰的提交信息

## 开发规范

### 代码风格
- C++: Google C++ Style Guide
- Python: PEP 8

### 提交信息
```
<type>(<scope>): <subject>

<body>

<footer>
```

类型:
- feat: 新功能
- fix: Bug修复
- docs: 文档
- refactor: 重构
- test: 测试
- chore: 构建/工具

## 技术栈

### 核心库
- **OpenCV**: 图像处理
- **Eigen**: 矩阵运算
- **PCL**: 点云处理
- **ONNX Runtime**: 模型推理

### 深度学习
- **PyTorch**: 模型训练
- **ONNX**: 模型部署

### 构建工具
- **CMake**: 跨平台构建
- **Git**: 版本控制

## 路线图

### v0.x - 基础框架
- [x] 项目架构设计
- [ ] 图像采集模块
- [ ] 双目立体匹配(DPU)
- [ ] 结构光深度计算
- [ ] 深度融合算法

### v1.x - 功能完善
- [ ] AI深度增强(NPU)
- [ ] RGB配准
- [ ] 实时优化
- [ ] 相机标定工具

### v2.x - 高级特性
- [ ] 多帧融合
- [ ] SLAM集成
- [ ] 语义深度融合

## 贡献

欢迎提交Issue和Pull Request!

## 许可证

[待定]

## 联系方式

- 项目: depth
- 组织: octas
