"""
KittyKitty 猫脸识别服务器 — DINOv2-Small PyTorch (本地模型)
直接加载缓存模型，不访问 HuggingFace
"""
import io, os, json, hashlib, argparse, time, glob
import numpy as np
import urllib.request
import urllib.error
from PIL import Image
from flask import Flask, request, jsonify

app = Flask(__name__)

# 使用 ECS 本地缓存的 AvitoTech 模型
MODEL_ID = "AvitoTech/DINO-v2-small-for-animal-identification"
CACHE_DIR = "/root/.cache/huggingface/hub"
DEVICE = "cpu"

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

model = None

def load_model():
    global model
    if model is not None: return

    import torch
    import safetensors.torch
    from transformers import AutoConfig, AutoModel

    print(f"[kittykitty] loading {MODEL_ID} from local cache...")

    # Find the cached model directory
    model_dir = os.path.join(CACHE_DIR, "models--AvitoTech--DINO-v2-small-for-animal-identification")
    snapshots = os.path.join(model_dir, "snapshots")
    if os.path.exists(snapshots):
        snapshot = os.listdir(snapshots)[0]
        model_path = os.path.join(snapshots, snapshot)
    else:
        model_path = os.path.join(model_dir, "blobs")

    # Find the safetensors file
    st_files = glob.glob(os.path.join(model_dir, "blobs", "*"))
    st_file = None
    for f in st_files:
        if os.path.getsize(f) > 1000000:  # > 1MB = model weights
            st_file = f
            break

    if not st_file:
        raise FileNotFoundError("Model weights not found in cache")

    print(f"[kittykitty] loading weights from: {st_file} ({os.path.getsize(st_file)/1024/1024:.0f}MB)")

    # Load state dict and remap keys (strip 'backbone.' prefix)
    state_dict = safetensors.torch.load_file(st_file)
    new_state_dict = {}
    for key, value in state_dict.items():
        new_key = key
        if key.startswith("backbone."):
            new_key = key[9:]  # strip "backbone."
        elif key.startswith("embeddings."):
            new_key = "backbone." + key
        new_state_dict[new_key] = value

    print(f"[kittykitty] remapped {len(new_state_dict)} weight keys")

    # Create model and load
    config = AutoConfig.from_pretrained(MODEL_ID, local_files_only=True, trust_remote_code=True)
    model = AutoModel.from_config(config).to(DEVICE)

    # Try loading with remapped keys
    missing, unexpected = model.load_state_dict(new_state_dict, strict=False)
    if missing:
        print(f"[kittykitty] missing keys: {len(missing)}")
    if unexpected:
        print(f"[kittykitty] unexpected keys: {len(unexpected)}")

    model.eval()
    n_params = sum(p.numel() for p in model.parameters())
    print(f"[kittykitty] loaded. {n_params:,} params on {DEVICE}")

def preprocess_image(image_data: bytes) -> np.ndarray:
    img = Image.open(io.BytesIO(image_data)).convert("RGB")
    img = img.resize((224, 224), Image.Resampling.LANCZOS)
    arr = np.array(img, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    arr = arr.transpose(2, 0, 1)
    return np.expand_dims(arr, axis=0).astype(np.float32)

def extract_features(image_data: bytes) -> np.ndarray:
    import torch
    load_model()
    tensor = torch.from_numpy(preprocess_image(image_data)).to(DEVICE)
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

@app.route("/health")
def health():
    return jsonify({"status":"ok","model":MODEL_ID,"device":DEVICE,"loaded":model is not None})

@app.route("/extract", methods=["POST"])
def extract():
    data = request.get_json(force=True)
    image_url = data.get("imageUrl", "")
    if not image_url:
        return jsonify({"code":400,"message":"imageUrl required"}), 400
    try:
        req = urllib.request.Request(image_url, headers={"User-Agent":"KittyKitty/1.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            img_data = resp.read()
        if len(img_data) > 10*1024*1024:
            return jsonify({"code":400,"message":"图片过大"}), 400
        t0 = time.time()
        features = extract_features(img_data)
        ms = (time.time()-t0)*1000
        return jsonify({"code":200,"data":{
            "matched":False,"method":"dinov2_small","featureDim":int(len(features)),
            "inferenceMs":round(ms,1),"featureVector":[round(float(f),6) for f in features],
            "imageHash":hashlib.sha256(img_data).hexdigest()[:16],"imageSize":len(img_data),
        }})
    except Exception as e:
        return jsonify({"code":500,"message":str(e)}), 500

@app.route("/extract_batch", methods=["POST"])
def extract_batch():
    data = request.get_json(force=True)
    urls = data.get("imageUrls",[])
    if not urls or len(urls)>16:
        return jsonify({"code":400,"message":"imageUrls 1-16 required"}),400
    try:
        import torch
        images = []
        for url in urls:
            req = urllib.request.Request(url, headers={"User-Agent":"KittyKitty/1.0"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                images.append(resp.read())
        load_model()
        tensors = torch.cat([torch.from_numpy(preprocess_image(d)) for d in images]).to(DEVICE)
        with torch.no_grad(): outputs = model(tensors)
        if hasattr(outputs,'pooler_output') and outputs.pooler_output is not None:
            feats = outputs.pooler_output
        else:
            feats = outputs.last_hidden_state.mean(dim=1) if hasattr(outputs,'last_hidden_state') else outputs[0]
        vecs = feats.cpu().numpy().astype(np.float32)
        norms = np.linalg.norm(vecs,axis=1,keepdims=True); norms[norms==0]=1; vecs/=norms
        return jsonify({"code":200,"data":{
            "method":"dinov2_small","featureDim":int(vecs.shape[1]),
            "featureVectors":[vecs[i].tolist() for i in range(vecs.shape[0])]
        }})
    except Exception as e:
        return jsonify({"code":500,"message":str(e)}),500

if __name__ == "__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--port",type=int,default=8765)
    p.add_argument("--host",default="0.0.0.0")
    args=p.parse_args()
    print(f"[kittykitty] starting on {args.host}:{args.port}")
    app.run(host=args.host,port=args.port,debug=False)
