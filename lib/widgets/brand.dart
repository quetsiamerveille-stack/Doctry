import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Logo applicatif DOCTRY : badge degrade, QR code stylise au centre,
/// coin document releve et vaguelette de protection.
class DoctryLogo extends StatelessWidget {
  const DoctryLogo({super.key, this.size = 96, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color first = dark ? AppColors.white : AppColors.darkBlue;
    final Color second = AppColors.gold;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.siam, AppColors.darkBlue],
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.siam.withValues(alpha: 0.35),
                blurRadius: size * 0.28,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
          child: CustomPaint(
            size: Size.square(size),
            painter: _DoctryLogoPainter(size: size),
          ),
        ),
        SizedBox(height: size * 0.22),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w900,
              letterSpacing: size * 0.035,
            ),
            children: <InlineSpan>[
              TextSpan(text: 'DOC', style: TextStyle(color: first)),
              TextSpan(text: 'TRY', style: TextStyle(color: second)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctryLogoPainter extends CustomPainter {
  _DoctryLogoPainter({required this.size});

  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final double s = size;
    final Paint white = Paint()..color = AppColors.white;

    // --- Document (coin plie en haut a droite) ---
    final Path document = Path()
      ..moveTo(s * 0.24, s * 0.18)
      ..lineTo(s * 0.62, s * 0.18)
      ..lineTo(s * 0.76, s * 0.32)
      ..lineTo(s * 0.76, s * 0.82)
      ..lineTo(s * 0.24, s * 0.82)
      ..close();
    final Path fold = Path()
      ..moveTo(s * 0.62, s * 0.18)
      ..lineTo(s * 0.62, s * 0.32)
      ..lineTo(s * 0.76, s * 0.32)
      ..close();
    canvas.drawPath(document, white);
    final Paint foldPaint = Paint()..color = AppColors.gold.withValues(alpha: 0.9);
    canvas.drawPath(fold, foldPaint);

    // --- QR stylise au centre du document ---
    final double qrTop = s * 0.38;
    final double qrLeft = s * 0.30;
    final double qrSize = s * 0.32;
    final double eye = qrSize * 0.34;
    final Paint qrPaint = Paint()..color = AppColors.darkBlue;

    // Coin superieur gauche du QR
    canvas.drawRect(Rect.fromLTWH(qrLeft, qrTop, eye, eye), qrPaint);
    canvas.drawRect(
      Rect.fromLTWH(qrLeft + eye * 0.28, qrTop + eye * 0.28, eye * 0.44, eye * 0.44),
      white,
    );
    // Coin superieur droit
    canvas.drawRect(Rect.fromLTWH(qrLeft + qrSize - eye, qrTop, eye, eye), qrPaint);
    canvas.drawRect(
      Rect.fromLTWH(
        qrLeft + qrSize - eye + eye * 0.28,
        qrTop + eye * 0.28,
        eye * 0.44,
        eye * 0.44,
      ),
      white,
    );
    // Coin inferieur gauche
    canvas.drawRect(Rect.fromLTWH(qrLeft, qrTop + qrSize - eye, eye, eye), qrPaint);
    canvas.drawRect(
      Rect.fromLTWH(
        qrLeft + eye * 0.28,
        qrTop + qrSize - eye + eye * 0.28,
        eye * 0.44,
        eye * 0.44,
      ),
      white,
    );
    // Points centraux du QR
    final double dot = qrSize * 0.10;
    canvas.drawRect(Rect.fromLTWH(qrLeft + qrSize * 0.52, qrTop + qrSize * 0.10, dot, dot), qrPaint);
    canvas.drawRect(Rect.fromLTWH(qrLeft + qrSize * 0.74, qrTop + qrSize * 0.32, dot, dot), qrPaint);
    canvas.drawRect(Rect.fromLTWH(qrLeft + qrSize * 0.52, qrTop + qrSize * 0.52, dot * 1.6, dot), qrPaint);
    canvas.drawRect(Rect.fromLTWH(qrLeft + qrSize * 0.10, qrTop + qrSize * 0.72, dot, dot), qrPaint);
    canvas.drawRect(Rect.fromLTWH(qrLeft + qrSize * 0.74, qrTop + qrSize * 0.74, dot, dot), qrPaint);

    // --- Bouclier / coche de protection en bas ---
    final Path check = Path()
      ..moveTo(s * 0.30, s * 0.70)
      ..lineTo(s * 0.42, s * 0.82)
      ..lineTo(s * 0.66, s * 0.56);
    final Paint checkPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(check, checkPaint);

    // --- Halo (pointille du badge) ---
    final Paint dotPaint = Paint()..color = AppColors.gold.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(s * 0.82, s * 0.20), s * 0.030, dotPaint);
    canvas.drawCircle(Offset(s * 0.16, s * 0.42), s * 0.022, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _DoctryLogoPainter oldDelegate) => oldDelegate.size != size;
}

class DoctryMark extends StatelessWidget {
  const DoctryMark({super.key, this.radius = 22});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: radius * 0.52, fontWeight: FontWeight.w900),
            children: const <InlineSpan>[
              TextSpan(text: 'Doc', style: TextStyle(color: AppColors.darkBlue)),
              TextSpan(text: 'Try', style: TextStyle(color: AppColors.siam)),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF4F6FA), Color(0xFFE7EDF6), Color(0xFFF4F6FA)],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.children, this.scrollable = true});

  final List<Widget> children;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final Widget content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );

    if (!scrollable) {
      return AuthBackground(child: content);
    }

    return AuthBackground(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 48),
          child: content,
        ),
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
