import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'data/app_state.dart';
import 'pages/dashboard_page.dart';
import 'pages/data_barang_page.dart';
import 'pages/kontak_page.dart';
import 'pages/laba_rugi_page.dart';
import 'pages/laporan_pages.dart';
import 'pages/pengaturan_page.dart';
import 'pages/pengguna_page.dart';
import 'pages/stok_barang_page.dart';
import 'pages/transaksi_page.dart';
import 'theme.dart';
import 'utils/format.dart';
import 'widgets/brand.dart';
import 'widgets/common.dart';

const _kasir = {'Kasir'};
const _gudang = {'Gudang'};
const _kasirGudang = {'Kasir', 'Gudang'};

class MenuEntry {
  const MenuEntry(this.label, this.icon, this.builder, {this.section, this.roles});

  final String label;
  final IconData icon;
  final String? section;
  final Widget Function() builder;

  /// Role selain Admin yang boleh membuka menu ini (Admin selalu boleh).
  final Set<String>? roles;

  bool bolehDibuka(String role) => role == 'Admin' || (roles?.contains(role) ?? false);
}

List<MenuEntry> menuUntuk(String role) => menus.where((m) => m.bolehDibuka(role)).toList();

final menus = <MenuEntry>[
  MenuEntry('Home', Icons.home_rounded, () => const DashboardPage(), roles: _kasirGudang),
  MenuEntry('Pembelian', Icons.add_shopping_cart, () => const TransaksiPage(penjualan: false),
      section: 'TRANSAKSI', roles: _gudang),
  MenuEntry('Penjualan', Icons.shopping_cart_checkout, () => const TransaksiPage(penjualan: true),
      roles: _kasir),
  MenuEntry('Stok Barang', Icons.inventory_2_outlined, () => const StokBarangPage(), roles: _kasirGudang),
  MenuEntry('Laporan Periodik', Icons.bar_chart_rounded, () => const LaporanPeriodikPage(),
      section: 'LAPORAN'),
  MenuEntry('Laporan Pembelian', Icons.description_outlined,
      () => const LaporanTransaksiPage(penjualan: false), roles: _gudang),
  MenuEntry('Laporan Penjualan', Icons.receipt_long_outlined,
      () => const LaporanTransaksiPage(penjualan: true), roles: _kasir),
  MenuEntry('Laporan Stok', Icons.inventory_outlined, () => const LaporanStokPage(), roles: _gudang),
  MenuEntry('Laba Rugi', Icons.pie_chart_rounded, () => const LabaRugiPage()),
  MenuEntry('Data Barang', Icons.category_outlined, () => const DataBarangPage(),
      section: 'DATA MASTER', roles: _gudang),
  MenuEntry('Data Supplier', Icons.local_shipping_outlined, () => const KontakPage(supplier: true),
      roles: _gudang),
  MenuEntry('Data Pelanggan', Icons.people_alt_outlined, () => const KontakPage(supplier: false),
      roles: _kasir),
  MenuEntry('Pengguna', Icons.person_outline, () => const PenggunaPage(), section: 'PENGATURAN'),
  MenuEntry('Pengaturan', Icons.settings_outlined, () => const PengaturanPage()),
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

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  bool _sidebarTerbuka = true;

  List<MenuEntry> _menu = menus;

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
              if (lebar && _sidebarTerbuka) sidebar,
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
                    Expanded(
                      child: SingleChildScrollView(
                        key: PageStorageKey(_index),
                        padding: const EdgeInsets.all(16),
                        child: KeyedSubtree(key: ValueKey(_menu[_index].label), child: _menu[_index].builder()),
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
          padding: const EdgeInsets.fromLTRB(22, 22, 16, 8),
          child: Text(m.section!,
              style: const TextStyle(
                  color: AppColors.sidebarSection,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
        ));
      }
      final aktif = i == selected;
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: aktif ? AppColors.sidebarActive : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.white10,
            onTap: () => onSelect(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(m.icon, color: Colors.white, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(m.label,
                        style: TextStyle(
                            color: AppColors.sidebarText,
                            fontSize: 14.5,
                            fontWeight: aktif ? FontWeight.w600 : FontWeight.w400)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    return Container(
      width: 230,
      color: AppColors.sidebar,
      child: Column(
        children: [
          const SizedBox(height: 18),
          const _Logo(),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(padding: const EdgeInsets.only(bottom: 16), children: children),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => const BrandBlock(logoSize: 90, judulSize: 22);
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
          IconButton(onPressed: onMenu, icon: const Icon(Icons.menu, size: 28)),
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
                    prefixIcon: const Icon(Icons.search),
                    fillColor: const Color(0xFFF1F4F8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!compact) ...[
            const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.text),
            const SizedBox(width: 6),
            Text(tglPanjang(DateTime.now()), style: const TextStyle(color: AppColors.text)),
            const SizedBox(width: 16),
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
            child: Badge(
              isLabelVisible: menipis.isNotEmpty,
              label: Text('${menipis.length}'),
              backgroundColor: AppColors.red,
              child: const Icon(Icons.notifications_none_rounded, size: 28),
            ),
          ),
          const SizedBox(width: 16),
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
              if (user?.role == 'Admin')
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
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.person, color: AppColors.blue),
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.nama ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(user?.role ?? '', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                ],
                const Icon(Icons.keyboard_arrow_down),
              ],
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
