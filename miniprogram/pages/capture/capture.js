const api = require('../../utils/api');
const generator = require('../../utils/generator');

Page({
  data: {
    capturing: false,
    processing: false,
    progress: 0,
    stepText: '正在上传...',
  },

  async takePhoto() {
    if (this.data.capturing) return;
    this.setData({ capturing: true });

    try {
      // 拍照
      const ctx = wx.createCameraContext();
      const { tempImagePath } = await new Promise((resolve, reject) => {
        ctx.takePhoto({ quality: 'high', success: resolve, fail: reject });
      });
      this.setData({ capturing: false, processing: true, progress: 10, stepText: '正在上传图片...' });

      // 上传到云存储
      const uploadRes = await wx.cloud.uploadFile({
        cloudPath: `cats/${Date.now()}_${Math.random().toString(36).slice(2,8)}.jpg`,
        filePath: tempImagePath,
      });
      this.setData({ progress: 40, stepText: '正在识别猫咪特征...' });

      // 获取临时链接用于识别
      const { fileList } = await wx.cloud.getTempFileURL({ fileList: [uploadRes.fileID] });
      const imageUrl = fileList[0].tempFileURL;

      // 获取位置
      let lat = 0, lng = 0;
      try {
        const pos = await new Promise((r, j) => wx.getLocation({ type: 'gcj02', success: r, fail: j }));
        lat = pos.latitude; lng = pos.longitude;
      } catch (_) {}

      // DINOv2 特征提取
      let featureVector = null;
      try {
        const matchRes = await api.matchCatFace(imageUrl, lat, lng);
        if (matchRes.code === 200 && matchRes.data) {
          featureVector = matchRes.data.featureVector;
        }
      } catch (_) {}

      this.setData({ progress: 70, stepText: '正在生成猫咪属性...' });

      // 生成猫咪
      const cat = generator.generateCat({
        id: `cat_${Date.now()}`,
        imageUrl: uploadRes.fileID,
        captureLocation: { latitude: lat, longitude: lng },
      });

      // 入库
      const catData = {
        name: cat.name, rarity: cat.rarity, type: cat.type,
        baseHp: cat.baseHp, baseAtk: cat.baseAtk, baseDef: cat.baseDef, baseSpd: cat.baseSpd, baseCrit: cat.baseCrit,
        imageUrl: uploadRes.fileID, battleSkills: [], lifeSkills: [],
        captureLocation: { latitude: lat, longitude: lng },
        level: 1, exp: 0,
      };
      if (featureVector) catData.featureVector = featureVector;

      await api.captureCat(catData);
      this.setData({ progress: 100, stepText: '完成！' });

      setTimeout(() => {
        wx.switchTab({ url: '/pages/collection/collection' });
      }, 500);
    } catch (e) {
      console.error(e);
      wx.showToast({ title: e.errMsg || '处理失败', icon: 'none' });
      this.setData({ capturing: false, processing: false });
    }
  },
});
