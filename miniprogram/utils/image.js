// 图片工具 — fileID → 临时 URL 转换
const CACHE_TTL = 90 * 60 * 1000; // 90 分钟（temp URL 有效期约 2 小时）

const cache = {}; // { [fileID]: { url, ts } }

module.exports = {
  async getTempUrls(fileIDs) {
    if (!Array.isArray(fileIDs)) fileIDs = [fileIDs];
    const ids = fileIDs.filter(id => id && typeof id === 'string');
    const now = Date.now();
    const results = {};

    // 缓存命中
    const needConvert = [];
    for (const id of ids) {
      const entry = cache[id];
      if (entry && now - entry.ts < CACHE_TTL) {
        results[id] = entry.url;
      } else if (!id.startsWith('cloud://')) {
        results[id] = id; // HTTP URL 直接使用
      } else {
        needConvert.push(id);
      }
    }

    if (needConvert.length > 0) {
      try {
        const res = await wx.cloud.getTempFileURL({ fileList: needConvert });
        for (const item of res.fileList || []) {
          if (item.tempFileURL) {
            cache[item.fileID] = { url: item.tempFileURL, ts: now };
            results[item.fileID] = item.tempFileURL;
          }
        }
      } catch (_) {}
    }

    return results;
  },

  async getTempUrl(fileID) {
    if (!fileID) return '';
    const urls = await this.getTempUrls([fileID]);
    return urls[fileID] || fileID;
  },

  clearCache() {
    for (const key of Object.keys(cache)) {
      delete cache[key];
    }
  },
};
