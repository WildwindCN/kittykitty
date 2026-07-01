import os; os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
import sys; sys.path.insert(0, "/root")
from recognition_server import load_model, extract_features
import time

with open("/tmp/test_cat.png", "rb") as f:
    img_data = f.read()

print("Loading facebook/dinov2-small (HF mirror)...")
t0 = time.time()
vec = extract_features(img_data)
print(f"SUCCESS: dim={len(vec)}, time={time.time()-t0:.1f}s")
