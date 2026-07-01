const api = require('../../utils/api');

Page({
  data: { cats: [], loading: true, error: '' },

  onShow() { this.loadNearby(); },

  async loadNearby() {
    this.setData({ loading: true, error: '' });
    try {
      // 获取 GPS 位置
      const pos = await new Promise((resolve, reject) => {
        wx.getLocation({ type: 'gcj02', success: resolve, fail: reject });
      }).catch(() => ({ latitude: 31.23, longitude: 121.47 }));

      const res = await api.getNearbyCats(pos.latitude, pos.longitude, 10000);
      if (res.code === 200) {
        this.setData({ cats: res.data || [], loading: false });
      } else {
        this.setData({ error: res.message || '加载失败', loading: false });
      }
    } catch (e) {
      this.setData({ error: e.errMsg || '网络错误', loading: false });
    }
  },

  rarityLabel(r) {
    return { legendary: '传说', epic: '史诗', rare: '稀有', common: '普通' }[r] || '普通';
  },

  goDetail(e) {
    const id = e.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/card/card?id=${id}` });
  },
});
