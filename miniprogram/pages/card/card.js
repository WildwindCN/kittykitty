const api = require('../../utils/api');
const image = require('../../utils/image');

Page({
  data: { cat: null, imageSrc: '', cp: 0, stats: [] },

  onLoad(options) {
    this._shareParams = options;
    if (options.id) this.loadCat(options.id);
  },

  async loadCat(id) {
    try {
      let cat = null;
      try {
        const detailRes = await api.getCatDetail(id);
        if (detailRes.code === 200 && detailRes.data) {
          cat = detailRes.data;
        }
      } catch (_) {}

      // 回退1：从自己的图鉴列表中查找
      if (!cat) {
        const res = await api.getMyCats();
        if (res.code === 200 && res.data) {
          cat = (res.data || []).find(c => c._id === id || c.id === id);
        }
      }

      // 回退2：从 explore 页暂存的数据（别人的猫）
      if (!cat) {
        const cached = getApp().globalData._viewingCat;
        if (cached && ((cached._id || cached.id) === id)) {
          cat = cached;
        }
        getApp().globalData._viewingCat = null;
      }

      // 回退3：从分享链接参数构建基础卡片
      if (!cat && this._shareParams && this._shareParams.name) {
        cat = {
          _id: id, id: id,
          name: decodeURIComponent(this._shareParams.name),
          rarity: this._shareParams.rarity || 'common',
          cp: parseInt(this._shareParams.cp) || 0,
        };
      }

      if (cat) {
        this.setData({
          cat,
          cp: cat.cp || this.calcCp(cat),
          stats: this.buildStats(cat),
        });
        const rawUrl = cat.cardImageUrl || cat.imageUrl;
        if (rawUrl) {
          if (rawUrl.startsWith('cloud://')) {
            this.loadImage(rawUrl);
          } else {
            this.setData({ imageSrc: rawUrl });
          }
        }
      }
    } catch (_) {}
  },

  async loadImage(fileID) {
    const url = await image.getTempUrl(fileID);
    if (url) this.setData({ imageSrc: url });
  },

  calcCp(cat) {
    const raw = (cat.baseHp || 80) * 0.4 + (cat.baseAtk || 50) * 1.2 + (cat.baseDef || 40) * 0.8 + (cat.baseSpd || 50) * 0.6;
    const mult = { common: 1.0, rare: 1.3, epic: 1.7, legendary: 2.2 }[cat.rarity] || 1.0;
    return Math.round(raw * mult);
  },

  buildStats(cat) {
    return [
      { label: 'HP', value: this.scaleStat(cat.baseHp, cat.level), pct: Math.min(100, Math.round((cat.baseHp || 80) / 180 * 100)), color: '#FF6B6B', suffix: '' },
      { label: 'ATK', value: this.scaleStat(cat.baseAtk, cat.level), pct: Math.min(100, Math.round((cat.baseAtk || 50) / 140 * 100)), color: '#FFA726', suffix: '' },
      { label: 'DEF', value: this.scaleStat(cat.baseDef, cat.level), pct: Math.min(100, Math.round((cat.baseDef || 40) / 115 * 100)), color: '#42A5F5', suffix: '' },
      { label: 'SPD', value: this.scaleStat(cat.baseSpd, cat.level), pct: Math.min(100, Math.round((cat.baseSpd || 50) / 125 * 100)), color: '#66BB6A', suffix: '' },
      { label: 'CRIT', value: Math.round((cat.baseCrit || 0.05) * 100), pct: Math.min(100, Math.round((cat.baseCrit || 0.05) * 100 / 15 * 100)), color: '#AB47BC', suffix: '%' },
    ];
  },

  scaleStat(base, level) { return Math.round(base * (1 + 0.02 * ((level || 1) - 1))); },

  rarityLabel(r) {
    return { legendary: '传说', epic: '史诗', rare: '稀有', common: '普通' }[r] || '普通';
  },

  startBattle() {
    if (this.data.cat && (this.data.cat._id || this.data.cat.id)) {
      wx.navigateTo({ url: `/pages/battle/battle?id=${this.data.cat._id || this.data.cat.id}` });
    }
  },

  // 分享
  onShareAppMessage() {
    const cat = this.data.cat;
    if (!cat) return { title: 'KittyKitty', path: '/pages/index/index' };
    return {
      title: `我抓到了 ${cat.name}！`,
      path: `/pages/card/card?id=${cat._id || cat.id}&name=${encodeURIComponent(cat.name || '')}&rarity=${cat.rarity || 'common'}&cp=${cat.cp || 0}`,
    };
  },
});
