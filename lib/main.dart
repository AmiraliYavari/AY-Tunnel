import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2Ray Flutter Client',
      debugShowCheckedModeBanner: false,
      // جهت راست‌به‌چپ برای نمایش درست متن فارسی
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: const HomeScreen(),
      ),
    );
  }
}
