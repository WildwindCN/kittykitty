const auth = require('../../utils/auth');

Page({
  onLoad() {
    // 已登录直接进探索页
    if (auth.isLoggedIn()) {
      wx.switchTab({ url: '/pages/explore/explore' });
    }
  },

  start() {
    if (auth.isLoggedIn()) {
      wx.switchTab({ url: '/pages/explore/explore' });
    } else {
      wx.navigateTo({ url: '/pages/login/login' });
    }
  },
});
