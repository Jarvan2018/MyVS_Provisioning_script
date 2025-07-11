#!/bin/bash

#================================================================================
# Vast.ai ComfyUI 自动化配置脚本 (V3.2 - hf_transfer 加速支持)
#================================================================================
# 更新日志:
# - V3: 将依赖安装和模型下载并行化处理，以大幅缩短准备时间。
# - V3.1: 添加了下载进度显示，每5%进度打印一次。
# - V3.2: 集成 hf_transfer 支持，实现极致下载速度。
#================================================================================


# --- 脚本设置 ---
# 如果任何命令失败，脚本将立即退出。
set -eo pipefail


# --- 步骤 0: 激活环境并更新Pip ---
echo "▶️ [0/5] 正在激活环境并更新Pip..."
if [ -f "/venv/main/bin/activate" ]; then
    . /venv/main/bin/activate
    echo "✅ 虚拟环境已激活。"
else
    echo "⚠️ 未找到虚拟环境，将使用系统Python。"
fi
pip install --upgrade pip
pip install huggingface_hub tqdm
pip install hf_transfer # <--- 添加: 安装 hf_transfer 加速库

echo "✅ Pip 已更新。"


# --- 步骤 1: 准备工作区 (串行执行) ---
echo "▶️ [1/5] 正在准备工作区..."
cd /workspace
echo "  - 正在克隆 ComfyUI 主仓库..."
git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git

echo "  - 正在克隆所有自定义节点..."
cd /workspace/ComfyUI/custom_nodes
git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager
git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
git clone --depth 1 https://github.com/crystian/ComfyUI-Crystools
git clone --depth 1 https://github.com/talesofai/comfyui-browser
git clone --depth 1 https://github.com/rgthree/rgthree-comfy
git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes
git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper
git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts
git clone --depth 1 https://github.com/kaibioinfo/ComfyUI_AdvancedRefluxControl.git
git clone --depth 1 https://github.com/ostris/ComfyUI-Advanced-Vision
git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials
git clone --depth 1 https://github.com/kijai/ComfyUI-DepthAnythingV2
git clone --depth 1 https://github.com/chrisgoringe/cg-use-everywhere
git clone --depth 1 https://github.com/Fannovel16/comfyui_controlnet_aux
git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git

echo "  - 正在 ComfyUI 内部创建模型目录..."
mkdir -p /workspace/ComfyUI/models/{controlnet,animatediff_models,animatediff_motion_lora,loras,CogVideo/loras,clip,LLM,checkpoints,upscale_models,vae,clip_vision,diffusion_models,models/style_models}
echo "✅ 工作区准备完毕。"


# --- 步骤 2: 定义并行任务 ---

# 任务 A: 安装所有Python依赖
install_dependencies() {
    echo "📦 [任务A] 开始安装 Python 依赖..."
    
    
    cd /workspace/ComfyUI
    echo "📦 [任务A] 正在安装 ComfyUI 核心依赖..."
    pip install xformers!=0.0.18 -r requirements.txt

    echo "📦 [任务A] 正在安装自定义节点依赖..."
    for dir in /workspace/ComfyUI/custom_nodes/*/; do
      if [ -f "${dir}requirements.txt" ]; then
        echo "📦 [任务A]   - 正在为 $(basename "$dir") 安装依赖..."
        pip install -r "${dir}requirements.txt"
      fi
    done

    echo "📦 [任务A] [特定硬件] 正在为新一代GPU安装PyTorch Nightly版本..."
    pip uninstall -y torch torchvision torchaudio xformers
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
    # pip install xformers
    echo "✅📦 [任务A] 所有依赖安装完毕。"
}

# 任务 B: 下载所有模型
download_models() {
    echo "⬇️ [任务B] 开始下载所有模型..."
    
    # <--- 添加: 设置环境变量以激活 hf_transfer 加速模式
    echo "🚀 [任务B] 已激活 hf_transfer 加速模式！"
    export HF_HUB_ENABLE_HF_TRANSFER=1
    
    cat <<EOF > /workspace/download_models.py
from huggingface_hub import hf_hub_download
import sys
import time
import os
from tqdm import tqdm

class ProgressCallback:
    def __init__(self, filename):
        self.filename = filename
        self.last_printed_percentage = 0
        
    def __call__(self, current, total):
        if total > 0:
            percentage = int((current / total) * 100)
            # 每5%打印一次进度
            if percentage >= self.last_printed_percentage + 5:
                print(f"📥 [任务B] {self.filename}: {percentage}% 完成 ({current:,}/{total:,} 字节)")
                self.last_printed_percentage = percentage

def download_with_progress(repo_id, filename, local_dir, repo_type=None):
    try:
        print(f"⬇️ [任务B] 开始下载: {filename}")
        
        # 创建进度回调
        progress_callback = ProgressCallback(filename)
        
        # 使用huggingface_hub下载，支持断点续传
        file_path = hf_hub_download(
            repo_id=repo_id, 
            filename=filename, 
            local_dir=local_dir, 
            repo_type=repo_type,
            resume_download=True
        )
        
        # 获取文件大小用于显示
        if os.path.exists(file_path):
            file_size = os.path.getsize(file_path)
            print(f"✅⬇️ [任务B] 下载完成: {filename} ({file_size:,} 字节)")
        else:
            print(f"✅⬇️ [任务B] 下载完成: {filename}")
            
    except Exception as e:
        print(f"❌⬇️ [任务B] 下载失败: {filename}. 错误: {e}", file=sys.stderr)

def download_with_wget_progress(repo_id, filename, local_dir):
    """使用wget下载并显示进度条的备用方法"""
    try:
        print(f"⬇️ [任务B] 开始下载: {filename}")
        
        # 构建HuggingFace文件URL
        if repo_id.count('/') == 1:
            url = f"https://huggingface.co/{repo_id}/resolve/main/{filename}"
        else:
            url = f"https://huggingface.co/{repo_id}/resolve/main/{filename}"
        
        # 确保目录存在
        os.makedirs(local_dir, exist_ok=True)
        output_path = os.path.join(local_dir, os.path.basename(filename))
        
        # 使用wget下载并显示进度
        import subprocess
        cmd = [
            'wget', 
            '--progress=bar:force:noscroll',
            '--continue',  # 支持断点续传
            '-O', output_path,
            url
        ]
        
        result = subprocess.run(cmd, capture_output=False, text=True)
        
        if result.returncode == 0:
            file_size = os.path.getsize(output_path)
            print(f"✅⬇️ [任务B] 下载完成: {filename} ({file_size:,} 字节)")
        else:
            raise Exception(f"wget返回错误代码: {result.returncode}")
            
    except Exception as e:
        print(f"❌⬇️ [任务B] wget下载失败: {filename}. 错误: {e}", file=sys.stderr)
        # 回退到huggingface_hub方法
        download_with_progress(repo_id, filename, local_dir)

# 主下载函数
def download(repo_id, filename, local_dir, repo_type=None, use_wget=False):
    if use_wget:
        download_with_wget_progress(repo_id, filename, local_dir)
    else:
        download_with_progress(repo_id, filename, local_dir, repo_type)

# 开始下载所有模型
MODEL_BASE_PATH = "/workspace/ComfyUI/models"

print("⬇️ [任务B] 开始批量下载模型文件...")
print("⬇️ [任务B] 注意: 大文件下载可能需要较长时间，请耐心等待...")

# 下载模型列表
# ("Kijai/WanVideo_comfy", "Wan2_1-T2V-14B_fp8_e4m3fn.safetensors", f"{MODEL_BASE_PATH}/diffusion_models"),
models = [
    ("Kijai/WanVideo_comfy", "Phantom-Wan-14B_fp8_e4m3fn.safetensors", f"{MODEL_BASE_PATH}/diffusion_models"),
    ("Kijai/WanVideo_comfy", "Wan2_1-VACE_module_14B_bf16.safetensors", f"{MODEL_BASE_PATH}/diffusion_models"),
    ("Kijai/WanVideo_comfy", "umt5-xxl-enc-bf16.safetensors", f"{MODEL_BASE_PATH}/clip"),
    ("Kijai/WanVideo_comfy", "Wan2_1_VAE_bf16.safetensors", f"{MODEL_BASE_PATH}/vae"),
    ("Kijai/WanVideo_comfy", "Wan21_CausVid_14B_T2V_lora_rank32.safetensors", f"{MODEL_BASE_PATH}/loras"),
    ("Kijai/WanVideo_comfy", "Wan21_T2V_14B_MoviiGen_lora_rank32_fp16.safetensors", f"{MODEL_BASE_PATH}/loras"),
    ("Kijai/WanVideo_comfy", "Wan21_AccVid_T2V_14B_lora_rank32_fp16.safetensors", f"{MODEL_BASE_PATH}/loras"),
    ("Kijai/WanVideo_comfy", "Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors", f"{MODEL_BASE_PATH}/loras"),
    ("vrgamedevgirl84/Wan14BT2VFusioniX", "OtherLoRa's/DetailEnhancerV1.safetensors", f"{MODEL_BASE_PATH}/loras"),
    ("alibaba-pai/Wan2.1-Fun-Reward-LoRAs", "Wan2.1-Fun-14B-InP-MPS.safetensors", f"{MODEL_BASE_PATH}/loras"),
    ("vrgamedevgirl84/Wan14BT2VFusioniX", "OtherLoRa's/Wan14B_RealismBoost.safetensors", f"{MODEL_BASE_PATH}/loras"),
    ("Kim2091/UltraSharpV2", "4x-UltraSharpV2.safetensors", f"{MODEL_BASE_PATH}/upscale_models"),
]

# 依次下载每个模型
for i, (repo_id, filename, local_dir) in enumerate(models, 1):
    print(f"⬇️ [任务B] [{i}/{len(models)}] 准备下载模型...")
    download(repo_id, filename, local_dir)
    print(f"⬇️ [任务B] [{i}/{len(models)}] 模型下载任务完成")
    print("-" * 60)

print("✅⬇️ [任务B] 所有模型下载任务已完成!")
EOF
    
    python /workspace/download_models.py
    echo "✅⬇️ [任务B] 所有模型下载任务已执行。"
}


# --- 步骤 3: 并行执行任务 ---
echo "▶️ [3/5] 🚀 即将并行执行 [任务A:依赖安装] 和 [任务B:模型下载]..."
echo "日志将会混合输出，请耐心等待..."

# 启动任务A到后台
install_dependencies &
# 启动任务B到后台
download_models &

# 等待所有后台作业完成
wait

echo "✅ [3/5] 所有并行任务均已完成。"


echo ""
echo "🎉🚀 所有配置已完成！ComfyUI 服务正在后台启动。"
echo "你现在可以从Vast.ai的Web UI上直接点击'ComfyUI'链接访问了。"