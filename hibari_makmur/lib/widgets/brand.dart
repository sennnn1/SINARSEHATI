import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

class LogoSinarSehati extends StatelessWidget {
  const LogoSinarSehati({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/logo.svg', width: size, height: size * 210 / 260);
}

/// Logo + nama toko + subjudul emas.
class BrandBlock extends StatelessWidget {
  const BrandBlock({super.key, this.logoSize = 120, this.judulSize = 32});

  final double logoSize;
  final double judulSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoSinarSehati(size: logoSize),
        SizedBox(height: judulSize * 0.3),
        Text(
          'SINAR SEHATI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: judulSize,
            fontWeight: FontWeight.w800,
            letterSpacing: judulSize * 0.06,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'TOKO PERKAKAS & KUNCI PINTU',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.brandGold,
            fontSize: (judulSize * 0.34).clamp(9, 14).toDouble(),
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
