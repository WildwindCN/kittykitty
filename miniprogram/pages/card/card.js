const api = require('../../utils/api');

Page({
  data: { cat: null, imageSrc: '', cp: 0, stats: [] },

  onLoad(options) {
    if (options.id) this.loadCat(options.id);
  },

  async loadCat(id) {
    try {
      // 先从本地图鉴缓存找
      const res = await api.getMyCats();
      if (res.code === 200) {
        const cat = (res.data || []).find(c => c._id === id || c.id === id);
        if (cat) {
          this.setData({
            cat,
            cp: cat.cp || this.calcCp(cat),
            stats: this.buildStats(cat),
          });
          // 加载图片
          if (cat.imageUrl) {
            this.loadImage(cat.imageUrl);
          }
        }
      }
    } catch (_) {}
  },

  loadImage(fileID) {
    wx.cloud.getTempFileURL({ fileList: [fileID] }).then(res => {
      if (res.fileList[0] && res.fileList[0].tempFileURL) {
        this.setData({ imageSrc: res.fileList[0].tempFileURL });
      }
    }).catch(() => {});
  },

  calcCp(cat) {
    const raw = (cat.baseHp || 80) * 0.4 + (cat.baseAtk || 50) * 1.2 + (cat.baseDef || 40) * 0.8 + (cat.baseSpd || 50) * 0.6;
    const mult = { common: 1.0, rare: 1.3, epic: 1.7, legendary: 2.2 }[cat.rarity] || 1.0;
    return Math.round(raw * mult);
  },

  buildStats(cat) {
    return [
      { label: 'HP', value: this.scaleStat(cat.baseHp, cat.level), pct: 60, color: '#FF6B6B', suffix: '' },
      { label: 'ATK', value: this.scaleStat(cat.baseAtk, cat.level), pct: 55, color: '#FFA726', suffix: '' },
      { label: 'DEF', value: this.scaleStat(cat.baseDef, cat.level), pct: 50, color: '#42A5F5', suffix: '' },
      { label: 'SPD', value: this.scaleStat(cat.baseSpd, cat.level), pct: 50, color: '#66BB6A', suffix: '' },
      { label: 'CRIT', value: Math.round((cat.baseCrit || 0.05) * 100), pct: 12, color: '#AB47BC', suffix: '%' },
    ];
  },

  scaleStat(base, level) { return Math.round(base * (1 + 0.02 * ((level || 1) - 1))); },

  rarityLabel(r) {
    return { legendary: '传说', epic: '史诗', rare: '稀有', common: '普通' }[r] || '普通';
  },

  startBattle() {
    if (this.data.cat && this.data.cat._id) {
      wx.navigateTo({ url: `/pages/battle/battle?id=${this.data.cat._id}` });
    }
  },
});
