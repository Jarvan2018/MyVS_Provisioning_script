#!/bin/bash

cd /app
rm -rf models
ln -s /workspace/ComfyUI/models /app/models
rm -rf custom_nodes
ln -s /workspace/ComfyUI/custom_nodes /app/custom_nodes

# if [ -f "/venv/main/bin/activate" ]; then
#     . /venv/main/bin/activate
#     echo "✅ 虚拟环境已激活。"
# else
#     echo "⚠️ 未找到虚拟环境，将使用系统Python。"
# fi

echo "📦 [任务A] 正在安装自定义节点依赖..."
for dir in /workspace/ComfyUI/custom_nodes/*/; do
    if [ -f "${dir}requirements.txt" ]; then
    echo "📦 [任务A]   - 正在为 $(basename "$dir") 安装依赖..."
    pip install -r "${dir}requirements.txt"
    fi
done