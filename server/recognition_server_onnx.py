"""
KittyKitty 猫脸识别服务器 — DINOv2-Small ONNX Runtime
384维特征向量 | ONNX FP16 | CPU推理 ~50ms

启动: python3 recognition_server.py --port 8765
"""
import io, os, json, hashlib, argparse, time
import numpy as np
import onnxruntime as ort
import urllib.request
import urllib.error
from PIL import Image
from flask import Flask, request, jsonify

app = Flask(__name__)

MODEL_PATH = os.environ.get("MODEL_PATH", "/root/dinov2_small_fp16.onnx")
DEVICE = "CPU"

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

_session = None
_input_name = None
_output_name = None

def get_session():
    global _session, _input_name, _output_name
    if _session is not None:
        return _session, _input_name, _output_name

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"ONNX model not found: {MODEL_PATH}")

    opts = ort.SessionOptions()
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC
    opts.intra_op_num_threads = 4
    # 禁用有问题的 LayerNorm 融合优化
    opts.add_session_config_entry("optimization.enable_gelu_approximation", "0")
    _session = ort.InferenceSession(MODEL_PATH, opts, providers=['CPUExecutionProvider'])

    _input_name = _session.get_inputs()[0].name
    # Try pooler_output first, fall back to last_hidden_state
    for out in _session.get_outputs():
        if "pooler" in out.name.lower():
            _output_name = out.name
            break
    if not _output_name:
        _output_name = _session.get_outputs()[0].name
    print(f"[kittykitty] ONNX ready. input={_input_name}, output={_output_name}")
    return _session, _input_name, _output_name

def preprocess_image(image_data: bytes) -> np.ndarray:
    img = Image.open(io.BytesIO(image_data)).convert("RGB")
    img = img.resize((224, 224), Image.Resampling.LANCZOS)
    arr = np.array(img, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    arr = arr.transpose(2, 0, 1)  # HWC -> CHW
    return np.expand_dims(arr, axis=0).astype(np.float32)

def extract_features(image_data: bytes) -> np.ndarray:
    session, input_name, output_name = get_session()
    tensor = preprocess_image(image_data)
    result = session.run([output_name], {input_name: tensor})
    features = result[0]
    # Mean pool if output is patch tokens [1, N, 384]
    if features.ndim == 3:
        features = features.mean(axis=1)
    features = features.flatten().astype(np.float32)
    # L2 normalize
    norm = float(np.linalg.norm(features))
    if norm > 0:
        features = features / norm
    return features

@app.route("/health")
def health():
    try:
        get_session()
        loaded = True
    except:
        loaded = False
    return jsonify({"status":"ok","model":"dinov2_small_onnx","device":DEVICE,"loaded":loaded})

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
            "matched":False,"method":"dinov2_small_onnx","featureDim":int(len(features)),
            "inferenceMs":round(ms,1),"featureVector":[round(float(f),6) for f in features],
            "imageHash":hashlib.sha256(img_data).hexdigest()[:16],"imageSize":len(img_data),
        }})
    except urllib.error.HTTPError as e:
        return jsonify({"code":502,"message":f"下载失败 HTTP {e.code}"}), 502
    except Exception as e:
        return jsonify({"code":500,"message":str(e)}), 500

@app.route("/extract_batch", methods=["POST"])
def extract_batch():
    data = request.get_json(force=True)
    urls = data.get("imageUrls",[])
    if not urls or len(urls) > 16:
        return jsonify({"code":400,"message":"imageUrls 1-16 required"}), 400
    try:
        images = []
        for url in urls:
            req = urllib.request.Request(url, headers={"User-Agent":"KittyKitty/1.0"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                images.append(resp.read())
        tensors = np.concatenate([preprocess_image(d) for d in images], axis=0)
        session, input_name, output_name = get_session()
        result = session.run([output_name], {input_name: tensors})
        feats = result[0]
        if feats.ndim == 3:
            feats = feats.mean(axis=1)
        vecs = feats.astype(np.float32)
        norms = np.linalg.norm(vecs, axis=1, keepdims=True)
        norms[norms == 0] = 1
        vecs = vecs / norms
        return jsonify({"code":200,"data":{
            "method":"dinov2_small_onnx","featureDim":int(vecs.shape[1]),
            "featureVectors":[vecs[i].tolist() for i in range(vecs.shape[0])]
        }})
    except Exception as e:
        return jsonify({"code":500,"message":str(e)}), 500

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("--host", default="0.0.0.0")
    args = p.parse_args()
    print(f"[kittykitty] starting on {args.host}:{args.port}")
    app.run(host=args.host, port=args.port, debug=False)
