// KittyKitty 微信小程序 — 入口文件

function base64UrlDecode(str) {
  // 转为标准 base64
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) base64 += '=';
  // 纯 JS base64 decode（微信小程序无 atob）
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  let output = '';
  for (let i = 0; i < base64.length; i += 4) {
    const a = chars.indexOf(base64[i]);
    const b = chars.indexOf(base64[i + 1]);
    const c = chars.indexOf(base64[i + 2]);
    const d = chars.indexOf(base64[i + 3]);
    output += String.fromCharCode((a << 2) | (b >> 4));
    if (c !== 64) output += String.fromCharCode(((b & 15) << 4) | (c >> 2));
    if (d !== 64) output += String.fromCharCode(((c & 3) << 6) | d);
  }
  return decodeURIComponent(escape(output));
}

App({
  globalData: {
    // CloudBase 环境配置 (与 Flutter 共用同一环境)
    envId: 'kittykitty-d0go1pcqbe5e83de6',
    apiBaseUrl: 'https://kittykitty-d0go1pcqbe5e83de6.service.tcloudbase.com',
    token: null,
    userInfo: null,
  },

  onLaunch() {
    if (wx.cloud) {
      wx.cloud.init({
        env: this.globalData.envId,
        traceUser: true,
      });
    }
    const token = wx.getStorageSync('auth_token');
    if (token) {
      try {
        const payload = JSON.parse(base64UrlDecode(token.split('.')[1]));
        if (payload.exp && payload.exp * 1000 > Date.now()) {
          this.globalData.token = token;
        } else {
          wx.removeStorageSync('auth_token');
          wx.removeStorageSync('refresh_token');
          wx.removeStorageSync('user');
        }
      } catch (_) {
        this.globalData.token = token;
      }
    }
  },
});
