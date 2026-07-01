const api = require('../../utils/api');
const image = require('../../utils/image');

Page({
  data: { cats: [], loading: true, error: '' },

  onShow() { this.loadNearby(); },

  async loadNearby() {
    this.setData({ loading: true, error: '' });
    try {
      const pos = await new Promise((resolve, reject) => {
        wx.getLocation({ type: 'gcj02', success: resolve, fail: reject });
      }).catch(() => ({ latitude: 31.23, longitude: 121.47 }));

      const res = await api.getNearbyCats(pos.latitude, pos.longitude, 10000);
      if (res.code === 200 && res.data) {
        const cats = res.data || [];
        // 批量转换图片 fileID → 临时 URL
        const fileIDs = cats.map(c => c.imageUrl).filter(Boolean);
        const urlMap = fileIDs.length > 0 ? await image.getTempUrls(fileIDs) : {};
        const catsWithUrls = cats.map(c => ({
          ...c,
          imageUrl: urlMap[c.imageUrl] || c.imageUrl,
        }));
        this.setData({ cats: catsWithUrls, loading: false });
      } else {
        this.setData({ error: res.message || '加载失败', loading: false });
      }
    } catch (e) {
      this.setData({ error: e.errMsg || '网络错误', loading: false });
    }
  },

  // 下拉刷新
  onPullDownRefresh() {
    this.loadNearby().then(() => wx.stopPullDownRefresh());
  },

  rarityLabel(r) {
    return { legendary: '传说', epic: '史诗', rare: '稀有', common: '普通' }[r] || '普通';
  },

  goDetail(e) {
    const id = e.currentTarget.dataset.id;
    if (id) wx.navigateTo({ url: `/pages/card/card?id=${id}` });
  },
});
