#!/bin/bash

#================================================================================
# Vast.ai ComfyUI 自动化配置脚本 (V3 - 并行优化版)
#================================================================================
# 更新日志:
# - V3: 将依赖安装和模型下载并行化处理，以大幅缩短准备时间。
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

echo "  - 正在 ComfyUI 内部创建模型目录..."
mkdir -p /workspace/ComfyUI/models/{controlnet,animatediff_models,animatediff_motion_lora,loras,CogVideo/loras,clip,LLM,checkpoints,upscale_models,vae,clip_vision,diffusion_models,models/style_models}
echo "✅ 工作区准备完毕。"


# --- 步骤 2: 定义并行任务 ---

# 任务 A: 安装所有Python依赖
install_dependencies() {
    echo "📦 [任务A] 开始安装 Python 依赖..."
    # 安装一个基础包，以防下载脚本需要
    pip install huggingface_hub
    
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
    pip install xformers
    echo "✅📦 [任务A] 所有依赖安装完毕。"
}

# 任务 B: 下载所有模型
download_models() {
    echo "⬇️ [任务B] 开始下载所有模型..."
    cat <<EOF > /workspace/download_models.py
from huggingface_hub import hf_hub_download
import sys
import time

def download(repo_id, filename, local_dir, repo_type=None):
    try:
        print(f"⬇️  [任务B]   - 正在下载: {filename}")
        hf_hub_download(repo_id=repo_id, filename=filename, local_dir=local_dir, repo_type=repo_type)
        print(f"✅⬇️ [任务B]   - 下载成功: {filename}")
    except Exception as e:
        print(f"❌⬇️ [任务B]   - 下载失败: {filename}. 错误: {e}", file=sys.stderr)

MODEL_BASE_PATH = "/workspace/ComfyUI/models"
download(repo_id="Kijai/WanVideo_comfy", filename="Wan2_1-T2V-14B_fp8_e4m3fn.safetensors", local_dir=f"{MODEL_BASE_PATH}/diffusion_models")
download(repo_id="Kijai/WanVideo_comfy", filename="Wan2_1-VACE_module_14B_bf16.safetensors", local_dir=f"{MODEL_BASE_PATH}/diffusion_models")
download(repo_id="Comfy-Org/Wan_2.1_ComfyUI_repackaged", filename="split_files/clip_vision/clip_vision_h.safetensors", local_dir=f"{MODEL_BASE_PATH}/clip_vision")
download(repo_id="Kijai/WanVideo_comfy", filename="umt5-xxl-enc-bf16.safetensors", local_dir=f"{MODEL_BASE_PATH}/clip")
download(repo_id="Kijai/WanVideo_comfy", filename="Wan2_1_VAE_bf16.safetensors", local_dir=f"{MODEL_BASE_PATH}/vae")
download(repo_id="Kijai/WanVideo_comfy", filename="Wan21_CausVid_14B_T2V_lora_rank32.safetensors", local_dir=f"{MODEL_BASE_PATH}/loras")
download(repo_id="lokCX/4x-Ultrasharp", filename="4x-UltraSharp.pth", local_dir=f"{MODEL_BASE_PATH}/upscale_models")
download(repo_id="Kijai/WanVideo_comfy", filename="Skyreels/Wan2_1-SkyReels-V2-DF-14B-720P_fp8_e4m3fn.safetensors", local_dir=f"{MODEL_BASE_PATH}/diffusion_models")
download(repo_id="alibaba-pai/Wan2.1-Fun-Reward-LoRAs", filename="Wan2.1-Fun-14B-InP-MPS.safetensors", local_dir=f"{MODEL_BASE_PATH}/loras")
download(repo_id="alibaba-pai/Wan2.1-Fun-Reward-LoRAs", filename="Wan2.1-Fun-14B-InP-HPS2.1.safetensors", local_dir=f"{MODEL_BASE_PATH}/loras")
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


# --- 步骤 4: 配置 Supervisor 服务 ---
echo "▶️ [4/5] 正在配置 Supervisor 以启动并守护 ComfyUI..."
cat <<EOF > /opt/supervisor-scripts/comfyui.sh
#!/bin/bash
if [ -f "/venv/main/bin/activate" ]; then . /venv/main/bin/activate; fi
cd /workspace/ComfyUI
python main.py --listen --port 6760 --preview-method auto
EOF
chmod +x /opt/supervisor-scripts/comfyui.sh

cat <<EOF > /etc/supervisor/conf.d/comfyui.conf
[program:comfyui]
command=/opt/supervisor-scripts/comfyui.sh
autostart=true; autorestart=true
stderr_logfile=/var/log/comfyui.err.log; stdout_logfile=/var/log/comfyui.out.log
user=root
EOF
echo "✅ Supervisor 配置完毕。"


# --- 步骤 5: 集成Vast.ai门户并重载服务 ---
echo "▶️ [5/5] 正在集成 ComfyUI 到 Vast.ai 门户并应用所有更改..."
COMFYUI_PORTAL_ENTRY="  - 'localhost:6760:16760:/:ComfyUI'"
echo "${COMFYUI_PORTAL_ENTRY}" >> /etc/portal.yaml

supervisorctl reload

echo ""
echo "🎉🚀 所有配置已完成！ComfyUI 服务正在后台启动。"
echo "你现在可以从Vast.ai的Web UI上直接点击'ComfyUI'链接访问了。"