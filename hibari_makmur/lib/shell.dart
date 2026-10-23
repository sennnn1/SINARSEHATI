import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'data/app_state.dart';
import 'pages/dashboard_page.dart';
import 'pages/data_barang_page.dart';
import 'pages/kontak_page.dart';
import 'pages/laba_kotor_page.dart';
import 'pages/laporan_pages.dart';
import 'pages/pengaturan_page.dart';
import 'pages/pengguna_page.dart';
import 'pages/stok_barang_page.dart';
import 'pages/transaksi_page.dart';
import 'theme.dart';
import 'utils/format.dart';
import 'widgets/brand.dart';
import 'widgets/common.dart';

// Owner selalu boleh membuka semua menu.
const _admin = {'Admin'};
const _adminSales = {'Admin', 'Sales'};

class MenuEntry {
  const MenuEntry(this.label, this.icon, this.builder, {this.section, this.roles});

  final String label;
  final IconData icon;
  final String? section;
  final Widget Function() builder;

  /// Role selain Owner yang boleh membuka menu ini (Owner selalu boleh).
  final Set<String>? roles;

  bool bolehDibuka(String role) => role == 'Owner' || (roles?.contains(role) ?? false);
}

List<MenuEntry> menuUntuk(String role) => menus.where((m) => m.bolehDibuka(role)).toList();

final menus = <MenuEntry>[
  MenuEntry('Home', Icons.home_rounded, () => const DashboardPage(), roles: _adminSales),
  MenuEntry('Pembelian', Icons.add_shopping_cart, () => const TransaksiPage(penjualan: false),
      section: 'TRANSAKSI', roles: _admin),
  MenuEntry('Penjualan', Icons.shopping_cart_checkout, () => const TransaksiPage(penjualan: true),
      roles: _adminSales),
  MenuEntry('Stok Barang', Icons.inventory_2_outlined, () => const StokBarangPage(), roles: _adminSales),
  MenuEntry('Laporan Periodik', Icons.bar_chart_rounded, () => const LaporanPeriodikPage(),
      section: 'LAPORAN'),
  MenuEntry('Laporan Pembelian', Icons.description_outlined,
      () => const LaporanTransaksiPage(penjualan: false), roles: _admin),
  MenuEntry('Laporan Penjualan', Icons.receipt_long_outlined,
      () => const LaporanTransaksiPage(penjualan: true), roles: _adminSales),
  MenuEntry('Laporan Stok', Icons.inventory_outlined, () => const LaporanStokPage(), roles: _admin),
  MenuEntry('Laba Kotor', Icons.savings_outlined, () => const LabaKotorPage()),
  MenuEntry('Data Barang', Icons.category_outlined, () => const DataBarangPage(),
      section: 'DATA MASTER', roles: _admin),
  MenuEntry('Data Supplier', Icons.local_shipping_outlined, () => const KontakPage(supplier: true),
      roles: _admin),
  MenuEntry('Data Pelanggan', Icons.people_alt_outlined, () => const KontakPage(supplier: false),
      roles: _adminSales),
  MenuEntry('Pengguna', Icons.person_outline, () => const PenggunaPage(), section: 'PENGATURAN'),
  MenuEntry('Pengaturan', Icons.settings_outlined, () => const PengaturanPage(), roles: _admin),
];

/// Dipakai halaman untuk pindah menu, mis. tombol "Lihat Semua".
class ShellNav extends InheritedWidget {
  const ShellNav({super.key, required this.buka, required super.child});

  final void Function(String label) buka;

  static ShellNav of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNav>()!;

  @override
  bool updateShouldNotify(ShellNav oldWidget) => false;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.role});

  /// Role pengguna yang login; menentukan menu yang tampil.
  final String role;

  /// Kalau false, halaman lain tidak disiapkan di latar (dipakai saat tes).
  static bool siapkanDiLatar = true;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  bool _sidebarTerbuka = true;

  List<MenuEntry> _menu = menus;

  /// Halaman yang sudah pernah dibangun. Halaman ini tetap disimpan (hanya
  /// disembunyikan), jadi pindah menu tidak perlu membangun ulang dari nol.
  final _dibangun = <String>{};
  Timer? _siapkan;

  @override
  void initState() {
    super.initState();
    if (HomeShell.siapkanDiLatar) _siapkan = Timer(const Duration(milliseconds: 800), _siapkanBerikutnya);
  }

  @override
  void dispose() {
    _siapkan?.cancel();
    super.dispose();
  }

  /// Membangun halaman yang belum dibuka satu per satu dengan jeda, supaya
  /// saat menu diklik halamannya sudah siap dan tidak membuat layar tersendat.
  void _siapkanBerikutnya() {
    if (!mounted) return;
    final berikut = _menu.where((m) => !_dibangun.contains(m.label)).firstOrNull;
    if (berikut == null) return;
    setState(() => _dibangun.add(berikut.label));
    _siapkan = Timer(const Duration(milliseconds: 250), _siapkanBerikutnya);
  }

  void _buka(String label) {
    final i = _menu.indexWhere((m) => m.label == label);
    if (i < 0) return;
    setState(() => _index = i);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    _menu = menuUntuk(widget.role);
    if (_index >= _menu.length) _index = 0;
    _dibangun.add(_menu[_index].label);
    final state = AppScope.read(context);
    return LayoutBuilder(builder: (context, c) {
      final lebar = c.maxWidth >= 1000;
      final sidebar = Sidebar(menus: _menu, selected: _index, onSelect: (i) => _buka(_menu[i].label));
      return ShellNav(
        buka: _buka,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: lebar ? null : Drawer(width: 240, child: sidebar),
          body: Row(
            children: [
              if (lebar && _sidebarTerbuka) RepaintBoundary(child: sidebar),
              Expanded(
                child: Column(
                  children: [
                    TopBar(
                      compact: c.maxWidth < 700,
                      onMenu: () {
                        if (lebar) {
                          setState(() => _sidebarTerbuka = !_sidebarTerbuka);
                        } else {
                          _scaffoldKey.currentState?.openDrawer();
                        }
                      },
                      onBuka: _buka,
                    ),
                    const _BannerErrorSinkron(),
                    Expanded(
                      child: Stack(
                        children: [
                          for (final m in _menu)
                            if (_dibangun.contains(m.label))
                              Positioned.fill(
                                child: _HalamanTetap(
                                  key: ValueKey(m.label),
                                  state: state,
                                  aktif: m.label == _menu[_index].label,
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.all(c.maxWidth >= 700 ? 24 : 16),
                                    child: m.builder(),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Peringatan kalau perubahan (mis. data barang) gagal disimpan ke Supabase,
/// supaya tidak hilang diam-diam saat data dimuat ulang.
class _BannerErrorSinkron extends StatelessWidget {
  const _BannerErrorSinkron();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pesan = s.errorSinkron;
    if (pesan == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFEF2F2),
        border: Border(bottom: BorderSide(color: Color(0xFFFECACA))),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.red, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(pesan, style: const TextStyle(color: Color(0xFFB91C1C)))),
        IconButton(
          tooltip: 'Tutup',
          onPressed: s.tutupErrorSinkron,
          icon: const Icon(Icons.close, size: 18, color: AppColors.red),
        ),
      ]),
    );
  }
}

/// Satu halaman menu yang disimpan. Saat tidak aktif halaman disembunyikan
/// (tidak digambar, animasinya berhenti) dan tidak ikut dibangun ulang ketika
/// data berubah; perubahan yang tertunda diterapkan begitu halaman dibuka lagi.
class _HalamanTetap extends StatefulWidget {
  const _HalamanTetap({super.key, required this.state, required this.aktif, required this.child});

  final AppState state;
  final bool aktif;
  final Widget child;

  @override
  State<_HalamanTetap> createState() => _HalamanTetapState();
}

class _HalamanTetapState extends State<_HalamanTetap> with SingleTickerProviderStateMixin {
  final _pemicu = _PemicuTertunda();
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);

  @override
  void initState() {
    super.initState();
    _pemicu.aktif = widget.aktif;
    widget.state.addListener(_pemicu.dataBerubah);
  }

  @override
  void didUpdateWidget(_HalamanTetap old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_pemicu.dataBerubah);
      widget.state.addListener(_pemicu.dataBerubah);
    }
    if (widget.aktif != old.aktif) {
      _pemicu.aktif = widget.aktif;
      if (widget.aktif) _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_pemicu.dataBerubah);
    _pemicu.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !widget.aktif,
      child: TickerMode(
        enabled: widget.aktif,
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: AppScope(state: widget.state, pemicu: _pemicu, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Meneruskan notifikasi perubahan data hanya saat halaman aktif; kalau tidak
/// aktif, perubahan dicatat dan diteruskan ketika halaman aktif kembali.
class _PemicuTertunda extends ChangeNotifier {
  bool _aktif = false;
  bool _tertunda = false;

  set aktif(bool v) {
    _aktif = v;
    if (v && _tertunda) {
      _tertunda = false;
      notifyListeners();
    }
  }

  void dataBerubah() {
    if (_aktif) {
      notifyListeners();
    } else {
      _tertunda = true;
    }
  }
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.menus, required this.selected, required this.onSelect});

  final List<MenuEntry> menus;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? sectionTerakhir;
    for (var i = 0; i < menus.length; i++) {
      final m = menus[i];
      if (m.section != null && m.section != sectionTerakhir) {
        sectionTerakhir = m.section;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 6),
          child: Text(m.section!,
              style: const TextStyle(
                  color: AppColors.sidebarSection,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ));
      }
      final aktif = i == selected;
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
        child: Material(
          color: aktif ? AppColors.sidebarActive : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: Colors.white.withValues(alpha: 0.06),
            onTap: () => onSelect(i),
            child: Stack(
              children: [
                // Penanda emas di kiri menu yang sedang dibuka.
                if (aktif)
                  Positioned(
                    left: 0,
                    top: 9,
                    bottom: 9,
                    child: Container(
                      width: 3.5,
                      decoration: BoxDecoration(
                        color: AppColors.brandGold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10.5),
                  child: Row(
                    children: [
                      Icon(m.icon,
                          color: aktif ? AppColors.brandGold : AppColors.sidebarText.withValues(alpha: 0.75),
                          size: 21),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(m.label,
                            style: TextStyle(
                                color: aktif ? Colors.white : AppColors.sidebarText.withValues(alpha: 0.85),
                                fontSize: 14,
                                fontWeight: aktif ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sidebar, AppColors.sidebarDark],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top + 20),
          const _Logo(),
          const SizedBox(height: 16),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.only(bottom: 16), children: children),
          ),
          const _KartuPengguna(),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => const BrandBlock(logoSize: 72, judulSize: 19);
}

/// Inisial nama untuk avatar, mis. "Budi Santoso" → "BS".
String inisial(String? nama) {
  final kata = (nama ?? '').trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
  if (kata.isEmpty) return '?';
  return (kata.first[0] + (kata.length > 1 ? kata.last[0] : '')).toUpperCase();
}

class AvatarInisial extends StatelessWidget {
  const AvatarInisial({super.key, required this.nama, this.radius = 18, this.gelap = false});

  final String? nama;
  final double radius;

  /// True untuk dipasang di latar gelap (sidebar).
  final bool gelap;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: gelap ? AppColors.brandGold : AppColors.brandSoft,
      child: Text(
        inisial(nama),
        style: TextStyle(
          color: gelap ? AppColors.sidebarDark : AppColors.brand,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

/// Nama & role pengguna di bagian bawah sidebar.
class _KartuPengguna extends StatelessWidget {
  const _KartuPengguna();

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    if (user == null) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          AvatarInisial(nama: user.nama, gelap: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(user.role, style: const TextStyle(color: AppColors.sidebarSection, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.onMenu, required this.onBuka, this.compact = false});

  final VoidCallback onMenu;
  final ValueChanged<String> onBuka;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final user = AuthScope.of(context).user;
    final menipis = s.stokMenipis;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded, size: 26, color: AppColors.text),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: TextField(
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) {
                    if (q.trim().isNotEmpty) _cariGlobal(context, q.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari barang, pelanggan, supplier...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.brand, width: 1.4)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!compact) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.brand),
                const SizedBox(width: 8),
                Text(tglPanjang(DateTime.now()),
                    style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(width: 12),
          ],
          PopupMenuButton<String>(
            tooltip: 'Notifikasi',
            onSelected: (_) => onBuka('Stok Barang'),
            itemBuilder: (_) => menipis.isEmpty
                ? [const PopupMenuItem(enabled: false, child: Text('Tidak ada notifikasi'))]
                : [
                    for (final b in menipis.take(8))
                      PopupMenuItem(
                        value: b.kode,
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.warning_amber_rounded, color: AppColors.red),
                          title: Text(b.nama),
                          subtitle: Text('Stok ${b.stok} ${b.satuan} (min. ${b.minStok})'),
                        ),
                      ),
                  ],
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Badge(
                isLabelVisible: menipis.isNotEmpty,
                label: Text('${menipis.length}'),
                backgroundColor: AppColors.red,
                child: const Icon(Icons.notifications_none_rounded, size: 22, color: AppColors.text),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Akun',
            onSelected: (v) async {
              if (v == 'pengaturan') onBuka('Pengaturan');
              if (v == 'keluar' &&
                  await konfirmasi(context, 'Keluar dari aplikasi?', tombol: 'Keluar') &&
                  context.mounted) {
                await AuthScope.read(context).logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(user?.nama ?? '-', style: const TextStyle(color: AppColors.text)),
                  subtitle: Text('${user?.email ?? ''}\nRole: ${user?.role ?? '-'}'),
                ),
              ),
              const PopupMenuDivider(),
              if (user != null && menuUntuk(user.role).any((m) => m.label == 'Pengaturan'))
                const PopupMenuItem(
                  value: 'pengaturan',
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Pengaturan')),
                ),
              const PopupMenuItem(
                value: 'keluar',
                child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout, color: AppColors.red),
                    title: Text('Keluar')),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  AvatarInisial(nama: user?.nama),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nama ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        Text(user?.role ?? '', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                      ],
                    ),
                  ],
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _cariGlobal(BuildContext context, String q) {
    final s = AppScope.read(context);
    final k = q.toLowerCase();
    bool cocok(String a, String b) => a.toLowerCase().contains(k) || b.toLowerCase().contains(k);
    final hasil = <(IconData, String, String, String)>[
      for (final b in s.barang)
        if (cocok(b.nama, b.kode))
          (Icons.inventory_2_outlined, b.nama, '${b.kode} · stok ${b.stok} ${b.satuan}', 'Data Barang'),
      for (final p in s.pelanggan)
        if (cocok(p.nama, p.kode)) (Icons.person_outline, p.nama, 'Pelanggan · ${p.kode}', 'Data Pelanggan'),
      for (final p in s.supplier)
        if (cocok(p.nama, p.kode))
          (Icons.local_shipping_outlined, p.nama, 'Supplier · ${p.kode}', 'Data Supplier'),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hasil pencarian "$q"'),
        content: SizedBox(
          width: 460,
          child: hasil.isEmpty
              ? const Text('Tidak ditemukan.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final h in hasil)
                      ListTile(
                        leading: Icon(h.$1),
                        title: Text(h.$2),
                        subtitle: Text(h.$3),
                        onTap: () {
                          Navigator.pop(ctx);
                          onBuka(h.$4);
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
