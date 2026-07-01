// API 客户端 — 封装 wx.request 调用 CloudBase HTTP 云函数
const app = getApp();

function request(fnPath, data = {}) {
  return new Promise((resolve, reject) => {
    const token = app.globalData.token;
    // 自动注入 token
    if (token) data.token = token;

    wx.request({
      url: `${app.globalData.apiBaseUrl}/${fnPath}`,
      method: 'POST',
      header: {
        'Content-Type': 'application/json',
        ...(token ? { 'X-Auth-Token': `Bearer ${token}` } : {}),
      },
      data,
      timeout: 30000,
      success(res) {
        if (res.statusCode === 200 && res.data) {
          resolve(res.data);
        } else {
          reject(res.data);
        }
      },
      fail(err) {
        reject(err);
      },
    });
  });
}

module.exports = {
  // Auth
  sendSms(phone) { return request('auth', { action: 'send-sms', phone }); },
  login(phone, code) { return request('auth', { action: 'login', phone, code }); },
  getProfile() { return request('auth', { action: 'profile' }); },
  refreshToken(refreshToken) { return request('auth', { action: 'refresh-token', refreshToken }); },

  // Cats
  getNearbyCats(lat, lng, radius = 5000) {
    return request('cats', { action: 'nearby', latitude: lat, longitude: lng, radius });
  },
  getMyCats() { return request('cats', { action: 'my-cats' }); },
  captureCat(catData) { return request('cats', { action: 'capture', catData }); },
  getCatDetail(catId) { return request('cats', { action: 'cat-detail', catId }); },

  // Recognition
  matchCatFace(imageUrl, lat, lng) {
    return request('recognition', { action: 'match', imageUrl, latitude: lat, longitude: lng });
  },

  // Battle
  getBattleHistory() { return request('battle', { action: 'history' }); },
  submitBattle(data) { return request('battle', { action: 'submit', ...data }); },

  // Storage — 使用 wx.cloud.uploadFile
  async uploadImage(filePath) {
    const cloudPath = `cats/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.jpg`;
    const result = await wx.cloud.uploadFile({ cloudPath, filePath });
    return result.fileID;
  },
};
