const auth = require('../../utils/auth');

Page({
  data: {
    phone: '',
    code: '',
    countdown: 0,
    sending: false,
    loading: false,
    wechatLoading: false,
    error: '',
  },

  _timer: null,

  onUnload() {
    if (this._timer) {
      clearTimeout(this._timer);
      this._timer = null;
    }
  },

  onPhoneInput(e) { this.setData({ phone: e.detail.value }); },
  onCodeInput(e) { this.setData({ code: e.detail.value }); },

  async sendSms() {
    const { phone } = this.data;
    if (phone.length !== 11) {
      this.setData({ error: '请输入正确的手机号' });
      return;
    }
    this.setData({ sending: true, error: '' });
    const result = await auth.sendSms(phone);
    this.setData({ sending: false });
    if (result.ok && result.devCode) {
      this.setData({ code: result.devCode, countdown: 60 });
      this._tick();
    } else if (result.ok) {
      this.setData({ countdown: 60 });
      this._tick();
    } else {
      this.setData({ error: result.error || '发送失败' });
    }
  },

  _tick() {
    if (this.data.countdown <= 0) return;
    this._timer = setTimeout(() => {
      this.setData({ countdown: this.data.countdown - 1 });
      this._tick();
    }, 1000);
  },

  async doLogin() {
    const { phone, code } = this.data;
    if (phone.length !== 11 || code.length !== 6) {
      this.setData({ error: '请输入手机号和验证码' });
      return;
    }
    this.setData({ loading: true, error: '' });
    const result = await auth.login(phone, code);
    this.setData({ loading: false });
    if (result.ok) {
      wx.switchTab({ url: '/pages/explore/explore' });
    } else {
      this.setData({ error: result.error || '登录失败' });
    }
  },

  async doWechatLogin() {
    this.setData({ wechatLoading: true, error: '' });
    const result = await auth.wechatLogin();
    this.setData({ wechatLoading: false });
    if (result.ok) {
      wx.switchTab({ url: '/pages/explore/explore' });
    } else {
      this.setData({ error: result.error || '微信登录失败' });
    }
  },
});
