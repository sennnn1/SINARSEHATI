import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand.dart';

/// Tampilan dua panel (branding kiri, form kanan) seperti desain SIGN/login.html.
/// Di layar sempit (HP) panel kiri diganti header kecil di atas form.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  static const _gradien = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xEB0F172A), Color(0xE0156143)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final lebar = c.maxWidth >= 900;
          final form = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: child),
            ),
          );
          if (!lebar) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(gradient: _gradien, color: AppColors.brandNavy),
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 20, 16, 20),
                  child: const BrandBlock(logoSize: 70, judulSize: 22),
                ),
                Expanded(child: form),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(color: AppColors.brandNavy, gradient: _gradien),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      const Positioned(top: -120, left: -120, child: _Lingkaran(360)),
                      const Positioned(bottom: -160, right: -100, child: _Lingkaran(440)),
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const BrandBlock(logoSize: 200, judulSize: 40),
                                const SizedBox(height: 48),
                                Container(height: 1, color: Colors.white24),
                                const SizedBox(height: 28),
                                const Row(
                                  children: [
                                    _Fitur(Icons.check_circle_outline, 'Produk Berkualitas'),
                                    _Fitur(Icons.sell_outlined, 'Harga Terbaik'),
                                    _Fitur(Icons.local_shipping_outlined, 'Pelayanan Cepat'),
                                    _Fitur(Icons.handshake_outlined, 'Terpercaya'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }
}

/// Lingkaran transparan sebagai hiasan latar panel branding.
class _Lingkaran extends StatelessWidget {
  const _Lingkaran(this.ukuran);

  final double ukuran;

  @override
  Widget build(BuildContext context) => Container(
    width: ukuran,
    height: ukuran,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 40),
    ),
  );
}

class _Fitur extends StatelessWidget {
  const _Fitur(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: AppColors.brandGold, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Judul form: "Selamat Datang di" + nama berwarna hijau + deskripsi.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.judul, required this.sorot, required this.deskripsi});

  final String judul;
  final String sorot;
  final String deskripsi;

  @override
  Widget build(BuildContext context) {
    const gaya = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(judul, style: gaya),
        Text(sorot, style: gaya.copyWith(color: AppColors.brand)),
        const SizedBox(height: 10),
        Text(deskripsi, style: const TextStyle(color: AppColors.muted, height: 1.5)),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Input dengan ikon di kiri, gaya abu-abu seperti desain HTML.
InputDecoration authInput(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
  hintText: hint,
  prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
  suffixIcon: suffix,
  fillColor: const Color(0xFFF5F7F6),
  contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 14),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFE8ECEA)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
  ),
);

/// Field password dengan tombol mata (tampilkan / sembunyikan).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hint = 'Password',
    this.validator,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _sembunyi = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _sembunyi,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      decoration: authInput(
        widget.hint,
        Icons.lock_outline,
        suffix: IconButton(
          tooltip: _sembunyi ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(_sembunyi ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: () => setState(() => _sembunyi = !_sembunyi),
        ),
      ),
    );
  }
}

/// Tombol hijau lebar dengan indikator loading.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Icon(icon, size: 18),
                ],
              ),
      ),
    );
  }
}

class PesanBox extends StatelessWidget {
  const PesanBox(this.pesan, {super.key, this.sukses = false});

  final String pesan;
  final bool sukses;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sukses ? const Color(0xFFD9F5E3) : const Color(0xFFFDE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            sukses ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: sukses ? const Color(0xFF167A43) : const Color(0xFFB91C1C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pesan,
              style: TextStyle(color: sukses ? const Color(0xFF167A43) : const Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }
}

class Pemisah extends StatelessWidget {
  const Pemisah({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('atau', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }
}
