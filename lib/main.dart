import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TestFontApp());
}

class TestFontApp extends StatelessWidget {
  const TestFontApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF7F00FF),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TEST 1: GoogleFonts langsung
              Text(
                'TES GOOGLE FONTS',
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              
              // TEST 2: Pake try-catch manual biar ga blank
              FutureBuilder(
                future: GoogleFonts.pendingFonts([
                  GoogleFonts.poppins(),
                ]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    // Font udah ke-load
                    return Text(
                      'FONT UDAH KELOAD',
                      style: GoogleFonts.poppins(fontSize: 20, color: Colors.green),
                    );
                  } else {
                    // Font masih download = pake font default
                    return Text(
                      'LOADING FONT...',
                      style: TextStyle(fontSize: 20, color: Colors.yellow),
                    );
                  }
                },
              ),
              SizedBox(height: 20),
              
              // TEST 3: Font default
              Text(
                'INI FONT DEFAULT',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}