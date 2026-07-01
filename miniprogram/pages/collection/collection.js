const api = require('../../utils/api');

Page({
  data: { cats: [], loading: false },

  onShow() { this.loadMyCats(); },

  async loadMyCats() {
    this.setData({ loading: true });
    try {
      const res = await api.getMyCats();
      if (res.code === 200) {
        this.setData({ cats: res.data || [], loading: false });
      } else {
        this.setData({ loading: false });
      }
    } catch (_) {
      this.setData({ loading: false });
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
