# AI Coding Agent 提示词 — AI 短剧生产系统

> 以下是分阶段的提示词，按顺序逐个交给你的 coding agent 执行。

---

## Phase 1 提示词：环境搭建 + 最小闭环

### Prompt 1: 基础环境 + ComfyUI

```
你是一个 AI 视频工程专家。请帮我搭建一套 AI 短剧生产系统的基础环境。

## 硬件
- GPU: NVIDIA L20 48GB
- 系统: Ubuntu 22.04 LTS
- CUDA: 12.1+

## 任务

1. 创建项目目录结构：
~/ai-drama/
├── models/          # 模型权重（子目录：flux/ skyreels/ wan/ lora/ cosyvoice/ musetalk/）
├── data/
│   ├── scripts/     # 分镜脚本 JSON
│   ├── characters/  # 角色参考图
│   └── voice_refs/  # 语音参考
├── outputs/
│   ├── images/      # Flux 生成的角色图
│   ├── videos/      # 各模型生成的视频片段
│   ├── audio/       # 配音/音效/配乐
│   └── final/       # 最终成片
├── scripts/         # 自动化 Python 脚本
├── comfyui/         # ComfyUI 安装
└── venv/            # Python 虚拟环境

2. 写一个 setup.sh 脚本，自动完成：
   - 安装 Python 3.11 + venv
   - 安装 PyTorch (CUDA 12.1)
   - clone ComfyUI 到 comfyui/
   - clone 以下仓库到各自目录：
     * SkyReels-V3: https://github.com/SkyworkAI/SkyReels-V3.git
     * Wan2.1: https://github.com/Wan-Video/Wan2.1.git
     * HunyuanVideo-Avatar: https://github.com/Tencent-Hunyuan/HunyuanVideo-Avatar.git
     * VACE: https://github.com/ali-vilab/VACE.git
     * CosyVoice: https://github.com/FunAudioLLM/CosyVoice.git
     * MuseTalk: https://github.com/TMElyralab/MuseTalk.git
     * ai-toolkit (LoRA 训练): https://github.com/ostris/ai-toolkit.git
     * NarratoAI: https://github.com/linyqh/NarratoAI.git
     * HunyuanVideo-Foley: https://github.com/Tencent-Hunyuan/HunyuanVideo-Foley.git
     * ACE-Step: https://github.com/ace-step/ACE-Step.git
     * HunyuanCustom: https://github.com/Tencent-Hunyuan/HunyuanCustom.git
   - 为每个仓库安装 requirements.txt
   - 安装 FFmpeg
   - 创建 venv 并激活

3. 写一个 download_models.sh 脚本（Phase 1 模型）：
   - 用 huggingface-cli 或 wget 下载：
     * FLUX.2-dev 模型权重到 models/flux/
     * SkyReels-V3-R2V-14B-720P 到 models/skyreels/
     * Wan2.1-I2V-14B-720P 到 models/wan/
     * CosyVoice 模型到 models/cosyvoice/
     * MuseTalk 模型到 models/musetalk/
   - 每个下载显示进度条和预估大小
   - 支持断点续传

4. 写一个 check_env.py 脚本：
   - 检测 CUDA 版本、GPU 显存、驱动版本
   - 检测所有模型文件是否存在且完整
   - 检测所有 Python 依赖是否安装
   - 输出一份环境状态报告

请确保脚本都有错误处理，失败时给出清晰的错误信息。
```

### Prompt 2: LoRA 训练脚本

```
请帮我写一个 LoRA 训练脚本 scripts/01_train_lora.py。

## 需求
- 基于 ostris/ai-toolkit 的 FLUX LoRA 训练流程
- 输入：一个角色目录（包含 20-30 张图片）
- 输出：一个 .safetensors LoRA 文件到 models/lora/

## 流程
1. 读取 data/characters/{角色名}/ 目录下的所有图片
2. 用 WD14 tagger 自动打标，生成 .txt 描述文件
3. 生成 ai-toolkit 所需的 YAML 配置文件：
   - 底模：models/flux/flux1-dev.safetensors
   - LoRA rank: 16-32
   - 训练步数：1500-3000
   - 学习率：1e-4
   - 分辨率：1024x1024
   - 每角色一个 trigger word，格式：{角色名}_character
4. 调用 ai-toolkit 进行训练
5. 训练完成后复制 .safetensors 到 models/lora/{角色名}.safetensors
6. 打印训练结果摘要

## 命令行参数
python scripts/01_train_lora.py \
  --character ceo \
  --images-dir data/characters/ceo/ \
  --steps 2000 \
  --rank 16

## 注意
- 需要先确认 ai-toolkit 的具体 API / CLI 调用方式，参考其 README
- 显存 ~32GB，注意 gradient checkpointing
- 训练完成后自动做一张测试图验证效果
```

### Prompt 3: 角色定妆图生成

```
请帮我写 scripts/02_generate_images.py，用 Flux + LoRA 生成角色定妆图。

## 需求
- 输入：分镜脚本 JSON（data/scripts/{剧本名}.json）
- 输出：每个角色的多角度定妆图到 outputs/images/

## 流程
1. 读取分镜脚本，提取所有角色和场景
2. 对每个角色，用 Flux + 角色 LoRA 生成以下定妆图：
   - 正面半身照
   - 侧面半身照
   - 全身照
   - 3 个不同表情（微笑/严肃/悲伤）
   - 2 个不同场景（办公室/街道，根据角色设定）
3. 对每个分镜场景，生成一张场景参考图（不含角色）

## 技术实现
- 通过 ComfyUI API 调用 Flux（POST http://localhost:8181/prompt）
- 或直接用 diffusers pipeline 加载 Flux + LoRA
- 每张图 1024x1024，seed 固定以便复现

## 命令行参数
python scripts/02_generate_images.py \
  --script data/scripts/demo_ep1.json \
  --output-dir outputs/images/ \
  --comfyui-url http://localhost:8181

## 分镜脚本格式参考
{
  "title": "霸道总裁第1集",
  "characters": [
    {
      "id": "ceo",
      "name": "陆景深",
      "lora": "models/lora/lu_jingshen.safetensors",
      "trigger_word": "lu_jingshen_character",
      "appearance": "30岁男性，短发，黑色西装，冷峻表情"
    }
  ],
  "scenes": [...]
}
```

### Prompt 4: 视频生成（核心）

```
请帮我写 scripts/03_generate_videos.py，根据分镜脚本自动路由到不同模型生成视频。

## 核心逻辑：镜头路由

读取分镜脚本的 scenes 数组，根据每个镜头的 type 和 engine 字段路由：

1. engine == "wan2.1" → 调用 Wan2.1 I2V
   - 环境镜头、空镜、转场
   - 输入：prompt 文字描述
   - 输出：3-5 秒视频，720P

2. engine == "skyreels-v3" → 调用 SkyReels-V3 R2V
   - 有角色的主镜头
   - 输入：角色参考图 + prompt
   - 输出：3-5 秒视频，720P
   - 角色 LoRA 参考图从 outputs/images/ 加载

3. engine == "hunyuan-avatar" → 调用 HunyuanVideo-Avatar
   - 对白特写、情绪戏
   - 输入：角色参考图 + 对白音频（如有）
   - 输出：3-5 秒视频

## 显存管理（关键！）
L20 只有 48GB，不能同时加载两个大模型。

实现一个 ModelManager 类：
- load_model(model_name) → 加载模型到 GPU
- unload_model() → 释放 GPU 显存
- 按引擎类型分批处理所有镜头：
  第一批：所有 wan2.1 镜头 → 加载 Wan2.1 → 生成完 → 释放
  第二批：所有 skyreels-v3 镜头 → 加载 SkyReels → 生成完 → 释放
  第三批：所有 hunyuan-avatar 镜头 → 加载 Avatar → 生成完 → 释放

每个模型加载前打印当前 GPU 显存使用情况。

## 输出
- outputs/videos/scene_001.mp4
- outputs/videos/scene_002.mp4
- ...
- 同时生成一个 outputs/videos/manifest.json 记录每个视频的时长、分辨率、对应分镜

## 命令行参数
python scripts/03_generate_videos.py \
  --script data/scripts/demo_ep1.json \
  --images-dir outputs/images/ \
  --output-dir outputs/videos/ \
  --resolution 720p \
  --duration 4

## 注意
- 优先用各仓库官方推荐的推理方式（参考各仓库 README 的 inference 章节）
- 如果官方没有现成的高层 API，可以直接 import 其源码
- Wan2.1 推理参考：https://github.com/Wan-Video/Wan2.1 的 Usage 部分
- SkyReels-V3 推理参考：https://github.com/SkyworkAI/SkyReels-V3 的 Inference 部分
- 每个视频生成后验证文件是否可播放（用 cv2 读前几帧）
```

### Prompt 5: 配音 + 口型同步

```
请帮我写两个脚本：

### scripts/04_generate_audio.py

用 CosyVoice 为每个有对白的镜头生成配音。

## 流程
1. 读取分镜脚本，提取所有有 dialogue 的镜头
2. 对每句台词，加载对应角色的 voice_ref 音频
3. 调用 CosyVoice 生成配音
4. 输出：outputs/audio/scene_004_ceo.wav, outputs/audio/scene_004_girl.wav

## CosyVoice 调用方式
参考 https://github.com/FunAudioLLM/CosyVoice 的推理部分。
支持：指定参考音频 + 参考文本 + 目标文本 → 输出语音。

## 命令行参数
python scripts/04_generate_audio.py \
  --script data/scripts/demo_ep1.json \
  --voice-refs data/voice_refs/ \
  --output-dir outputs/audio/

### scripts/05_lip_sync.py

用 MuseTalk 做口型同步。

## 流程
1. 读取 outputs/videos/ 和 outputs/audio/ 目录
2. 对每个有对白的镜头视频，找到对应的配音音频
3. 调用 MuseTalk 将音频与视频的嘴型对齐
4. 输出覆盖原视频文件（或输出到 outputs/videos/scene_004_synced.mp4）

## MuseTalk 调用方式
参考 https://github.com/TMElyralab/MuseTalk 的推理部分。

## 命令行参数
python scripts/05_lip_sync.py \
  --videos-dir outputs/videos/ \
  --audio-dir outputs/audio/ \
  --output-dir outputs/videos/
```

### Prompt 6: 最终合成

```
请帮我写 scripts/06_compose.py，用 FFmpeg 将所有素材合成为最终成片。

## 流程
1. 读取 outputs/videos/manifest.json，获取视频片段顺序和时长
2. 拼接所有视频片段（按 scene id 排序）
3. 叠加对白音频（每个镜头的 .wav 文件对齐到对应时间段）
4. 如果有 BGM 文件，混入（音量 -20dB）
5. 烧录字幕（从分镜脚本的 dialogue 字段生成 SRT）
6. 输出最终 MP4

## FFmpeg 命令参考
# 拼接
ffmpeg -f concat -safe 0 -i filelist.txt -c copy temp_video.mp4

# 叠加音频
ffmpeg -i temp_video.mp4 -i dialogue.wav -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 temp_with_audio.mp4

# 混入 BGM（降低音量）
ffmpeg -i temp_with_audio.mp4 -i bgm.mp3 -filter_complex "[1:a]volume=-20dB[bg];[0:a][bg]amix=inputs=2:duration=first[a]" -map 0:v -map "[a]" temp_with_bgm.mp4

# 烧录字幕
ffmpeg -i temp_with_bgm.mp4 -vf subtitles=subtitles.srt -c:a copy final_output.mp4

## 命令行参数
python scripts/06_compose.py \
  --script data/scripts/demo_ep1.json \
  --videos-dir outputs/videos/ \
  --audio-dir outputs/audio/ \
  --bgm outputs/audio/bgm.mp3 \
  --output outputs/final/demo_ep1_final.mp4 \
  --subtitle-font-size 24

## 输出
- outputs/final/{title}.mp4
- 自动生成同名字幕文件 .srt
```

### Prompt 7: 一键流水线

```
请帮我写 scripts/pipeline.py，串联以上所有步骤的一键脚本。

## 功能
按顺序执行：
1. 解析分镜脚本 JSON
2. 检查环境（模型是否存在、GPU 是否可用）
3. 检查角色 LoRA 是否已训练，如果没有则提示先运行 01_train_lora.py
4. 调用 02_generate_images.py 生成角色图
5. 调用 03_generate_videos.py 生成视频片段
6. 调用 04_generate_audio.py 生成配音
7. 调用 05_lip_sync.py 做口型同步
8. 调用 06_compose.py 合成最终成片
9. 打印完整耗时和各步骤耗时明细

## 特性
- 支持 --from-step 参数，从指定步骤开始（跳过已完成步骤）
- 每步完成后写进度到 outputs/pipeline_state.json，支持断点续跑
- 每步打印预计耗时和 GPU 显存占用
- 失败时打印清晰的错误信息和建议的修复方式

## 命令行参数
python scripts/pipeline.py \
  --script data/scripts/demo_ep1.json \
  --from-step 3 \
  --resolution 720p \
  --output outputs/final/

## 额外：帮我生成一份 demo 分镜脚本
data/scripts/demo_ep1.json —「霸道总裁 - 雨中重逢」
- 5 个镜头
- 2 个角色（总裁陆景深 + 女主苏念）
- 包含环境镜头、主镜头、对白镜头
- 完整的 dialogue 字段
```

---

## Phase 2 提示词（Phase 1 跑通后再用）

### Prompt 8: ComfyUI 工作流

```
请帮我把 Phase 1 的流水线整合到 ComfyUI 工作流中。

## 任务
1. 为每个模型创建 ComfyUI 自定义节点（如果官方没有）：
   - SkyReels-V3 节点：输入参考图+prompt，输出视频
   - HunyuanVideo-Avatar 节点：输入角色图+音频，输出视频
   - VACE 修复节点：输入视频+mask，输出修复后视频
   - CosyVoice 节点：输入文本+参考音频，输出语音
   - MuseTalk 节点：输入视频+音频，输出同步视频

2. 创建完整工作流 comfyui/workflows/short_drama.json：
   - 加载 Flux + LoRA → 生成角色图
   - 角色图 + SkyReels-V3 → 主镜头视频
   - 角色图 + Wan2.1 → B-roll 视频
   - CosyVoice → 对白音频
   - MuseTalk → 口型同步
   - 所有素材汇合 → FFmpeg 输出

3. 写一个 comfyui_api_client.py，通过 ComfyUI API 提交工作流并等待结果
   - POST /prompt 提交工作流
   - WS /ws 监听进度
   - GET /history 查询结果

4. 更新 pipeline.py，增加 --backend comfyui 选项，使用 ComfyUI 而非直接调用模型
```

### Prompt 9: VACE 局部修补

```
请帮我写 scripts/07_repair.py，用 VACE 做视频局部修补。

## 场景
当某个镜头的嘴型/手势/道具不满意时，不需要重生整段视频，只需 mask 出问题区域，用 VACE 修复。

## 流程
1. 加载 outputs/videos/manifest.json
2. 用户指定要修复的镜头 ID 和修复类型（mouth/hand/prop/custom）
3. 自动生成或手动指定 mask
4. 调用 VACE masked video-to-video 修复
5. 输出修复后的视频覆盖原文件

## 命令行参数
python scripts/07_repair.py \
  --scene 4 \
  --type mouth \
  --video outputs/videos/scene_004_synced.mp4 \
  --mask outputs/masks/scene_004_mouth.png \
  --output outputs/videos/scene_004_repaired.mp4

## VACE 参考实现
https://github.com/ali-vilab/VACE
```

---

## Phase 3 提示词（Phase 2 跑通后再用）

### Prompt 10: 音效 + 配乐

```
请帮我完善音频系统：

### scripts/08_generate_foley.py
用 HunyuanVideo-Foley 为每个镜头自动生成环境音效。
- 输入：视频片段
- 输出：匹配的环境音效 wav
- 参考：https://github.com/Tencent-Hunyuan/HunyuanVideo-Foley

### scripts/09_generate_bgm.py
用 ACE-Step 生成配乐。
- 输入：整体情绪描述 + 时长
- 输出：完整配乐 wav
- 参考：https://github.com/ace-step/ACE-Step

### 更新 scripts/06_compose.py
整合 foley + bgm 到最终合成中。
对白音频优先级最高，foley 次之，bgm 最低。
```

### Prompt 11: 一致性兜底

```
请帮我写 scripts/10_consistency_check.py，用 HunyuanCustom 做角色一致性兜底。

## 流程
1. 用面部识别（insightface）提取每个镜头中的角色面部特征
2. 与角色定妆图的面部特征比对，计算相似度
3. 相似度低于阈值（如 0.85）的镜头标记为「漂移」
4. 对漂移镜头调用 HunyuanCustom 重新生成，强制角色一致性
5. 输出修复报告

## HunyuanCustom 参考
https://github.com/Tencent-Hunyuan/HunyuanCustom
```

---

## 提交给 Agent 时的话术

把上面的 Prompt 1-7 按顺序提交，每个 prompt 之间确认上一个已完成再提交下一个。

如果 Agent 遇到某个模型无法正常运行，让它：
1. 先阅读该模型的 GitHub README（inference 部分）
2. 检查模型权重文件是否完整
3. 检查 Python 依赖版本是否匹配
4. 给出具体错误信息和日志
