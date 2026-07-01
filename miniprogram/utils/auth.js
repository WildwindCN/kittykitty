// 认证管理
const api = require('./api');
const app = getApp();

module.exports = {
  async login(phone, code) {
    const res = await api.login(phone, code);
    return handleAuthResponse(res);
  },

  async wechatLogin() {
    // 获取微信登录 code
    const { code } = await new Promise((resolve, reject) => {
      wx.login({ success: resolve, fail: reject });
    });
    if (!code) return { ok: false, error: '微信登录失败' };

    const res = await api.wechatLogin(code);
    return handleAuthResponse(res);
  },

  async sendSms(phone) {
    const res = await api.sendSms(phone);
    return { ok: res.code === 200, devCode: res.devCode, error: res.message };
  },

  logout() {
    app.globalData.token = null;
    app.globalData.userInfo = null;
    wx.removeStorageSync('auth_token');
    wx.removeStorageSync('refresh_token');
    wx.removeStorageSync('user');
  },

  isLoggedIn() {
    return !!app.globalData.token;
  },

  getUser() {
    return app.globalData.userInfo || wx.getStorageSync('user');
  },
};

function handleAuthResponse(res) {
  if (res.code === 200 && res.data) {
    app.globalData.token = res.data.token;
    app.globalData.userInfo = res.data.user;
    wx.setStorageSync('auth_token', res.data.token);
    wx.setStorageSync('refresh_token', res.data.refreshToken);
    wx.setStorageSync('user', res.data.user);
    return { ok: true, user: res.data.user };
  }
  return { ok: false, error: res.message };
}
