// 认证管理
const api = require('./api');
const app = getApp();

module.exports = {
  async login(phone, code) {
    const res = await api.login(phone, code);
    if (res.code === 200 && res.data) {
      app.globalData.token = res.data.token;
      app.globalData.userInfo = res.data.user;
      wx.setStorageSync('auth_token', res.data.token);
      wx.setStorageSync('refresh_token', res.data.refreshToken);
      wx.setStorageSync('user', res.data.user);
      return { ok: true, user: res.data.user };
    }
    return { ok: false, error: res.message };
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
