// KittyKitty 微信小程序 — 入口文件
App({
  globalData: {
    // CloudBase 环境配置 (与 Flutter 共用同一环境)
    envId: 'kittykitty-d0go1pcqbe5e83de6',
    apiBaseUrl: 'https://kittykitty-d0go1pcqbe5e83de6.service.tcloudbase.com',
    token: null,
    userInfo: null,
  },

  onLaunch() {
    // 初始化 CloudBase
    if (wx.cloud) {
      wx.cloud.init({
        env: this.globalData.envId,
        traceUser: true,
      });
    }
    // 检查登录状态
    const token = wx.getStorageSync('auth_token');
    if (token) {
      this.globalData.token = token;
    }
  },
});
