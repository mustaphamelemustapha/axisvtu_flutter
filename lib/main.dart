import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint("Failed to initialize Firebase on Android: $e");
    }
  }
  runApp(const AxisVTUApp());
}
