const api = require('../../utils/api');
const image = require('../../utils/image');

Page({
  data: { cats: [], loading: false },

  onShow() { this.loadMyCats(); },

  async loadMyCats() {
    this.setData({ loading: true });
    try {
      const res = await api.getMyCats();
      if (res.code === 200 && res.data) {
        const cats = res.data || [];
        const fileIDs = cats.map(c => c.imageUrl).filter(Boolean);
        const urlMap = fileIDs.length > 0 ? await image.getTempUrls(fileIDs) : {};
        const catsWithUrls = cats.map(c => ({
          ...c,
          imageUrl: urlMap[c.imageUrl] || c.imageUrl,
        }));
        this.setData({ cats: catsWithUrls, loading: false });
      } else {
        this.setData({ loading: false });
      }
    } catch (_) {
      this.setData({ loading: false });
    }
  },

  // 下拉刷新
  onPullDownRefresh() {
    this.loadMyCats().then(() => wx.stopPullDownRefresh());
  },

  rarityLabel(r) {
    return { legendary: '传说', epic: '史诗', rare: '稀有', common: '普通' }[r] || '普通';
  },

  goDetail(e) {
    const id = e.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/card/card?id=${id}` });
  },
});
