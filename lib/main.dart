import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';

const String baseUrl = 'https://abahkhuzai.pythonanywhere.com';
const Color warnaUtama = Color(0xFF7F00FF);

// PIN PANEL - GANTI INI BOSS
const String PIN_ADMIN = "123456";

void main() {
  runApp(const PanelTBMekar());
}

class PanelTBMekar extends StatelessWidget {
  const PanelTBMekar({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panel TB. MEKAR',
      theme: ThemeData(primarySwatch: Colors.deepPurple, fontFamily: 'Poppins'),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
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
                Icon(Icons.storefront, size: 80, color: warnaUtama),
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

// 2. DASHBOARD PANEL - 4 TAB
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
        ],
      ),
    );
  }
}

// 3. HALAMAN PESANAN
class HalamanOrder extends StatefulWidget {
  @override
  State<HalamanOrder> createState() => _HalamanOrderState();
}

class _HalamanOrderState extends State<HalamanOrder> {
  List orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    getOrders();
  }

  Future<void> getOrders() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/orders'));
      setState(() {
        orders = json.decode(res.body);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  String formatRupiah(int angka) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(angka);
  }

  void copyStrukWA(Map order) {
    String struk = "🧾 *STRUK TB. MEKAR*\n";
    struk += "ID: ${order['id']}\n";
    struk += "Tgl: ${order['created_at']}\n";
    struk += "Nama: ${order['nama_pembeli']}\n";
    struk += "------------------------\n";
    for (var item in order['items']) {
      struk += "${item['nama']} x${item['qty']}\n";
      struk += " ${formatRupiah(item['harga'] * item['qty'])}\n";
    }
    struk += "------------------------\n";
    struk += "*TOTAL: ${formatRupiah(order['total'])}*\n\n";
    struk += "Terima kasih 🙏";

    Clipboard.setData(ClipboardData(text: struk));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Struk dicopy! Tinggal paste di WA'), backgroundColor: Colors.green),
    );
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
                      return Card(
                        margin: EdgeInsets.all(8),
                        child: ExpansionTile(
                          title: Text(o['nama_pembeli'], style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${o['id']} - ${formatRupiah(o['total'])}'),
                          children: [
                          ...o['items'].map<Widget>((item) => ListTile(
                                  title: Text('${item['nama']} x${item['qty']}'),
                                  trailing: Text(formatRupiah(item['harga'] * item['qty'])),
                                )).toList(),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => copyStrukWA(o),
                                    icon: Icon(Icons.copy),
                                    label: Text('Copy WA'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: Icon(Icons.print),
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

// 4. HALAMAN PRODUK
class HalamanProduk extends StatefulWidget {
  @override
  State<HalamanProduk> createState() => _HalamanProdukState();
}

class _HalamanProdukState extends State<HalamanProduk> {
  List produk = [];

  @override
  void initState() {
    super.initState();
    getProduk();
  }

  Future<void> getProduk() async {
    final res = await http.get(Uri.parse('$baseUrl/api/produk'));
    setState(() => produk = json.decode(res.body));
  }

  Future<void> hapusProduk(int id) async {
    await http.delete(Uri.parse('$baseUrl/api/produk/$id'));
    getProduk();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kelola Produk'), backgroundColor: warnaUtama),
      body: ListView.builder(
        itemCount: produk.length,
        itemBuilder: (c, i) {
          final p = produk[i];
          return ListTile(
            leading: Image.network(p['foto'], width: 50, height: 50, fit: BoxFit.cover,
              errorBuilder: (c,e,s) => Icon(Icons.image)),
            title: Text(p['nama']),
            subtitle: Text('Stok: ${p['stok']}'),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => hapusProduk(p['id']),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // Nanti bikin form tambah
        backgroundColor: warnaUtama,
        child: Icon(Icons.add),
      ),
    );
  }
}

// 5. HALAMAN LAPORAN + EXPORT EXCEL
class HalamanHistory extends StatefulWidget {
  @override
  State<HalamanHistory> createState() => _HalamanHistoryState();
}

class _HalamanHistoryState extends State<HalamanHistory> {
  List orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    getAllOrders();
  }

  Future<void> getAllOrders() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/orders/all'));
      setState(() {
        orders = json.decode(res.body);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> exportExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Transaksi'];
    sheet.appendRow(['ID', 'Tanggal', 'Nama', 'WA', 'Total', 'Item']);

    for (var o in orders) {
      String items = o['items'].map((i) => '${i['nama']} x${i['qty']}').join(', ');
      sheet.appendRow([o['id'], o['created_at'], o['nama_pembeli'], o['wa_pembeli'], o['total'], items]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/history_tb_mekar.xlsx');
    file.writeAsBytesSync(excel.encode()!);
    Share.shareXFiles([XFile(file.path)], text: 'History Transaksi TB. MEKAR');
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
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (ctx, i) {
                final o = orders[i];
                return ListTile(
                  title: Text(o['nama_pembeli']),
                  subtitle: Text('${o['created_at']}'),
                  trailing: Text(NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(o['total'])),
                );
              },
            ),
    );
  }
}

// 6. HALAMAN KATALOG - PREVIEW CUSTOMER
class HalamanKatalog extends StatefulWidget {
  @override
  State<HalamanKatalog> createState() => _HalamanKatalogState();
}

class _HalamanKatalogState extends State<HalamanKatalog> {
  List produk = [];
  List kategori = ['Semua', 'Semen', 'Cat', 'Pipa', 'Besi', 'Keramik'];
  String kategoriDipilih = 'Semua';
  bool loading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getProduk();
  }

  Future<void> getProduk({String? search, String? kategori}) async {
    setState(() => loading = true);
    try {
      String url = '$baseUrl/api/produk?';
      if (search!= null && search.isNotEmpty) url += 'search=$search&';
      if (kategori!= null && kategori!= 'Semua') url += 'kategori=$kategori';

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() {
          produk = json.decode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
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
              : produk.isEmpty
          ? Center(child: Text('Produk tidak ditemukan'))
                : ListView.builder(
                    itemCount: produk.length,
                    itemBuilder: (c, i) {
                      final p = produk[i];
                      final hargaData = p['harga'];
                      final hargaMap = hargaData is String? json.decode(hargaData) : hargaData;
                      final hargaPertama = hargaMap.values.first;
                      final stok = p['stok']?? 0;

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(p['foto'], width: 50, height: 50, fit: BoxFit.cover,
                              errorBuilder: (c,e,s) => Container(width: 50, height: 50, color: Colors.grey[300], child: Icon(Icons.image))),
                          ),
                          title: Text(p['nama'], style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Rp $hargaPertama / ${p['satuan']}'),
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
