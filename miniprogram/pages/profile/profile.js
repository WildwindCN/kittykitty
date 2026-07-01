const auth = require('../../utils/auth');
const api = require('../../utils/api');

Page({
  data: {
    user: {},
    cats: [],
    totalBattles: 0,
    totalWins: 0,
    strongestCat: null,
  },

  onShow() {
    const user = auth.getUser() || {};
    this.setData({ user });
    this.loadStats();
  },

  async loadStats() {
    try {
      const [catsRes, battleRes] = await Promise.all([
        api.getMyCats(),
        api.getBattleHistory(),
      ]);

      if (catsRes.code === 200 && catsRes.data) {
        const cats = catsRes.data;
        const strongest = cats.length > 0
          ? cats.reduce((a, b) => ((a.cp || 0) >= (b.cp || 0) ? a : b))
          : null;
        this.setData({ cats, strongestCat: strongest });
      }

      if (battleRes.code === 200 && battleRes.data) {
        const battles = battleRes.data;
        this.setData({
          totalBattles: battles.length,
          totalWins: battles.filter(b => b.won).length,
        });
      }
    } catch (_) {}
  },

  // 下拉刷新
  onPullDownRefresh() {
    this.loadStats().then(() => wx.stopPullDownRefresh());
  },

  logout() {
    wx.showModal({
      title: '确认退出',
      content: '退出登录后需要重新验证',
      success: (res) => {
        if (res.confirm) {
          auth.logout();
          wx.reLaunch({ url: '/pages/login/login' });
        }
      },
    });
  },
});
