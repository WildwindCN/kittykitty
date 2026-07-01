"""
KittyKitty 猫脸识别服务器
DINOv2-Small (AvitoTech) — 384维特征
PyTorch 推理 | Flask HTTP API | 端点可配置

启动: python recognition_server.py --port 8765
生产: 改 RECOGNITION_ENDPOINT 环境变量或 Flutter AppConfig
"""

import io, os, json, hashlib, argparse, time
import numpy as np
import requests as http_requests
from PIL import Image
from flask import Flask, request, jsonify

app = Flask(__name__)

# === 模型配置 ===
MODEL_ID = "AvitoTech/DINO-v2-small-for-animal-identification"
DEVICE = "cpu"  # RTX 5070 Ti 需 PyTorch 2.7+，先 CPU
BATCH_SIZE = 8

# ImageNet 标准化
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

model = None

def load_model():
    global model
    if model is not None: return
    import torch
    from transformers import AutoModel
    print(f"[kittykitty] loading {MODEL_ID} on {DEVICE}...")
    model = AutoModel.from_pretrained(MODEL_ID).to(DEVICE).eval()
    n_params = sum(p.numel() for p in model.parameters())
    print(f"[kittykitty] loaded. {n_params:,} params on {DEVICE}")

def preprocess(image_data: bytes):
    img = Image.open(io.BytesIO(image_data)).convert("RGB")
    img = img.resize((224, 224), Image.Resampling.LANCZOS)
    arr = np.array(img, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    arr = arr.transpose(2, 0, 1)
    return np.expand_dims(arr, axis=0).astype(np.float32)

def extract_features(image_data: bytes) -> np.ndarray:
    import torch
    load_model()
    tensor = torch.from_numpy(preprocess(image_data)).to(DEVICE)
    with torch.no_grad():
        outputs = model(tensor)
    if hasattr(outputs, 'pooler_output') and outputs.pooler_output is not None:
        features = outputs.pooler_output
    elif hasattr(outputs, 'last_hidden_state'):
        features = outputs.last_hidden_state.mean(dim=1)
    else:
        features = outputs[0]
    vec = features.cpu().numpy().flatten().astype(np.float32)
    norm = float(np.linalg.norm(vec))
    return vec / norm if norm > 0 else vec

# === API ===

@app.route("/health")
def health():
    return jsonify({"status":"ok","model":MODEL_ID,"device":DEVICE,"loaded":model is not None})

@app.route("/extract", methods=["POST"])
def extract():
    data = request.get_json(force=True)
    image_url = data.get("imageUrl", "")
    if not image_url: return jsonify({"code":400,"message":"imageUrl required"}), 400
    try:
        resp = http_requests.get(image_url, timeout=20, headers={"User-Agent":"KittyKitty/1.0"})
        resp.raise_for_status()
        img_data = resp.content
        if len(img_data) > 10*1024*1024: return jsonify({"code":400,"message":"图片过大"}), 400
        t0 = time.time()
        features = extract_features(img_data)
        ms = (time.time()-t0)*1000
        return jsonify({"code":200,"data":{
            "matched":False,"method":"dinov2_small","featureDim":len(features),
            "inferenceMs":round(ms,1),"featureVector":[round(float(f),6) for f in features],
            "imageHash":hashlib.sha256(img_data).hexdigest()[:16],"imageSize":len(img_data),
        }})
    except Exception as e:
        return jsonify({"code":500,"message":str(e)}), 500

@app.route("/extract_batch", methods=["POST"])
def extract_batch():
    data = request.get_json(force=True)
    urls = data.get("imageUrls",[])
    if not urls or len(urls)>16: return jsonify({"code":400,"message":"imageUrls 1-16 required"}),400
    try:
        images = []
        for url in urls:
            r = http_requests.get(url, timeout=20, headers={"User-Agent":"KittyKitty/1.0"})
            r.raise_for_status()
            images.append(r.content)
        import torch
        load_model()
        tensors = torch.cat([torch.from_numpy(preprocess(d)) for d in images]).to(DEVICE)
        with torch.no_grad(): outputs = model(tensors)
        if hasattr(outputs,'pooler_output') and outputs.pooler_output is not None:
            feats = outputs.pooler_output
        else:
            feats = outputs.last_hidden_state.mean(dim=1) if hasattr(outputs,'last_hidden_state') else outputs[0]
        vecs = feats.cpu().numpy().astype(np.float32)
        norms = np.linalg.norm(vecs,axis=1,keepdims=True); norms[norms==0]=1; vecs/=norms
        return jsonify({"code":200,"data":{"method":"dinov2_small","featureDim":vecs.shape[1],"featureVectors":[vecs[i].tolist() for i in range(vecs.shape[0])]}})
    except Exception as e:
        return jsonify({"code":500,"message":str(e)}),500

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--port",type=int,default=8765);p.add_argument("--host",default="127.0.0.1")
    args=p.parse_args()
    print(f"[kittykitty] starting on {args.host}:{args.port}")
    app.run(host=args.host,port=args.port,debug=False)
