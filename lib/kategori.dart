import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = 'https://abahkhuzai.pythonanywhere.com';
const Color warnaUtama = Color(0xFF7F00FF);

class HalamanKategori extends StatefulWidget {
  @override
  State<HalamanKategori> createState() => _HalamanKategoriState();
}

class _HalamanKategoriState extends State<HalamanKategori> {
  List kategori = [];
  bool loading = true;
  final namaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    getKategori();
  }

  Future getKategori() async {
    if (mounted) setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/kategori')).timeout(Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        kategori = json.decode(res.body);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future tambahKategori() async {
    if (namaCtrl.text.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/kategori'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'nama': namaCtrl.text}),
      ).timeout(Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode!= 201) throw Exception('Server error ${res.statusCode}');

      namaCtrl.clear();
      getKategori();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kategori ditambah'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    }
  }

  Future hapusKategori(int id, String nama) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Kategori'),
        content: Text('Yakin hapus "$nama"?\nProduk dengan kategori ini ga akan kehapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await http.delete(Uri.parse('$baseUrl/api/kategori/$id')).timeout(Duration(seconds: 10));
        if (!mounted) return;
        if (res.statusCode!= 200) throw Exception('Server error ${res.statusCode}');

        getKategori();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kategori dihapus'), backgroundColor: Colors.green));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kelola Kategori'), backgroundColor: warnaUtama),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: namaCtrl,
                    decoration: InputDecoration(labelText: 'Nama Kategori Baru', border: OutlineInputBorder()),
                    onSubmitted: (_) => tambahKategori(),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(onPressed: tambahKategori, child: Text('TAMBAH'), style: ElevatedButton.styleFrom(backgroundColor: warnaUtama, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16))),
              ],
            ),
          ),
          Expanded(
            child: loading
             ? Center(child: CircularProgressIndicator())
              : kategori.isEmpty
               ? Center(child: Text('Belum ada kategori'))
                : RefreshIndicator(
                    onRefresh: getKategori,
                    child: ListView.builder(
                      itemCount: kategori.length,
                      itemBuilder: (c, i) => Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.label, color: warnaUtama),
                          title: Text(kategori[i]['nama'], style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => hapusKategori(kategori[i]['id'], kategori[i]['nama']),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}