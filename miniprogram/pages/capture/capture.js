const api = require('../../utils/api');
const generator = require('../../utils/generator');

Page({
  data: {
    capturing: false,
    processing: false,
    progress: 0,
    stepText: '',
    error: '',
    cameraAuthorized: true,
  },

  onShow() {
    this._aborted = false;
    this.setData({ capturing: false, processing: false, progress: 0, stepText: '', error: '' });
  },

  onError() {
    this.setData({ cameraAuthorized: false, error: '相机授权失败，请在设置中开启相机权限' });
  },

  async takePhoto() {
    if (this.data.capturing || this.data.processing) return;
    this._aborted = false;
    this.setData({ capturing: true, error: '' });

    try {
      const ctx = wx.createCameraContext();
      const { tempImagePath } = await new Promise((resolve, reject) => {
        ctx.takePhoto({ quality: 'high', success: resolve, fail: reject });
      });
      if (this._aborted) return;

      this.setData({ capturing: false, processing: true, progress: 10, stepText: '正在上传图片...' });

      let uploadRes;
      try {
        uploadRes = await wx.cloud.uploadFile({
          cloudPath: `cats/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.jpg`,
          filePath: tempImagePath,
        });
      } catch (e) {
        throw new Error('图片上传失败: ' + (e.errMsg || '未知错误'));
      }
      if (this._aborted) return;

      this.setData({ progress: 30, stepText: '正在获取图片链接...' });

      const { fileList } = await wx.cloud.getTempFileURL({ fileList: [uploadRes.fileID] });
      const imageUrl = fileList[0] && fileList[0].tempFileURL;
      if (!imageUrl) throw new Error('图片链接获取失败');
      if (this._aborted) return;

      this.setData({ progress: 40, stepText: '正在获取位置...' });

      let lat = 0, lng = 0;
      try {
        const pos = await new Promise((r, j) => wx.getLocation({ type: 'gcj02', success: r, fail: j }));
        lat = pos.latitude; lng = pos.longitude;
      } catch (_) {}
      if (this._aborted) return;

      this.setData({ progress: 50, stepText: '正在识别猫咪特征...' });

      let featureVector = null;
      if (imageUrl) {
        try {
          const matchRes = await api.matchCatFace(imageUrl, lat, lng);
          if (matchRes.code === 200 && matchRes.data) {
            featureVector = matchRes.data.featureVector;
          }
        } catch (_) {}
      }
      if (this._aborted) return;

      this.setData({ progress: 70, stepText: '正在生成猫咪属性...' });

      const cat = generator.generateCat({
        id: `cat_${Date.now()}`,
        imageUrl: imageUrl,
        captureLocation: { latitude: lat, longitude: lng },
      });

      const catData = {
        name: cat.name, rarity: cat.rarity, type: cat.type,
        baseHp: cat.baseHp, baseAtk: cat.baseAtk, baseDef: cat.baseDef, baseSpd: cat.baseSpd, baseCrit: cat.baseCrit,
        cp: cat.cp, imageUrl: imageUrl,
        battleSkills: cat.battleSkills, lifeSkills: cat.lifeSkills,
        captureLocation: { latitude: lat, longitude: lng },
        level: 1, exp: 0,
      };
      if (featureVector) catData.featureVector = featureVector;
      if (this._aborted) return;

      this.setData({ progress: 85, stepText: '正在保存...' });

      await api.captureCat(catData);
      if (this._aborted) return;

      this.setData({ progress: 100, stepText: '捕捉成功！' });

      setTimeout(() => {
        if (!this._aborted) wx.switchTab({ url: '/pages/collection/collection' });
      }, 600);
    } catch (e) {
      if (this._aborted) return;
      console.error('Capture error:', e);
      this.setData({
        capturing: false, processing: false,
        error: (e && e.message) || '处理失败，请重试',
      });
      wx.showToast({ title: (e && e.message) || '处理失败', icon: 'none' });
    }
  },

  cancelProcessing() {
    this._aborted = true;
    this.setData({ processing: false, capturing: false, progress: 0, stepText: '', error: '' });
  },
});
