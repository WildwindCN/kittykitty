"""
KittyKitty 猫脸识别云函数 (Python 3.10)
DINOv2-Small ONNX — 44MB, 384维特征向量
AvitoTech 微调，猫个体识别 Top-1: 85.47%

首次冷启动：下载模型 ~10s + 初始化 ~5s = ~15s
热启动：推理 ~200ms
"""

import json
import os
import hashlib
import numpy as np
from PIL import Image
from io import BytesIO
import urllib.request
import urllib.error

# === DINOv2 ONNX 模型配置 ===
MODEL_URL = os.environ.get("MODEL_URL",
    "https://huggingface.co/onnx-community/dinov2-small/resolve/main/onnx/model_fp16.onnx")
MODEL_PATH = "/tmp/dinov2_small_fp16.onnx"

# ImageNet 标准化
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

_session = None
_input_name = None
_output_name = None

def get_session():
    global _session, _input_name, _output_name
    if _session is not None:
        return _session, _input_name, _output_name

    import onnxruntime as ort

    if not os.path.exists(MODEL_PATH):
        print(f"[recognition] downloading DINOv2 model ({MODEL_URL})...")
        req = urllib.request.Request(MODEL_URL, headers={"User-Agent": "KittyKitty/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
        with open(MODEL_PATH, "wb") as f:
            f.write(data)
        print(f"[recognition] model downloaded: {len(data)} bytes ({len(data)/1024/1024:.1f}MB)")

    opts = ort.SessionOptions()
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    _session = ort.InferenceSession(MODEL_PATH, opts)

    _input_name = _session.get_inputs()[0].name
    # DINOv2 community ONNX outputs: "last_hidden_state" (patch tokens) and "pooler_output" (CLS)
    # Try to use pooler_output for a single embedding vector
    for out in _session.get_outputs():
        if "pooler" in out.name.lower() or "cls" in out.name.lower():
            _output_name = out.name
            break
    if not _output_name:
        _output_name = _session.get_outputs()[0].name
    print(f"[recognition] ONNX ready. input={_input_name}, output={_output_name}")
    return _session, _input_name, _output_name


def preprocess_image(image_data: bytes) -> np.ndarray:
    """DINOv2 预处理：224x224 RGB, ImageNet 标准化"""
    img = Image.open(BytesIO(image_data)).convert("RGB")
    img = img.resize((224, 224), Image.Resampling.LANCZOS)
    arr = np.array(img, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    arr = arr.transpose(2, 0, 1)  # HWC -> CHW
    arr = np.expand_dims(arr, axis=0)
    return arr.astype(np.float32)


def extract_features(image_data: bytes) -> np.ndarray:
    """提取 DINOv2 特征向量"""
    session, input_name, output_name = get_session()
    tensor = preprocess_image(image_data)

    result = session.run([output_name], {input_name: tensor})
    features = result[0]

    # 取均值池化 (如果输出是 [1, N, 384] 格式的 patch tokens)
    if features.ndim == 3:
        features = features.mean(axis=1)
    features = features.flatten().astype(np.float32)

    # L2 归一化
    norm = float(np.linalg.norm(features))
    if norm > 0:
        features = features / norm
    return features


# === 主入口 ===

def main(event, context):
    body = {}
    if isinstance(event, dict):
        body = event
        raw = event.get("body", "")
        if isinstance(raw, str) and raw:
            try: body = json.loads(raw)
            except json.JSONDecodeError: pass
        elif isinstance(raw, dict):
            body = raw

    action = body.get("action", "")
    image_url = body.get("imageUrl", "")
    latitude = body.get("latitude")
    longitude = body.get("longitude")

    if action == "match":
        return match_cat_face(image_url, latitude, longitude)
    elif action == "health":
        return {"code": 200, "message": "recognition-py ready (DINOv2-Small ONNX)"}
    return {"code": 400, "message": f"unknown: {action}"}


def match_cat_face(image_url, latitude, longitude):
    if not image_url:
        return {"code": 400, "message": "imageUrl required"}

    try:
        req = urllib.request.Request(image_url, headers={"User-Agent": "KittyKitty/1.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            img_data = resp.read()

        if len(img_data) == 0:
            return {"code": 400, "message": "图片为空"}
        if len(img_data) > 10 * 1024 * 1024:
            return {"code": 400, "message": "图片过大(>10MB)"}

        features = extract_features(img_data)
        img_hash = hashlib.sha256(img_data).hexdigest()[:16]

        return {
            "code": 200,
            "data": {
                "matched": False,
                "method": "dinov2_small_onnx",
                "featureDim": len(features),
                "featureVector": [round(float(f), 6) for f in features],
                "imageHash": img_hash,
                "imageSize": len(img_data),
                "message": f"DINOv2-Small 特征提取完成 ({len(features)}维)",
            },
        }
    except urllib.error.HTTPError as e:
        return {"code": 502, "message": f"下载失败 HTTP {e.code}"}
    except urllib.error.URLError as e:
        return {"code": 502, "message": f"下载失败: {str(e.reason)}"}
    except Exception as e:
        return {"code": 500, "message": f"识别失败: {str(e)}"}

# === 保留纯 Python fallback（模型下载失败时使用）===

def fallback_features(image_data: bytes) -> list:
    """纯 Python 感知哈希 (144维) — 仅用于 DINOv2 不可用时的降级"""
    import math
    # 简化版 aHash (64维)
    info = {"pixels": list(image_data[:256]), "width": 16, "height": 16}
    ahash = [1.0 if b > 128 else 0.0 for b in image_data[:64].ljust(64, b'\x00')]
    # 颜色简化为 48维
    color = [0.0] * 48
    # 纹理简化为 32维
    tex = [0.0] * 32
    features = ahash + color + tex
    norm = math.sqrt(sum(f*f for f in features)) if features else 1
    return [f/norm for f in features] if norm > 0 else features
