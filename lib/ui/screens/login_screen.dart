import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/v2board_provider.dart';

enum LoginMode { login, register, forgotPassword }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  LoginMode _mode = LoginMode.login;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _verifyCodeController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // 状态
  bool _rememberMe = true;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // 验证码倒计时
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _verifyCodeController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  // 加载保存的账号
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      if (mounted) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    }
  }

  // 保存或清除账号
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
    } else {
      await prefs.remove('saved_email');
    }
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendVerifyCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = "请输入邮箱地址");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success =
          await ref.read(v2boardServiceProvider).sendEmailVerify(email);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('验证码已发送，请检查邮箱')),
          );
          _startCountdown();
        }
      } else {
        setState(() => _errorMessage = "验证码发送失败");
      }
    } catch (e) {
      setState(
          () => _errorMessage = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final v2board = ref.read(v2boardServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_mode == LoginMode.login) {
        final loginResp = await v2board.login(email: email, password: password);
        if (loginResp != null) {
          await _saveCredentials();
          if (mounted) context.go('/');
        } else {
          setState(() => _errorMessage = "登录失败，请检查账号密码");
        }
      } else if (_mode == LoginMode.register) {
        if (password != _confirmPasswordController.text) {
          throw Exception("两次输入的密码不一致");
        }
        final resp = await v2board.register(
          email: email,
          password: password,
          verifyCode: _verifyCodeController.text.trim(),
          inviteCode: _inviteCodeController.text.trim(),
        );
        if (resp != null) {
          await _saveCredentials();
          if (mounted) context.go('/');
        } else {
          setState(() => _errorMessage = "注册失败");
        }
      } else if (_mode == LoginMode.forgotPassword) {
        final success = await v2board.forgetPassword(
          email: email,
          password: password, // user sets new password here
          verifyCode: _verifyCodeController.text.trim(),
        );
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('密码重置成功，请登录')),
            );
            setState(() {
              _mode = LoginMode.login;
              _passwordController.clear();
            });
          }
        } else {
          setState(() => _errorMessage = "重置失败，请检查验证码");
        }
      }
    } catch (e) {
      setState(
          () => _errorMessage = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _title {
    switch (_mode) {
      case LoginMode.login:
        return '账号登录';
      case LoginMode.register:
        return '注册新账号';
      case LoginMode.forgotPassword:
        return '重置密码';
    }
  }

  String get _buttonText {
    switch (_mode) {
      case LoginMode.login:
        return '登 录';
      case LoginMode.register:
        return '注 册';
      case LoginMode.forgotPassword:
        return '重置密码';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 背景色：亮色模式下使用浅灰，深色模式下使用深灰/黑等
    final backgroundColor =
        isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBrandingContent(), // Logo区域
                const SizedBox(height: 32),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _buildForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingContent() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.zap,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome to SLux',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.displayLarge?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your Premium Gateway to the World',
          style: TextStyle(
            fontSize: 14,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    final linkColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Email
        _LoginInput(
          controller: _emailController,
          label: '邮箱账号', // 汉化
          icon: LucideIcons.mail,
          hint: 'user@example.com',
        ),
        const SizedBox(height: 16),

        // Verify Code Area (Register/Forgot)
        if (_mode != LoginMode.login) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _LoginInput(
                  controller: _verifyCodeController,
                  label: '验证码',
                  icon: LucideIcons.shieldCheck,
                  hint: 'Email 验证码',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: (_countdown > 0 || _isLoading)
                      ? null
                      : _handleSendVerifyCode,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: theme.dividerColor),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(_countdown > 0 ? '${_countdown}s' : '发送'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Password
        _LoginInput(
          controller: _passwordController,
          label: _mode == LoginMode.forgotPassword ? '新密码' : '密码', // 汉化
          icon: LucideIcons.lock,
          isPassword: true,
          obscureText: !_showPassword,
          hint: '请输入密码',
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword ? LucideIcons.eye : LucideIcons.eyeOff,
              size: 18,
              color: theme.textTheme.bodySmall?.color,
            ),
            onPressed: () {
              setState(() {
                _showPassword = !_showPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password (Register Only)
        if (_mode == LoginMode.register) ...[
          _LoginInput(
            controller: _confirmPasswordController,
            label: '确认密码',
            icon: LucideIcons.lock,
            isPassword: true,
            obscureText: !_showConfirmPassword,
            hint: '请再次输入密码',
            suffixIcon: IconButton(
              icon: Icon(
                  _showConfirmPassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18),
              onPressed: () =>
                  setState(() => _showConfirmPassword = !_showConfirmPassword),
            ),
          ),
          const SizedBox(height: 16),
          // Invite Code
          _LoginInput(
            controller: _inviteCodeController,
            label: '邀请码 (可选)',
            icon: LucideIcons.ticket,
            hint: '如有邀请码请填写',
          ),
          const SizedBox(height: 16),
        ],

        // Remember Me (Login Only)
        if (_mode == LoginMode.login)
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      _rememberMe = val ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _rememberMe = !_rememberMe;
                  });
                },
                child: Text(
                  '记住账号',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 24),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),

        // Action Button
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _buttonText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),

        const SizedBox(height: 20),

        // Mode Switchers
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_mode == LoginMode.login) ...[
              TextButton(
                onPressed: () => setState(() {
                  _mode = LoginMode.register;
                  _errorMessage = null;
                }),
                child: Text(
                  '注册账号',
                  style: TextStyle(color: linkColor, fontSize: 13),
                ),
              ),
              Text(
                '|',
                style: TextStyle(color: theme.dividerColor),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _mode = LoginMode.forgotPassword;
                  _errorMessage = null;
                }),
                child: Text(
                  '找回密码',
                  style: TextStyle(color: linkColor, fontSize: 13),
                ),
              ),
            ] else ...[
              TextButton(
                onPressed: () => setState(() {
                  _mode = LoginMode.login;
                  _errorMessage = null;
                }),
                child: Text(
                  '返回登录',
                  style: TextStyle(color: linkColor, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LoginInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final String hint;
  final bool obscureText;
  final Widget? suffixIcon;

  const _LoginInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    required this.hint,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? obscureText : false,
            style: TextStyle(
                color: theme.textTheme.bodyMedium?.color, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
              prefixIcon: Icon(
                icon,
                size: 18,
                color: theme.textTheme.bodySmall?.color,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
