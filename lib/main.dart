import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'kategori.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';


const String baseUrl = 'https://abahkhuzai.pythonanywhere.com';
const Color warnaUtama = Color(0xFF7F00FF);
const String PIN_ADMIN = "123456";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PanelTBMekar());
}

class PanelTBMekar extends StatelessWidget {
  const PanelTBMekar({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panel TB. MEKAR',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Poppins',
        useMaterial3: false,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// HELPER AMAN
String formatTotal(dynamic total) {
  if (total == null) return 'Rp 0';
  int angka = int.tryParse(total.toString())?? 0;
  return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(angka);
}

String formatTanggal(dynamic tgl) {
  if (tgl == null) return '-';
  try {
    return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(tgl.toString()));
  } catch (e) {
    return tgl.toString();
  }
}

List safeParseList(dynamic data) {
  try {
    if (data is String) return jsonDecode(data);
    if (data is List) return data;
  } catch (e) {
    print('Gagal parse list: $e');
  }
  return [];
}

Map safeParseMap(dynamic data) {
  try {
    if (data is String) return jsonDecode(data);
    if (data is Map) return data;
  } catch (e) {
    print('Gagal parse map: $e');
  }
  return {};
}

// 1. HALAMAN LOGIN
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final pinCtrl = TextEditingController();
  bool salah = false;

  void login() {
    if (pinCtrl.text == PIN_ADMIN) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (ctx) => DashboardPanel()));
    } else {
      setState(() => salah = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: warnaUtama,
      body: Center(
        child: Card(
          margin: EdgeInsets.all(32),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
  'assets/images/logomekar.svg',
  width: 80,
  height: 100,
  ),
                SizedBox(height: 16),
                Text('Panel TB. MEKAR', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Sistem Manajemen Toko', style: TextStyle(color: Colors.grey[600])),
                SizedBox(height: 24),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Masukkan PIN',
                    border: OutlineInputBorder(),
                    errorText: salah? 'PIN Salah' : null,
                  ),
                  onSubmitted: (_) => login(),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(backgroundColor: warnaUtama, padding: EdgeInsets.all(16)),
                    child: Text('MASUK', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. DASHBOARD PANEL
class DashboardPanel extends StatefulWidget {
  const DashboardPanel({super.key});
  @override
  State<DashboardPanel> createState() => _DashboardPanelState();
}

class _DashboardPanelState extends State<DashboardPanel> {
  int tabIndex = 0;
  final pages = [
    HalamanOrder(),
    HalamanProduk(),
    HalamanHistory(),
    HalamanKatalog(),
    HalamanSetting(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[tabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        selectedItemColor: warnaUtama,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => tabIndex = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Pesanan'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Produk'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Laporan'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Katalog'),
          BottomNavigationBarItem(
  icon: SvgPicture.asset(
    'assets/images/logomekar.svg',
    width: 24, height: 24,
    color: Colors.grey,
  ),
  
  label: 'Setting',
),
        ],
      ),
    );
  }
}

// 3. HALAMAN PESANAN - ANTI-CRASH TOTAL
class HalamanOrder extends StatefulWidget {
  @override
  State<HalamanOrder> createState() => _HalamanOrderState();
}

class _HalamanOrderState extends State<HalamanOrder> {
  List orders = [];
  bool loading = true;
  final listStatus = ['Baru', 'Diproses', 'Selesai', 'Batal'];

  @override
  void initState() {
    super.initState();
    getOrders();
  }

  Future<void> printStruk(Map o) async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();

      if (statuses[Permission.bluetoothConnect]!= PermissionStatus.granted ||
          statuses[Permission.bluetoothScan]!= PermissionStatus.granted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Izin Bluetooth ditolak Boss'), backgroundColor: Colors.red));
        return;
      }
    }

    bool enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nyalain Bluetooth dulu Boss'), backgroundColor: Colors.red));
      return;
    }

    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));
      List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
      if (mounted) Navigator.pop(context);

      if (devices.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Printer belum di-pairing di HP'), backgroundColor: Colors.red));
        return;
      }

      BluetoothInfo? selected = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Pilih Printer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: devices.map((d) => ListTile(
              leading: Icon(Icons.print),
              title: Text(d.name),
              subtitle: Text(d.macAdress),
              onTap: () => Navigator.pop(ctx, d),
            )).toList(),
          ),
        ),
      );

      if (selected == null) return;

      try {
        bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: selected.macAdress);
        if (!connected) throw Exception('Gagal konek ke printer');
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal konek: $e'), backgroundColor: Colors.red));
        return;
      }
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      String idStr = o['id']?.toString()?? '';
      String displayId = idStr.length > 8? idStr.substring(0, 8) : idStr;

      bytes += generator.text('TB MEKAR', styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
      bytes += generator.text('Probolinggo', styles: PosStyles(align: PosAlign.center));
      bytes += generator.hr();
      bytes += generator.text('Order: $displayId');
      bytes += generator.text('Tgl: ${formatTanggal(o['tanggal']?? o['created_at'])}');
      bytes += generator.text('Kasir: Admin');
      bytes += generator.hr();

      final itemsList = safeParseList(o['items']);
      int total = 0;
      for (var item in itemsList) {
        int harga = int.tryParse(item['harga']?.toString()?? '0')?? 0;
        int qty = int.tryParse(item['qty']?.toString()?? '0')?? 0;
        int subtotal = qty * harga;
        total += subtotal;
        bytes += generator.text(item['nama']?.toString()?? 'Item');
        bytes += generator.row([
          PosColumn(text: '$qty x ${formatTotal(harga)}', width: 6),
          PosColumn(text: formatTotal(subtotal), width: 6, styles: PosStyles(align: PosAlign.right)),
        ]);
      }
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: PosStyles(bold: true)),
        PosColumn(text: formatTotal(o['total']?? total), width: 6, styles: PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.hr();
      bytes += generator.text('Terima Kasih', styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      final result = await PrintBluetoothThermal.writeBytes(bytes);
      if (result == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Struk berhasil dicetak!'), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal cetak Boss'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> getOrders() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/orders')).timeout(Duration(seconds: 15));
      if (!mounted) return;

      if (res.statusCode!= 200) throw Exception('Server error ${res.statusCode}');
      if (!res.headers['content-type']!.contains('application/json')) throw Exception('Response bukan JSON');

      setState(() {
        orders = json.decode(res.body);
        loading = false;
      });
    } catch (e) {
      print("API ORDER ERROR: $e");
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ambil pesanan: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> updateStatus(String orderId, String statusBaru) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': statusBaru}),
      ).timeout(Duration(seconds: 10));

      if (!mounted) return;
      if (res.statusCode!= 200) throw Exception('Server error ${res.statusCode}');
      if (!res.headers['content-type']!.contains('application/json')) throw Exception('Response bukan JSON');

      getOrders();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status diubah: $statusBaru'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal update: $e'), backgroundColor: Colors.red));
    }
  }

  Color warnaStatus(String status) {
    switch (status) {
      case 'Baru': return Colors.red;
      case 'Diproses': return Colors.orange;
      case 'Selesai': return Colors.green;
      case 'Batal': return Colors.grey;
      default: return Colors.blue;
    }
  }

  void copyStrukWA(Map order) {
    try {
      String struk = "🧾 *STRUK TB. MEKAR*\n";
      struk += "ID: ${order['id']?.toString()?? '-'}\n";
      struk += "Tgl: ${formatTanggal(order['created_at']?? order['tanggal'])}\n";
      struk += "Nama: ${order['nama_pembeli']?.toString()?? '-'}\n";
      struk += "Status: ${order['status']?.toString()?? 'Baru'}\n";
      struk += "------------------------\n";

      final itemsList = safeParseList(order['items']);
      for (var item in itemsList) {
        int harga = int.tryParse(item['harga']?.toString()?? '0')?? 0;
        int qty = int.tryParse(item['qty']?.toString()?? '0')?? 0;
        struk += "${item['nama']?.toString()?? 'Item'} x$qty\n";
        struk += " ${formatTotal(harga * qty)}\n";
      }
      struk += "------------------------\n";
      struk += "*TOTAL: ${formatTotal(order['total'])}*\n\n";
      struk += "Terima kasih 🙏";

      Clipboard.setData(ClipboardData(text: struk));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Struk dicopy!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal copy: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pesanan Masuk'), backgroundColor: warnaUtama),
      body: loading
        ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: getOrders,
              child: orders.isEmpty
                ? Center(child: Text('Belum ada pesanan'))
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) {
                        final o = orders[i];
                        String rawStatus = o['status']?.toString()?? 'Baru';
                        String statusTervalidasi = 'Baru';
                        for (var s in listStatus) {
                          if (s.toLowerCase() == rawStatus.toLowerCase().trim()) {
                            statusTervalidasi = s;
                            break;
                          }
                        }

                        final itemsList = safeParseList(o['items']);

                        return Card(
                          margin: EdgeInsets.all(8),
                          child: ExpansionTile(
                            leading: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: warnaStatus(statusTervalidasi), borderRadius: BorderRadius.circular(12)),
                              child: Text(statusTervalidasi, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(o['nama_pembeli']?.toString()?? 'Tanpa Nama', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${o['id']} - ${formatTotal(o['total'])}'),
                            children: [
                            ...itemsList.map<Widget>((item) {
                                int hrg = int.tryParse(item['harga']?.toString()?? '0')?? 0;
                                int qtypcl = int.tryParse(item['qty']?.toString()?? '0')?? 0;
                                return ListTile(
                                  title: Text('${item['nama']?.toString()?? 'Item'} x$qtypcl'),
                                  trailing: Text(formatTotal(hrg * qtypcl)),
                                );
                              }).toList(),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: DropdownButtonFormField<String>(
                                  value: statusTervalidasi,
                                  decoration: InputDecoration(labelText: 'Ubah Status', border: OutlineInputBorder()),
                                  items: listStatus.map((String s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                                  onChanged: (String? v) => updateStatus(o['id'].toString(), v!),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => copyStrukWA(o),
                                      icon: Icon(Icons.copy, size: 18),
                                      label: Text('Copy WA'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => printStruk(o),
                                      icon: Icon(Icons.print, size: 18),
                                      label: Text('Print'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// 4. HALAMAN PRODUK - KATEGORI DINAMIS + EDIT AKTIF
class HalamanProduk extends StatefulWidget {
  @override
  State<HalamanProduk> createState() => _HalamanProdukState();
}

class _HalamanProdukState extends State<HalamanProduk> {
  List produk = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    getProduk();
  }

  Future<void> getProduk() async {
    if (mounted) setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/produk')).timeout(Duration(seconds: 15));
      if (!mounted) return;

      if (res.statusCode!= 200) throw Exception('Server error ${res.statusCode}');
      if (!res.headers['content-type']!.contains('application/json')) throw Exception('Response bukan JSON');

      setState(() {
        produk = json.decode(res.body);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> hapusProduk(String id, String nama) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Produk'),
        content: Text('Yakin hapus "$nama"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await http.delete(Uri.parse('$baseUrl/api/produk/$id')).timeout(Duration(seconds: 10));
        if (!mounted) return;
        if (res.statusCode!= 200) throw Exception('Server error ${res.statusCode}');

        getProduk();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Produk dihapus'), backgroundColor: Colors.green));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void bukaFormProduk({Map? dataProduk}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => FormProduk(produk: dataProduk))
    );
    if (result == true) {
      getProduk();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kelola Produk'), backgroundColor: warnaUtama),
      body: loading
       ? Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: getProduk,
            child: produk.isEmpty
             ? Center(child: Text('Belum ada produk'))
              : ListView.builder(
                  itemCount: produk.length,
                  itemBuilder: (c, i) {
                    final p = produk[i];
                    final hargaMap = safeParseMap(p['harga']);
                    final hargaPertama = hargaMap.values.isNotEmpty? hargaMap.values.first : 0;
                    final stok = p['stok']?? 0;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(p['foto']?.toString()?? '', width: 50, height: 50, fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(width: 50, height: 50, color: Colors.grey[300], child: Icon(Icons.image, color: Colors.grey))),
                        ),
                        title: Text(p['nama']?.toString()?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${formatTotal(hargaPertama)} / ${p['satuan']?? ''} - Stok: $stok'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => bukaFormProduk(dataProduk: p),
                              tooltip: 'Edit Produk',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => hapusProduk(p['id'].toString(), p['nama']?.toString()?? ''),
                              tooltip: 'Hapus Produk',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => bukaFormProduk(),
        backgroundColor: warnaUtama,
        child: Icon(Icons.add),
        tooltip: 'Tambah Produk',
      ),
    );
  }
}

// FORM PRODUK - KATEGORI DINAMIS DARI API
class FormProduk extends StatefulWidget {
  final Map? produk;
  FormProduk({this.produk});

  @override
  State<FormProduk> createState() => _FormProdukState();
}

class _FormProdukState extends State<FormProduk> {
  final _formKey = GlobalKey<FormState>();
  final namaCtrl = TextEditingController();
  final stokCtrl = TextEditingController();
  final hargaCtrl = TextEditingController();
  String kategori = 'Lainnya';
  String satuan = 'sak';
  String fotoUrl = '';
  bool isLoading = false;
  bool uploadLoading = false;
  List<String> listKategori = ['Lainnya'];
  bool kategoriLoading = true;
  final listSatuan = ['sak', 'kg', 'batang', 'dus', 'kaleng', 'm2', 'pcs'];

  @override
  void initState() {
    super.initState();
    getKategori();
    if (widget.produk!= null) {
      namaCtrl.text = widget.produk!['nama']?.toString()?? '';
      fotoUrl = widget.produk!['foto']?.toString()?? '';
      stokCtrl.text = widget.produk!['stok']?.toString()?? '0';
      kategori = widget.produk!['kategori']?.toString()?? 'Lainnya';
      satuan = widget.produk!['satuan']?.toString()?? 'sak';

      try {
        final hargaMap = safeParseMap(widget.produk!['harga']);
        hargaCtrl.text = hargaMap.values.isNotEmpty? hargaMap.values.first.toString() : '0';
      } catch (e) {
        hargaCtrl.text = '0';
      }
    }
  }

  Future getKategori() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/kategori'));
      if (!mounted) return;
      final data = json.decode(res.body) as List;
      setState(() {
        listKategori = data.map((e) => e['nama'].toString()).toList();
        if (listKategori.isEmpty) listKategori = ['Lainnya'];
        if (!listKategori.contains(kategori)) kategori = listKategori.first;
        kategoriLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => kategoriLoading = false);
    }
  }

  Future<void> pilihDanUploadFoto() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    if (mounted) setState(() => uploadLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://freeimage.host/api/1/upload'));
      request.fields['key'] = '6d207e02198a847aa98d0a2a901485a5';
      request.files.add(await http.MultipartFile.fromPath('source', file.path));
      var res = await request.send().timeout(Duration(seconds: 30));
      var responseData = await res.stream.toBytes();
      var result = json.decode(utf8.decode(responseData));

      if (!mounted) return;
      if (result['status_code'] == 200) {
        setState(() => fotoUrl = result['image']['url']);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto keupload!'), backgroundColor: Colors.green));
      } else {
        throw Exception('Upload gagal: ${result['error']?['message']?? 'Unknown'}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => uploadLoading = false);
    }
  }

  Future<void> simpanProduk() async {
    if (!_formKey.currentState!.validate()) return;
    if (fotoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload foto dulu Boss'), backgroundColor: Colors.orange));
      return;
    }

    if (mounted) setState(() => isLoading = true);
    Map hargaJson = {satuan: int.parse(hargaCtrl.text)};
    Map data = {
      'id': widget.produk?['id']?? 'PRD${DateTime.now().millisecondsSinceEpoch}',
      'nama': namaCtrl.text,
      'kategori': kategori,
      'deskripsi': widget.produk?['deskripsi']?? '',
      'foto': fotoUrl,
      'satuan': satuan,
      'varian': json.encode({}),
      'harga': json.encode(hargaJson),
      'stok': int.parse(stokCtrl.text),
    };

    try {
      http.Response res;
      if (widget.produk == null) {
        res = await http.post(
          Uri.parse('$baseUrl/api/produk'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(data),
        ).timeout(Duration(seconds: 15));
      } else {
        res = await http.put(
          Uri.parse('$baseUrl/api/produk/${widget.produk!['id']}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'nama': namaCtrl.text,
            'kategori': kategori,
            'harga': json.encode(hargaJson),
            'stok': int.parse(stokCtrl.text),
            'satuan': satuan,
            'foto': fotoUrl,
          }),
        ).timeout(Duration(seconds: 15));
      }

      if (!mounted) return;
      if (res.statusCode!= 200 && res.statusCode!= 201) throw Exception('Server error ${res.statusCode}');

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.produk == null? 'Produk ditambah' : 'Produk diupdate'),
        backgroundColor: Colors.green
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.produk == null? 'Tambah Produk' : 'Edit Produk'), backgroundColor: warnaUtama),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(controller: namaCtrl, decoration: InputDecoration(labelText: 'Nama Produk', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shopping_bag)), validator: (v) => v!.isEmpty? 'Wajib diisi' : null),
            SizedBox(height: 16),
            kategoriLoading
             ? Center(child: CircularProgressIndicator())
              : DropdownButtonFormField(
                  value: kategori,
                  decoration: InputDecoration(labelText: 'Kategori', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                  items: listKategori.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) => setState(() => kategori = v!)
                ),
            SizedBox(height: 16),
            Row(children: [
              Expanded(flex: 2, child: TextFormField(controller: hargaCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Harga', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)), validator: (v) => v!.isEmpty? 'Wajib' : null)),
              SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField(value: satuan, decoration: InputDecoration(labelText: 'Satuan', border: OutlineInputBorder()), items: listSatuan.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => satuan = v!))),
            ]),
            SizedBox(height: 16),
            TextFormField(controller: stokCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Stok', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory)), validator: (v) => v!.isEmpty? 'Wajib' : null),
            SizedBox(height: 16),
            Text('Foto Produk', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            SizedBox(height: 8),
            fotoUrl.isEmpty
             ? Container(width: double.infinity, height: 120, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: InkWell(onTap: uploadLoading? null : pilihDanUploadFoto, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [uploadLoading? CircularProgressIndicator() : Icon(Icons.add_a_photo, size: 40, color: warnaUtama), SizedBox(height: 8), Text(uploadLoading? 'Uploading...' : 'Pilih Foto dari HP'), Text('Otomatis keupload', style: TextStyle(fontSize: 12, color: Colors.grey))])))
              : Column(children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl, height: 150, width: double.infinity, fit: BoxFit.cover)), SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width: 4), Text('Foto udah online', style: TextStyle(color: Colors.green)), TextButton(onPressed: () => setState(() => fotoUrl = ''), child: Text('Ganti Foto'))])]),
            SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: isLoading? null : simpanProduk, style: ElevatedButton.styleFrom(backgroundColor: warnaUtama), child: isLoading? CircularProgressIndicator(color: Colors.white) : Text(widget.produk == null? 'TAMBAH PRODUK' : 'UPDATE PRODUK', style: TextStyle(color: Colors.white, fontSize: 16)))),
          ],
        ),
      ),
    );
  }
}

// 5. HALAMAN LAPORAN + EXPORT EXCEL - ANTI CRASH TOTAL
class HalamanHistory extends StatefulWidget {
  @override
  State<HalamanHistory> createState() => _HalamanHistoryState();
}

class _HalamanHistoryState extends State<HalamanHistory> {
  List orders = [];
  bool loading = true;
  String errorMsg = '';

  @override
  void initState() {
    super.initState();
    getAllOrders();
  }

  Future<void> getAllOrders() async {
    try {
      if (mounted) setState(() { loading = true; errorMsg = ''; });
      final res = await http.get(Uri.parse('$baseUrl/api/orders/all')).timeout(Duration(seconds: 15));
      if (!mounted) return;

      if (res.statusCode!= 200) throw Exception('Server error: ${res.statusCode}');
      if (!res.headers['content-type']!.contains('application/json')) throw Exception('Response bukan JSON');

      setState(() {
        orders = json.decode(res.body);
        loading = false;
      });
    } catch (e) {
      print("LAPORAN ERROR: $e");
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = 'Gagal ambil data: $e';
      });
    }
  }

  Future<void> exportExcel() async {
    if (orders.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Data kosong Boss'), backgroundColor: Colors.orange));
      return;
    }

    try {
      var excel = ex.Excel.createExcel();
      ex.Sheet sheet = excel['Transaksi'];

      sheet.appendRow([
        ex.TextCellValue('ID'),
        ex.TextCellValue('Tanggal'),
        ex.TextCellValue('Nama'),
        ex.TextCellValue('WA'),
        ex.TextCellValue('Total'),
        ex.TextCellValue('Item'),
        ex.TextCellValue('Status'),
      ]);

      for (var o in orders) {
        String items = '';
        try {
          final itemsList = safeParseList(o['items']);
          items = itemsList.map((i) => '${i['nama']?.toString()?? 'Item'} x${i['qty']?.toString()?? '0'}').join(', ');
        } catch (e) {
          items = 'Error parsing item';
        }

        sheet.appendRow([
          ex.TextCellValue(o['id']?.toString()?? ''),
          ex.TextCellValue(formatTanggal(o['created_at'])),
          ex.TextCellValue(o['nama_pembeli']?.toString()?? ''),
          ex.TextCellValue(o['wa_pembeli']?.toString()?? ''),
          ex.IntCellValue(int.tryParse(o['total']?.toString()?? '0')?? 0),
          ex.TextCellValue(items),
          ex.TextCellValue(o['status']?.toString()?? ''),
        ]);
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/history_tb_mekar_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      file.writeAsBytesSync(excel.encode()!);

      await Share.shareXFiles([XFile(file.path)], text: 'History Transaksi TB. MEKAR');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Transaksi'),
        backgroundColor: warnaUtama,
        actions: [
          IconButton(onPressed: exportExcel, icon: Icon(Icons.file_download), tooltip: 'Export Excel'),
        ],
      ),
      body: loading
       ? Center(child: CircularProgressIndicator())
          : errorMsg.isNotEmpty
           ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(errorMsg, textAlign: TextAlign.center),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: getAllOrders, child: Text('Coba Lagi'))
                ]))
              : orders.isEmpty
               ? Center(child: Text('Belum ada transaksi'))
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) {
                        final o = orders[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: warnaUtama,
                            child: Text('${i + 1}', style: TextStyle(color: Colors.white)),
                          ),
                          title: Text(o['nama_pembeli']?.toString()?? 'Tanpa Nama'),
                          subtitle: Text(formatTanggal(o['created_at'])),
                          trailing: Text(
                            formatTotal(o['total']),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
    );
  }
}

// 6. HALAMAN KATALOG - PREVIEW CUSTOMER - ANTI CRASH TOTAL
class HalamanKatalog extends StatefulWidget {
  @override
  State<HalamanKatalog> createState() => _HalamanKatalogState();
}

class _HalamanKatalogState extends State<HalamanKatalog> {
  List produk = [];
  List kategori = ['Semua', 'Semen', 'Cat', 'Pipa', 'Besi', 'Keramik', 'Lainnya'];
  String kategoriDipilih = 'Semua';
  bool loading = true;
  String errorMsg = '';
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getProduk();
  }

  Future<void> getProduk({String? search, String? kategori}) async {
    try {
      if (mounted) setState(() { loading = true; errorMsg = ''; });

      String url = '$baseUrl/api/produk?';
      if (search!= null && search.isNotEmpty) url += 'search=$search&';
      if (kategori!= null && kategori!= 'Semua') url += 'kategori=$kategori';

      final res = await http.get(Uri.parse(url)).timeout(Duration(seconds: 15));
      if (!mounted) return;

      if (res.statusCode!= 200) throw Exception('Server error: ${res.statusCode}');
      if (!res.headers['content-type']!.contains('application/json')) throw Exception('Response bukan JSON');

      setState(() {
        produk = json.decode(res.body);
        loading = false;
      });
    } catch (e) {
      print("KATALOG ERROR: $e");
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMsg = 'Gagal ambil data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Katalog'),
        backgroundColor: warnaUtama,
        actions: [IconButton(onPressed: getProduk, icon: Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) => getProduk(search: value, kategori: kategoriDipilih),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemCount: kategori.length,
              itemBuilder: (ctx, i) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(kategori[i]),
                  selected: kategoriDipilih == kategori[i],
                  onSelected: (selected) {
                    setState(() => kategoriDipilih = kategori[i]);
                    getProduk(search: searchController.text, kategori: kategori[i]);
                  },
                  selectedColor: warnaUtama,
                  labelStyle: TextStyle(
                    color: kategoriDipilih == kategori[i]? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: loading
             ? Center(child: CircularProgressIndicator(color: warnaUtama))
                : errorMsg.isNotEmpty
                 ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.error, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(errorMsg, textAlign: TextAlign.center),
                        SizedBox(height: 16),
                        ElevatedButton(onPressed: getProduk, child: Text('Coba Lagi'))
                      ]))
                    : produk.isEmpty
                     ? Center(child: Text('Produk tidak ditemukan'))
                        : ListView.builder(
                            itemCount: produk.length,
                            itemBuilder: (c, i) {
                              final p = produk[i];
                              final hargaMap = safeParseMap(p['harga']);
                              final hargaPertama = hargaMap.values.isNotEmpty? hargaMap.values.first : 0;
                              final stok = p['stok']?? 0;

                              return Card(
                                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      p['foto']?.toString()?? '',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[300],
                                          child: Icon(Icons.image)),
                                    ),
                                  ),
                                  title: Text(p['nama']?.toString()?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${formatTotal(hargaPertama)} / ${p['satuan']?? ''}'),
                                  trailing: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: stok > 10? Colors.green : stok > 0? Colors.orange : Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('Stok: $stok', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// 7. HALAMAN SETTING - LENGKAP 7 FITUR + FIX BUILD ERROR
class HalamanSetting extends StatefulWidget {
  @override
  State<HalamanSetting> createState() => _HalamanSettingState();
}

class _HalamanSettingState extends State<HalamanSetting> {
  int versi = 36; // GANTI SESUAI VERSI SEKARANG
  String linkGithub = 'https://mekarpaiton.github.io/usermekar';
  final pinCtrl = TextEditingController();
  final namaTokoCtrl = TextEditingController(text: 'TB. MEKAR');
  final alamatCtrl = TextEditingController(text: 'Jl. Probolinggo No.1');
  final waCtrl = TextEditingController(text: '0812-xxxx-xxxx');

  // 1. CACHE BUSTER
  void generateLinkBaru() {
    setState(() => versi++);
    String linkFinal = '$linkGithub?v=$versi';
    Clipboard.setData(ClipboardData(text: linkFinal));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Link v$versi dicopy! Share ke customer'), backgroundColor: Colors.green),
      );
    }
  }

  // 2. GANTI PIN
  void gantiPin() {
    if (pinCtrl.text.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PIN minimal 6 digit'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    // TODO: Simpen ke SharedPreferences / Server
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN berhasil diganti: ${pinCtrl.text}'), backgroundColor: Colors.green),
      );
    }
    pinCtrl.clear();
  }

  // 3. SIMPAN INFO TOKO
  void simpanInfoToko() {
    // TODO: Simpen ke SharedPreferences / Server
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Info toko disimpan'), backgroundColor: Colors.green),
      );
    }
    FocusScope.of(context).unfocus();
  }

  // 4. TEST PRINTER - FIXED
  Future<void> testPrinter() async {
    try {
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      bool enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nyalain Bluetooth dulu Boss'), backgroundColor: Colors.red));
        return;
      }

      List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
      if (devices.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Printer belum di-pairing di HP'), backgroundColor: Colors.red));
        return;
      }

      BluetoothInfo? selected = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Pilih Printer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: devices.map((d) => ListTile(
              leading: Icon(Icons.print),
              title: Text(d.name),
              subtitle: Text(d.macAdress),
              onTap: () => Navigator.pop(ctx, d),
            )).toList(),
          ),
        ),
      );

      if (selected == null) return;

      bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: selected.macAdress);
      if (!connected) throw Exception('Gagal konek ke printer');

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];
      bytes += generator.text('TB. MEKAR', styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.text('TEST PRINTER OK', styles: PosStyles(align: PosAlign.center));
      bytes += generator.text(DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), styles: PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      await PrintBluetoothThermal.writeBytes(bytes);
      await PrintBluetoothThermal.disconnect; // <-- FIX: GA PAKE ()
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test print berhasil'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Printer error: $e'), backgroundColor: Colors.red));
    }
  }

  // 5. BACKUP DATA - FIXED IMPORT EXCEL
  Future<void> backupProduk() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/produk')).timeout(Duration(seconds: 15));
      if (!mounted) return;

      if (res.statusCode!= 200) throw Exception('Server error ${res.statusCode}');
      if (!res.headers['content-type']!.contains('application/json')) throw Exception('Response bukan JSON');

      List produk = json.decode(res.body);

      var excel = ex.Excel.createExcel(); // <-- FIX: ex.Excel
      ex.Sheet sheet = excel['Produk']; // <-- FIX: ex.Sheet
      sheet.appendRow([
        ex.TextCellValue('ID'), // <-- FIX: ex.TextCellValue
        ex.TextCellValue('Nama'),
        ex.TextCellValue('Kategori'),
        ex.TextCellValue('Harga'),
        ex.TextCellValue('Stok'),
        ex.TextCellValue('Satuan'),
      ]);

      for (var p in produk) {
        final hargaMap = safeParseMap(p['harga']);
        sheet.appendRow([
          ex.TextCellValue(p['id']?.toString()?? ''),
          ex.TextCellValue(p['nama']?.toString()?? ''),
          ex.TextCellValue(p['kategori']?.toString()?? ''),
          ex.IntCellValue(hargaMap.values.isNotEmpty? hargaMap.values.first : 0), // <-- FIX: ex.IntCellValue
          ex.IntCellValue(p['stok']?? 0),
          ex.TextCellValue(p['satuan']?.toString()?? ''),
        ]);
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/backup_produk_tbmekar.xlsx');
      file.writeAsBytesSync(excel.encode()!);
      await Share.shareXFiles([XFile(file.path)], text: 'Backup Produk TB. MEKAR');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup gagal: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // 6. LOGOUT
  void logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Logout'),
        content: Text('Yakin mau keluar dari Panel Admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (ctx) => LoginPage()),
                (route) => false,
              );
            },
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String linkSekarang = '$linkGithub?v=$versi';

    return Scaffold(
      appBar: AppBar(title: Text('Setting & Tools'), backgroundColor: warnaUtama),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 1. CACHE BUSTER
          _buildCard(
            icon: Icon(Icons.rocket_launch),
            title: 'Cache Buster Link',
            subtitle: 'Generate link baru kalo katalog customer nggak update',
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: warnaUtama.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(linkSekarang, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: generateLinkBaru,
                    icon: Icon(Icons.add_link),
                    label: Text('GENERATE LINK v${versi + 1}'),
                    style: ElevatedButton.styleFrom(backgroundColor: warnaUtama),
                  ),
                ),
              ],
            ),
          ),

          // 2. GANTI PIN
          _buildCard(
            icon: Icon(Icons.lock),
            title: 'Ganti PIN Admin',
            subtitle: 'PIN saat ini: 123456',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'PIN Baru 6 digit',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(onPressed: gantiPin, child: Text('SIMPAN'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
              ],
            ),
          ),

          // 3. INFO TOKO
          _buildCard(
           icon: SvgPicture.asset(
  'assets/images/logomekar.svg',
  width: 45,
  height: 45,
  color: warnaUtama,
),
            title: 'Info Toko',
            subtitle: 'Data ini nampil di struk & katalog',
            child: Column(
              children: [
                TextField(controller: namaTokoCtrl, decoration: InputDecoration(labelText: 'Nama Toko', border: OutlineInputBorder())),
                SizedBox(height: 12),
                TextField(controller: alamatCtrl, decoration: InputDecoration(labelText: 'Alamat', border: OutlineInputBorder())),
                SizedBox(height: 12),
                TextField(controller: waCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'No WA', border: OutlineInputBorder())),
                SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: simpanInfoToko, child: Text('SIMPAN INFO TOKO'))),
              ],
            ),
          ),

          // 4. TEST PRINTER
          _buildCard(
            icon: Icon(Icons.print),
            title: 'Test Printer Thermal',
            subtitle: 'Cek koneksi printer sebelum ada order',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: testPrinter,
                icon: Icon(Icons.print),
                label: Text('CETAK TES'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
          ),

          // 5. BACKUP DATA
          _buildCard(
            icon: Icon(Icons.backup),
            title: 'Backup Data',
            subtitle: 'Download semua data produk ke Excel',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: backupProduk,
                icon: Icon(Icons.file_download),
                label: Text('BACKUP PRODUK EXCEL'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ),
          ),
//6. kategori
_buildCard(
  icon: Icon(Icons.category),
  title: 'Kelola Kategori',
  subtitle: 'Tambah/hapus kategori produk',
  child: SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HalamanKategori())),
      icon: Icon(Icons.edit),
      label: Text('ATUR KATEGORI'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
    ),
  ),
),
          // 7. TENTANG APLIKASI
          _buildCard(
            icon: Icon(Icons.info),
            title: 'Tentang Aplikasi',
            subtitle: 'Panel TB. MEKAR v1.0.0',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Owner: Abah Khuzai'),
                Text('Builder: BABE.INFO/HeruWingchun'),
                Text('Link: mekarpaiton.github.io/'),
              ],
            ),
          ),

          // 8. LOGOUT
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: logout,
              icon: Icon(Icons.logout),
              label: Text('LOGOUT'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

    Widget _buildCard({
    required Widget icon,
    required String title,
    required String subtitle,
    required Widget child
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTheme(
                  data: IconThemeData(color: warnaUtama, size: 45),
                  child: icon,
                ),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                )),
              ],
            ),
            Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}