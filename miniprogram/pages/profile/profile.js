const auth = require('../../utils/auth');
const api = require('../../utils/api');

Page({
  data: { user: {}, cats: [], totalBattles: 0, totalWins: 0 },

  onShow() {
    const user = auth.getUser() || {};
    this.setData({ user });
    this.loadStats();
  },

  async loadStats() {
    try {
      const res = await api.getMyCats();
      if (res.code === 200 && res.data) {
        const cats = res.data;
        const totalBattles = cats.reduce((s, c) => s + (c.totalBattles || 0), 0);
        const totalWins = cats.reduce((s, c) => s + (c.totalWins || 0), 0);
        this.setData({ cats, totalBattles, totalWins });
      }
    } catch (_) {}
  },

  logout() {
    auth.logout();
    wx.reLaunch({ url: '/pages/login/login' });
  },
});
