import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

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
              colors: <Color>[AppColors.siam, AppColors.siam.withValues(alpha: 0.72)],
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
          child: Icon(
            Icons.description_outlined,
            size: size * 0.56,
            color: AppColors.white,
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
