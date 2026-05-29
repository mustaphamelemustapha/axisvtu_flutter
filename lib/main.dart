import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure modern edge-to-edge layout & transparent system overlays
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint("Failed to initialize Firebase on Android: $e");
    }
  }
  runApp(const AxisVTUApp());
}
