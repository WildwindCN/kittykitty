import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// 登录页面 — 手机号 + 验证码 + 微信登录
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSendingSms = false;
  int _countdown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _phone => _phoneController.text.trim();
  String get _code => _codeController.text.trim();

  bool get _canSendSms =>
      _phone.length == 11 && _countdown == 0 && !_isSendingSms;

  bool get _canLogin =>
      _phone.length == 11 && _code.length == 6;

  Future<void> _sendSms() async {
    if (!_canSendSms) return;

    setState(() => _isSendingSms = true);
    final devCode = await ref.read(authProvider.notifier).sendSms(_phone);
    setState(() => _isSendingSms = false);

    if (devCode != null) {
      // 开发环境自动填入验证码
      _codeController.text = devCode;
      setState(() => _countdown = 60);
      _startCountdown();
    } else {
      setState(() => _countdown = 60);
      _startCountdown();
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          _startCountdown();
        }
      });
    });
  }

  Future<void> _login() async {
    if (!_canLogin) return;
    await ref.read(authProvider.notifier).loginWithPhone(_phone, _code);
  }

  Future<void> _wechatLogin() async {
    final wechatService = ref.read(wechatServiceProvider);
    final result = await wechatService.login();

    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? '微信登录需在真机运行')),
      );
      return;
    }

    // code 换 token
    final loginResult = await wechatService.completeLogin(result.code);
    if (!mounted) return;

    if (loginResult.isSuccess && loginResult.data != null) {
      ref.read(authProvider.notifier).setWechatLoginResult(loginResult.data!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loginResult.message ?? '微信登录失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // 监听登录成功跳转
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        // 登录成功，路由由 go_router 自动处理
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 80),
              // Logo
              Icon(
                Icons.pets,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'KittyKitty',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '发现身边的猫咪，开始收集之旅',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 56),

              // 手机号输入
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入手机号',
                  prefixIcon: const Icon(Icons.phone_android),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white.withAlpha(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 验证码输入 + 发送按钮
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: '验证码',
                        hintText: '6位验证码',
                        prefixIcon: const Icon(Icons.message),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withAlpha(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _canSendSms ? _sendSms : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        disabledBackgroundColor: Colors.white.withAlpha(25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSendingSms
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _countdown > 0 ? '${_countdown}s' : '获取验证码',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 错误提示
              if (authState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    authState.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),

              const SizedBox(height: 24),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    disabledBackgroundColor: theme.colorScheme.primary.withAlpha(100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '登录',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // 分隔线
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '其他登录方式',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 24),

              // 微信登录
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _wechatLogin,
                  icon: const Icon(Icons.wechat, color: Color(0xFF07C160)),
                  label: const Text(
                    '微信登录',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF07C160), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 隐私政策
              Text(
                '登录即表示同意《用户协议》和《隐私政策》',
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
