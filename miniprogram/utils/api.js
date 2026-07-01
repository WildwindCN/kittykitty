// API 客户端 — 封装 wx.request 调用 CloudBase HTTP 云函数
const app = getApp();

let _isRefreshing = false;
let _refreshQueue = [];

function resolveRefreshQueue(success) {
  _refreshQueue.forEach(([resolve, reject]) => {
    if (success) resolve();
    else reject(new Error('token_refresh_failed'));
  });
  _refreshQueue = [];
}

async function tryRefreshToken() {
  const refreshToken = wx.getStorageSync('refresh_token');
  if (!refreshToken) return false;

  try {
    const res = await new Promise((resolve, reject) => {
      wx.request({
        url: `${app.globalData.apiBaseUrl}/auth`,
        method: 'POST',
        header: { 'Content-Type': 'application/json' },
        data: { action: 'refresh-token', refreshToken },
        timeout: 15000,
        success(r) { resolve(r.data); },
        fail: reject,
      });
    });

    if (res.code === 200 && res.data) {
      app.globalData.token = res.data.token;
      wx.setStorageSync('auth_token', res.data.token);
      wx.setStorageSync('refresh_token', res.data.refreshToken);
      return true;
    }
  } catch (_) {}
  return false;
}

function request(fnPath, originData = {}, retry = true) {
  return new Promise((resolve, reject) => {
    const execute = () => {
      const token = app.globalData.token;
      const data = { ...originData };
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
          } else if (res.statusCode === 401 && retry && wx.getStorageSync('refresh_token')) {
            // Token 过期，尝试刷新
            handle401().then(() => {
              // 更新 token 后重试
              if (app.globalData.token) {
                data.token = app.globalData.token;
              }
              // 递归重试，但不再触发 refresh
              request(fnPath, data, false).then(resolve).catch(reject);
            }).catch(() => {
              // 刷新失败，跳转登录
              redirectToLogin();
              reject({ code: 401, message: '登录已过期' });
            });
          } else {
            reject(res.data);
          }
        },
        fail(err) {
          reject(err);
        },
      });
    };

    execute();
  });
}

async function handle401() {
  // 如果正在刷新，排队等待
  if (_isRefreshing) {
    return new Promise((resolve, reject) => {
      _refreshQueue.push([resolve, reject]);
    });
  }

  _isRefreshing = true;
  try {
    const success = await tryRefreshToken();
    resolveRefreshQueue(success);
    if (!success) throw new Error('refresh_failed');
  } catch (e) {
    resolveRefreshQueue(false);
    throw e;
  } finally {
    _isRefreshing = false;
  }
}

function redirectToLogin() {
  wx.removeStorageSync('auth_token');
  wx.removeStorageSync('refresh_token');
  wx.removeStorageSync('user');
  app.globalData.token = null;
  app.globalData.userInfo = null;

  wx.reLaunch({ url: '/pages/login/login' });
}

module.exports = {
  // Auth
  sendSms(phone) { return request('auth', { action: 'send-sms', phone }, false); },
  login(phone, code) { return request('auth', { action: 'login', phone, code }, false); },
  wechatLogin(wxCode) { return request('auth', { action: 'wechat-login', code: wxCode }, false); },
  getProfile() { return request('auth', { action: 'profile' }); },
  refreshToken(refreshToken) { return request('auth', { action: 'refresh-token', refreshToken }, false); },

  // Cats
  getNearbyCats(lat, lng, radius = 5000) {
    return request('cats', { action: 'nearby', latitude: lat, longitude: lng, radius }, false);
  },
  getMyCats() { return request('cats', { action: 'my-cats' }); },
  captureCat(catData) { return request('cats', { action: 'capture', catData }); },
  getCatDetail(catId) { return request('cats', { action: 'cat-detail', catId }); },

  // Recognition
  matchCatFace(imageUrl, lat, lng) {
    return request('recognition', { action: 'match', imageUrl, latitude: lat, longitude: lng }, false);
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
