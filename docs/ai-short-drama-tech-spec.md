# AI 短剧技术方案 — 最终版

> 目标：用开源工具复现 Runway Multi-Shot 效果
> 输入：故事梗概 → 输出：多镜头连贯短剧成片
> 硬件：NVIDIA L20 48GB GPU + Mac Mini M4 Pro（开发机）
> 日期：2026-04-08

---

## 一、技术栈总览

```
┌─────────────────────────────────────────────────┐
│               AI 短剧生产流水线                    │
├─────────────────────────────────────────────────┤
│                                                   │
│  1. 剧本分镜    NarratoAI / LLM                   │
│       ↓                                           │
│  2. 角色定妆    Flux + LoRA (ai-toolkit)           │
│       ↓                                           │
│  3. 主镜头      SkyReels-V3 (R2V / V2V)           │
│       ↓                                           │
│  4. 补镜头/B-roll  Wan2.1 (T2V / I2V)             │
│       ↓                                           │
│  5. 对白表演    HunyuanVideo-Avatar               │
│       ↓                                           │
│  6. 局部修补    VACE                              │
│       ↓                                           │
│  7. 配音        CosyVoice 3.0                     │
│       ↓                                           │
│  8. 口型同步    MuseTalk                          │
│       ↓                                           │
│  9. 音效        HunyuanVideo-Foley                │
│       ↓                                           │
│  10. 配乐       ACE-Step                          │
│       ↓                                           │
│  11. 剪辑合成   FFmpeg                            │
│       ↓                                           │
│  12. 工作流引擎  ComfyUI（串联以上所有模型）         │
│                                                   │
└─────────────────────────────────────────────────┘
```

---

## 二、分阶段实施计划

### Phase 1：最小闭环（第 1 周）

目标：跑通「输入故事 → 输出 15 秒短剧 demo」

| 步骤 | 工具 | 版本/模型 | 作用 |
|------|------|----------|------|
| 1.1 | NarratoAI | `linyqh/NarratoAI` | 剧本→分镜脚本 |
| 1.2 | Flux + LoRA | `black-forest-labs/flux2` + `ostris/ai-toolkit` | 角色定妆图生成 + 角色一致性 |
| 1.3 | SkyReels-V3 | `SkyworkAI/SkyReels-V3` 14B-720P R2V | 主镜头视频生成 |
| 1.4 | Wan2.1 | `Wan-Video/Wan2.1` I2V | 补镜头/环境镜头/B-roll |
| 1.5 | CosyVoice | `FunAudioLLM/CosyVoice` | 中文对白配音 |
| 1.6 | MuseTalk | `TMElyralab/MuseTalk` | 口型同步 |
| 1.7 | FFmpeg | 系统安装 | 剪辑合成 |

**Phase 1 交付物**：一个 15-30 秒的短剧 demo（3-5 个镜头，单角色，有对白）

### Phase 2：质量提升（第 2 周）

| 步骤 | 工具 | 作用 |
|------|------|------|
| 2.1 | HunyuanVideo-Avatar `Tencent-Hunyuan/HunyuanVideo-Avatar` | 关键对白特写、双人对手戏、情绪表演 |
| 2.2 | VACE `ali-vilab/VACE` | 局部修补（嘴型/手势/道具），不重生整段 |
| 2.3 | ComfyUI `Comfy-Org/ComfyUI` | 全流程节点编排，替代手动脚本 |

**Phase 2 交付物**：多角色对白短剧（5-8 个镜头，双角色对话场景）

### Phase 3：锦上添花（第 3-4 周）

| 步骤 | 工具 | 作用 |
|------|------|------|
| 3.1 | HunyuanVideo-Foley `Tencent-Hunyuan/HunyuanVideo-Foley` | 视频自动生成环境音效 |
| 3.2 | ACE-Step `ace-step/ACE-Step` | AI 配乐生成 |
| 3.3 | HunyuanCustom `Tencent-Hunyuan/HunyuanCustom` | 角色一致性兜底（漂移时救火） |
| 3.4 | 自动化流水线 | ComfyUI API + Python 脚本一键出片 |

**Phase 3 交付物**：完整短剧成品（含音效+配乐），以及可复用的一键生产脚本

---

## 三、各工具详细规格

### 3.1 角色定妆：Flux + LoRA

```
GitHub:      black-forest-labs/flux2 (★2,097 | Apache-2.0)
训练工具:     ostris/ai-toolkit
模型:        FLUX.2-dev（非商用）或 Flux-schnell（Apache-2.0）
参数量:      12B
显存需求:     ~24GB（推理）/ ~32GB（LoRA 训练）

LoRA 训练流程:
  输入: 20-30 张角色图片（不同角度/表情/光线）
  打标: WD14 tagger 自动生成描述
  训练: ai-toolkit，约 1500-3000 步
  输出: ~150MB .safetensors 文件
  耗时: L20 约 30-60 分钟/角色

推理:
  ComfyUI 加载 Flux + 角色 LoRA
  输入分镜描述 → 输出角色一致图片
  显存 ~24GB，约 10-15 秒/张
```

### 3.2 主镜头：SkyReels-V3

```
GitHub:      SkyworkAI/SkyReels-V3 (★403 | skywork-license)
模型线:
  - SkyReels-V3-R2V-14B-720P: 参考图→视频（主力）
  - SkyReels-V3-V2V-14B-720P: 视频→视频（编辑/风格转换）
  - SkyReels-V3-TalkingAvatar-19B-720P: 说话头像
参数量:      14B / 19B
显存需求:     ~32-40GB（14B 720P）/ ~45GB+（19B）
L20 跑 14B:  ✅ 可以，~3-5 分钟/片段
L20 跑 19B:  ⚠️ 勉强，需低分辨率或量化

核心能力:
  ✅ 多主体参考图生成（多个角色同框保持一致）
  ✅ 音频引导视频生成（配音驱动嘴型）
  ✅ Video-to-Video（已有视频二次编辑）
  ✅ 短剧专用设计

ComfyUI 集成: 需要自定义节点或 API 调用
```

### 3.3 辅助镜头：Wan2.1

```
GitHub:      Wan-Video/Wan2.1 (★15,760 | Apache-2.0)
或 Wan2.2:   Wan-Video/Wan2.2 (★15,121 | Apache-2.0)
参数量:      14B
显存需求:     ~32GB（720P）
L20 跑:      ✅ 可以，~2-3 分钟/片段

负责镜头类型:
  - 外景空镜（城市天际线、日出日落）
  - 转场镜头（推门、走路、车窗外）
  - 梦境/回忆片段
  - 标题片头
  - 不需要精确角色一致的环境镜头

为什么不用它做主力:
  通用模型，角色一致性不如 SkyReels-V3
  但通用能力强，适合非核心表演镜头
```

### 3.4 对白表演：HunyuanVideo-Avatar

```
GitHub:      Tencent-Hunyuan/HunyuanVideo-Avatar (★2,075 | Tencent Hunyuan License)
参数量:      ~13B
显存需求:     ~28GB
L20 跑:      ✅ 可以，~3-5 分钟/片段

核心能力:
  ✅ 高动态角色动画（不只是微表情）
  ✅ 音频驱动，情绪与对白精确对齐
  ✅ 多角色音频驱动动画
  ✅ 支持 portrait / upper-body / full-body 三种尺度

使用策略:
  SkyReels 负责"把戏搭起来"（全景/中景）
  HunyuanVideo-Avatar 负责"把人演出来"（特写/对白/情绪戏）
```

### 3.5 局部修补：VACE

```
GitHub:      ali-vilab/VACE (★3,722 | Apache-2.0)
论文:        ICCV 2025
显存需求:     ~32GB
L20 跑:      ✅ 可以

核心能力:
  ✅ reference-to-video: 参考图引导生成
  ✅ video-to-video: 视频风格转换
  ✅ masked video-to-video: 只修指定区域

短剧场景:
  嘴型不对 → mask 嘴部区域 → 只重生嘴
  手势错了 → mask 手部区域 → 只重生手
  道具位置偏 → mask 道具 → 只修道具
  构图边缘 → mask 边缘 → 扩展画面

  不用整段重生，节省 80% 返工算力
```

### 3.6 配音：CosyVoice 3.0

```
GitHub:      FunAudioLLM/CosyVoice (★20,445 | Apache-2.0)
参数量:      ~2B
显存需求:     ~8GB
L20 跑:      ✅ 非常轻松，可常驻后台

核心能力:
  ✅ 高质量中文 TTS（自然度极佳）
  ✅ 语音克隆（需要 3-10 秒参考音频）
  ✅ 情绪控制（通过指令控制语气）
  ✅ 流式输出（实时生成）
  ✅ 中文方言支持

使用方式:
  每个角色录 10 秒参考音频
  合成对白时指定角色音色
  支持语速/停顿/情绪指令
```

### 3.7 口型同步：MuseTalk

```
GitHub:      TMElyralab/MuseTalk (★5,557)
显存需求:     ~8GB
L20 跑:      ✅ 轻松

核心能力:
  ✅ 实时高质量唇形同步
  ✅ 输入：一段人脸视频 + 一段音频
  ✅ 输出：嘴型与音频对齐的视频
  ✅ 基于 Latent Space Inpainting，效果自然

使用场景:
  CosyVoice 生成对白音频
  MuseTalk 把音频对齐到角色视频的嘴型上
```

### 3.8 音效：HunyuanVideo-Foley

```
GitHub:      Tencent-Hunyuan/HunyuanVideo-Foley (★1,270)
显存需求:     ~16GB
L20 跑:      ✅ 可以

核心能力:
  ✅ 端到端 video-to-audio
  ✅ text + video → audio（文字引导音效生成）
  ✅ 48kHz Hi-Fi 输出
  ✅ 多场景适配

使用场景:
  输入一段视频片段 → 自动生成匹配的环境音效
  "脚步声、关门声、雨声、玻璃杯碰撞声..."
```

### 3.9 配乐：ACE-Step

```
GitHub:      ace-step/ACE-Step (★4,279 | Apache-2.0)
参数量:      ~3B
显存需求:     ~10GB
L20 跑:      ✅ 轻松

核心能力:
  ✅ 开源音乐基础模型
  ✅ 可控生成（指定风格/情绪/节奏）
  ✅ 支持中文提示词

使用场景:
  "生成一段30秒的悲伤钢琴曲，适合雨天场景"
  "生成一段紧张的弦乐，适合追逐场景"
```

### 3.10 工作流引擎：ComfyUI

```
GitHub:      Comfy-Org/ComfyUI (★108,082 | GPL-3.0)
作用:        串联以上所有模型的节点式工作流平台

使用策略:
  Phase 1-2: 手动 ComfyUI 工作流，调试参数
  Phase 3: 稳定后导出为 API，Python 脚本自动化调用

ComfyUI 需要安装的节点/插件:
  - ComfyUI-WanVideoWrapper (Wan2.1/2.2)
  - ComfyUI-SkyReels (SkyReels-V3，需确认是否有社区节点)
  - ComfyUI-HunyuanVideo (HunyuanVideo 系列)
  - ComfyUI-VACE
  - ComfyUI-Flux (Flux 模型)
  - ComfyUI-IPAdapter (角色一致性辅助)
```

---

## 四、数据流架构

```
                        ┌─────────────┐
                        │   故事梗概    │
                        │  (自然语言)   │
                        └──────┬──────┘
                               ↓
                   ┌──── NarratoAI ────┐
                   │ 分镜脚本 JSON 输出: │
                   │ {                  │
                   │   scenes: [        │
                   │     {              │
                   │       id: 1,       │
                   │       type: "主镜头",│
                   │       shot: "中景",  │
                   │       desc: "...",  │
                   │       characters:   │
                   │         ["角色A"],  │
                   │       dialogue:     │
                   │         "台词...",  │
                   │       camera:       │
                   │         "推近",     │
                   │       mood: "紧张"  │
                   │     },              │
                   │     ...             │
                   │   ]                 │
                   │ }                   │
                   └────────┬────────────┘
                            ↓
              ┌─────────────┴─────────────┐
              ↓                           ↓
    ┌── 角色定妆 ──┐            ┌── 场景参考 ──┐
    │ Flux + LoRA  │            │ Flux / SDXL  │
    │ 每角色出      │            │ 每场景出      │
    │ 定妆图 x5    │            │ 参考图 x3    │
    └──────┬───────┘            └──────┬───────┘
           ↓                           ↓
    ┌──────────────────────────────────────┐
    │            镜头路由决策               │
    │                                      │
    │  type=="主镜头" + 有角色 → SkyReels-V3│
    │  type=="对白特写"        → H-Avatar  │
    │  type=="空镜/环境"       → Wan2.1    │
    │  type=="需修补"          → VACE      │
    └──────────────┬───────────────────────┘
                   ↓
           ┌── 视频片段 x N ──┐
           │  (每个 3-5 秒)    │
           └──────┬────────────┘
                  ↓
    ┌─────────────┴─────────────┐
    ↓                           ↓
┌── 配音 ──┐           ┌── 音效/配乐 ──┐
│CosyVoice │           │Foley + ACE-Step│
│对白音频   │           │环境音 + BGM    │
└────┬─────┘           └──────┬────────┘
     ↓                        ↓
┌── 口型同步 ──┐              │
│ MuseTalk    │              │
│ 音频→嘴型   │              │
└────┬────────┘              │
     ↓                       ↓
    ┌────────────────────────┴┐
    │       FFmpeg 合成         │
    │  1. 视频片段拼接           │
    │  2. 对白音频叠加           │
    │  3. 环境音效混合           │
    │  4. BGM 混入（音量 -20dB） │
    │  5. ASS/SRT 字幕烧录      │
    │  6. 输出最终成片           │
    └──────────┬───────────────┘
               ↓
         🎬 短剧成片 MP4
```

---

## 五、分镜脚本数据格式

```json
{
  "title": "霸道总裁第1集 - 雨中重逢",
  "characters": [
    {
      "id": "ceo",
      "name": "陆景深",
      "lora": "models/lora/lu_jingshen.safetensors",
      "voice_ref": "audio/ref/lu_jingshen_ref.wav",
      "appearance": "30岁男性，短发，黑色西装，冷峻表情"
    },
    {
      "id": "girl",
      "name": "苏念",
      "lora": "models/lora/su_nian.safetensors",
      "voice_ref": "audio/ref/su_nian_ref.wav",
      "appearance": "25岁女性，长发，白色连衣裙，温柔表情"
    }
  ],
  "scenes": [
    {
      "id": 1,
      "type": "environment",
      "engine": "wan2.1",
      "prompt": "城市雨夜，高楼大厦，霓虹灯倒映在湿漉漉的街道上",
      "camera": "缓慢上升全景",
      "duration": 3,
      "audio": "雨声，远处雷声",
      "dialogue": null
    },
    {
      "id": 2,
      "type": "principal",
      "engine": "skyreels-v3",
      "characters": ["ceo"],
      "reference_images": ["refs/ceo_rain_01.png"],
      "prompt": "男人穿黑色西装站在高楼门口，撑着黑伞，表情焦急地看向远方，雨水从伞边滴落",
      "camera": "中景→推近面部",
      "duration": 4,
      "audio": "雨声",
      "dialogue": null
    },
    {
      "id": 3,
      "type": "principal",
      "engine": "skyreels-v3",
      "characters": ["girl"],
      "reference_images": ["refs/girl_umbrella_01.png"],
      "prompt": "女人撑着红色雨伞从街角走来，白色连衣裙在雨中飘动",
      "camera": "远景→中景",
      "duration": 3,
      "audio": "脚步声，雨声",
      "dialogue": null
    },
    {
      "id": 4,
      "type": "dialogue",
      "engine": "hunyuan-avatar",
      "characters": ["ceo", "girl"],
      "reference_images": ["refs/ceo_girl_face_01.png"],
      "prompt": "两人在雨中对视，男人缓缓放下雨伞",
      "camera": "双人中景",
      "duration": 5,
      "dialogue": {
        "ceo": "你...还愿意回来吗？",
        "girl": "我不是回来找你的。"
      }
    },
    {
      "id": 5,
      "type": "dialogue_closeup",
      "engine": "hunyuan-avatar",
      "characters": ["ceo"],
      "reference_images": ["refs/ceo_closeup_01.png"],
      "prompt": "男人面部特写，雨水和泪水交织",
      "camera": "特写",
      "duration": 3,
      "dialogue": {
        "ceo": "那我...可以去找你吗？"
      }
    }
  ],
  "bgm": {
    "style": "悲伤钢琴，缓慢节奏",
    "duration": 18,
    "volume_db": -20
  }
}
```

---

## 六、环境部署清单

### 6.1 GPU 服务器（L20 48G）

```bash
# 系统: Ubuntu 22.04 LTS
# GPU: NVIDIA L20 48GB
# 驱动: NVIDIA Driver >= 535
# CUDA: 12.1+

# 1. 基础环境
sudo apt update && sudo apt install -y \
  python3.11 python3.11-venv python3-pip \
  git wget curl ffmpeg \
  nvidia-cuda-toolkit

# 2. 创建项目目录
mkdir -p ~/ai-drama/{models,outputs,data,scripts}
cd ~/ai-drama

# 3. Python 虚拟环境
python3.11 -m venv venv
source venv/bin/activate

# 4. PyTorch (CUDA 12.1)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# 5. ComfyUI
git clone https://github.com/Comfy-Org/ComfyUI.git
cd ComfyUI
pip install -r requirements.txt
# 启动: python main.py --listen 0.0.0.0 --port 8188

# 6. 各模型仓库 (按需 clone)
cd ~/ai-drama

# SkyReels-V3
git clone https://github.com/SkyworkAI/SkyReels-V3.git

# Wan2.1
git clone https://github.com/Wan-Video/Wan2.1.git

# HunyuanVideo-Avatar
git clone https://github.com/Tencent-Hunyuan/HunyuanVideo-Avatar.git

# VACE
git clone https://github.com/ali-vilab/VACE.git

# CosyVoice
git clone https://github.com/FunAudioLLM/CosyVoice.git

# MuseTalk
git clone https://github.com/TMElyralab/MuseTalk.git

# HunyuanVideo-Foley
git clone https://github.com/Tencent-Hunyuan/HunyuanVideo-Foley.git

# ACE-Step
git clone https://github.com/ace-step/ACE-Step.git

# ai-toolkit (LoRA 训练)
git clone https://github.com/ostris/ai-toolkit.git

# NarratoAI
git clone https://github.com/linyqh/NarratoAI.git
```

### 6.2 模型权重下载

```
HuggingFace 需要下载的模型（按优先级排序）:

Phase 1 必须下载:
  1. FLUX.2-dev 或 flux1-dev        (~24GB) → 角色图片生成
  2. SkyReels-V3-R2V-14B-720P       (~28GB) → 主镜头视频
  3. Wan2.1-I2V-14B-720P            (~28GB) → 辅助镜头
  4. CosyVoice-300M-Instruct        (~1GB)  → 配音
  5. MuseTalk 模型                   (~2GB)  → 口型同步

Phase 2 下载:
  6. HunyuanVideo-Avatar             (~26GB) → 对白表演
  7. VACE 模型                       (~28GB) → 局部修补

Phase 3 下载:
  8. HunyuanVideo-Foley              (~8GB)  → 音效
  9. ACE-Step                        (~6GB)  → 配乐
  10. HunyuanCustom                  (~26GB) → 一致性兜底

预估总磁盘: ~180GB（含所有阶段）
Phase 1 磁盘: ~85GB
```

### 6.3 显存分配策略

```
L20 48GB 显存，不能同时加载两个大模型。

运行策略:
  大模型按需加载，用完释放:
  1. 加载 Flux (~24GB) → 生成所有角色图 → 释放
  2. 加载 SkyReels-V3 (~32GB) → 生成所有主镜头 → 释放
  3. 加载 Wan2.1 (~32GB) → 生成所有 B-roll → 释放
  4. 加载 HunyuanVideo-Avatar (~28GB) → 生成对白镜头 → 释放
  5. CosyVoice (~8GB) + MuseTalk (~8GB) 可同时常驻

  小模型可以常驻: CosyVoice + MuseTalk 共 ~16GB
  大模型串行: 每次 28-36GB，48GB 绰绰有余
```

---

## 七、自动化脚本架构

```
~/ai-drama/
├── models/                    # 模型权重
│   ├── flux/
│   ├── skyreels-v3/
│   ├── wan2.1/
│   ├── lora/                  # 角色 LoRA 文件
│   └── cosyvoice/
├── data/                      # 输入数据
│   ├── scripts/               # 分镜脚本 JSON
│   ├── characters/            # 角色参考图
│   └── voice_refs/            # 角色语音参考
├── outputs/                   # 输出
│   ├── images/                # Flux 生成的角色图
│   ├── videos/                # 各模型生成的视频片段
│   ├── audio/                 # 配音/音效/配乐
│   └── final/                 # 最终成片
├── scripts/                   # 自动化脚本
│   ├── 01_train_lora.py       # LoRA 训练
│   ├── 02_generate_images.py  # 角色图生成
│   ├── 03_generate_videos.py  # 视频片段生成
│   ├── 04_generate_audio.py   # 配音+音效+配乐
│   ├── 05_lip_sync.py         # 口型同步
│   ├── 06_compose.py          # FFmpeg 最终合成
│   └── pipeline.py            # 一键全流程
├── comfyui/                   # ComfyUI 安装
│   └── workflows/             # 导出的工作流 JSON
└── venv/                      # Python 虚拟环境
```

### 一键流水线入口 (scripts/pipeline.py)

```python
"""
AI 短剧一键生产流水线
输入: 分镜脚本 JSON
输出: 最终成片 MP4
"""

def main(script_path: str):
    # Step 1: 解析分镜脚本
    script = load_script(script_path)

    # Step 2: 生成角色定妆图（Flux + LoRA）
    for char in script["characters"]:
        generate_character_images(char)

    # Step 3: 按镜头路由到不同模型生成视频
    for scene in script["scenes"]:
        if scene["engine"] == "skyreels-v3":
            generate_skyreels(scene)
        elif scene["engine"] == "wan2.1":
            generate_wan(scene)
        elif scene["engine"] == "hunyuan-avatar":
            generate_avatar(scene)

    # Step 4: 生成配音（CosyVoice）
    for scene in script["scenes"]:
        if scene.get("dialogue"):
            generate_dialogue_audio(scene)

    # Step 5: 口型同步（MuseTalk）
    for scene in script["scenes"]:
        if scene.get("dialogue"):
            lip_sync(scene)

    # Step 6: 音效 + 配乐
    generate_foley(script)
    generate_bgm(script)

    # Step 7: FFmpeg 合成
    compose_final(script)

    print(f"✅ 成片输出: outputs/final/{script['title']}.mp4")
```

---

## 八、Demo 目标

**第一个 demo：「霸道总裁 - 雨中重逢」**

- 时长：15-20 秒
- 镜头：5 个
- 角色：2 个（总裁 + 女主）
- 有对白、有配乐
- 对标 Runway Multi-Shot 效果

成功标准：**发给朋友看，对方说"这是 AI 做的？"**

---

## 九、风险与注意事项

1. **SkyReels-V3 社区小（403 Stars）**：可能缺少 ComfyUI 插件，需要自己写节点或用 API 调用
2. **模型切换开销**：48G 每次只跑一个大模型，切换需要卸载/加载，单条短剧完整生成预计 30-60 分钟
3. **许可证**：多个模型非商用许可，商业化前需法务审查
4. **EchoShot 值得跟踪**：虽然现在只有 50 Stars / 1.3B 参数，但方向完全对口，等它 14B 版本可能成为主力
5. **Wan2.2 已发布**：替代 Wan2.1，支持音频驱动视频（S2V）和无限长视频生成，Phase 1 可直接用 Wan2.2
