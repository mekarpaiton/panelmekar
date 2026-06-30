import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red,
        body: Center(child: Text('TEST MERAH', style: TextStyle(fontSize: 40, color: Colors.white))),
      ),
    ),
  );
}