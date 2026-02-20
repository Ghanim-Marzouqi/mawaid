import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/strings.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } catch (e) {
      if (mounted) {
        setState(() => _error = Strings.loginError);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.forgotPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              Strings.enterEmailForReset,
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: Strings.email,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final value = emailController.text.trim();
              Navigator.pop(dialogContext, value);
            },
            child: const Text(Strings.send),
          ),
        ],
      ),
    );

    emailController.dispose();

    if (email == null || email.isEmpty || !email.contains('@')) return;

    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.resetPasswordSent),
            backgroundColor: AppColors.confirmed,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.resetPasswordError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 14,
        fontFamily: 'ReadexPro',
      ),
      hintText: hint,
      hintTextDirection: TextDirection.rtl,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      errorStyle: const TextStyle(
        color: AppColors.error,
        fontSize: 12,
        fontFamily: 'ReadexPro',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 380,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _AppLogo(),
                  const SizedBox(height: 20),
                  Text(
                    Strings.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Strings.login,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontFamily: 'ReadexPro',
                    ),
                    decoration: _inputDecoration(
                      label: Strings.email,
                      hint: 'user@mawaid.local',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return Strings.requiredField;
                      }
                      if (!value.contains('@')) {
                        return Strings.invalidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontFamily: 'ReadexPro',
                    ),
                    decoration: _inputDecoration(
                      label: Strings.password,
                      hint: '••••••',
                      icon: Icons.lock_outline,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return Strings.requiredField;
                      }
                      if (value.length < 6) {
                        return Strings.passwordTooShort;
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        Strings.forgotPassword,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'ReadexPro',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(Strings.loginButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double r = s * 0.22; // corner radius

    // --- Background rounded square with gradient ---
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(r),
    );
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1B5E7B), Color(0xFF0D3B4F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, s, s));
    canvas.drawRRect(bgRect, bgPaint);

    // --- Subtle inner shine (top-left arc) ---
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final shinePath = Path()
      ..moveTo(0, 0)
      ..arcToPoint(Offset(s * 0.55, 0), radius: Radius.circular(s * 0.55))
      ..arcToPoint(Offset(0, s * 0.55), radius: Radius.circular(s * 0.55))
      ..close();
    canvas.save();
    canvas.clipRRect(bgRect);
    canvas.drawPath(shinePath, shinePaint);
    canvas.restore();

    // --- Calendar body (white rounded rect) ---
    final calLeft = s * 0.18;
    final calTop = s * 0.28;
    final calRight = s * 0.82;
    final calBottom = s * 0.82;
    final calRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(calLeft, calTop, calRight, calBottom),
      const Radius.circular(6),
    );
    final calPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawRRect(calRRect, calPaint);

    // --- Calendar header band ---
    final headerRRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(calLeft, calTop, calRight, calTop + (calBottom - calTop) * 0.32),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
    );
    final headerPaint = Paint()..color = const Color(0xFF1B5E7B);
    canvas.drawRRect(headerRRect, headerPaint);

    // --- Ring pins at top ---
    final pinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    // Left pin
    canvas.drawLine(
      Offset(s * 0.35, calTop - s * 0.07),
      Offset(s * 0.35, calTop + s * 0.08),
      pinPaint,
    );
    // Right pin
    canvas.drawLine(
      Offset(s * 0.65, calTop - s * 0.07),
      Offset(s * 0.65, calTop + s * 0.08),
      pinPaint,
    );

    // --- Grid dots (2×3) ---
    final dotPaint = Paint()..color = const Color(0xFF1B5E7B).withValues(alpha: 0.6);
    final dotRadius = s * 0.038;
    final gridTop = calTop + (calBottom - calTop) * 0.46;
    final gridBottom = calBottom - s * 0.08;
    final gridLeft = calLeft + s * 0.10;
    final gridRight = calRight - s * 0.10;

    final cols = 3;
    final rows = 2;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = gridLeft + (gridRight - gridLeft) * col / (cols - 1);
        final cy = gridTop + (gridBottom - gridTop) * row / (rows - 1);
        // Highlight first dot (today)
        if (row == 0 && col == 0) {
          final highlightPaint = Paint()..color = const Color(0xFF1B5E7B);
          canvas.drawCircle(Offset(cx, cy), dotRadius * 1.4, highlightPaint);
          canvas.drawCircle(
            Offset(cx, cy),
            dotRadius * 0.7,
            Paint()..color = Colors.white,
          );
        } else {
          canvas.drawCircle(Offset(cx, cy), dotRadius, dotPaint);
        }
      }
    }

    // --- Small clock arc overlay (bottom-right) ---
    final clockCenter = Offset(s * 0.75, s * 0.75);
    final clockR = s * 0.155;
    final clockBgPaint = Paint()..color = const Color(0xFF0D3B4F);
    canvas.drawCircle(clockCenter, clockR, clockBgPaint);

    final clockArcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.028
      ..strokeCap = StrokeCap.round;
    // Clock circle
    canvas.drawCircle(clockCenter, clockR * 0.78, clockArcPaint);
    // Hour hand (pointing to ~10)
    final hourAngle = -math.pi / 2 - math.pi / 6;
    canvas.drawLine(
      clockCenter,
      Offset(
        clockCenter.dx + math.cos(hourAngle) * clockR * 0.45,
        clockCenter.dy + math.sin(hourAngle) * clockR * 0.45,
      ),
      Paint()
        ..color = Colors.white
        ..strokeWidth = s * 0.028
        ..strokeCap = StrokeCap.round,
    );
    // Minute hand (pointing to ~12)
    final minAngle = -math.pi / 2;
    canvas.drawLine(
      clockCenter,
      Offset(
        clockCenter.dx + math.cos(minAngle) * clockR * 0.6,
        clockCenter.dy + math.sin(minAngle) * clockR * 0.6,
      ),
      Paint()
        ..color = Colors.white
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
