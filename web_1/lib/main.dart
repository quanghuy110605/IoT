import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/dashboard_screen.dart';

// --- CẤU HÌNH FIREBASE ---
const firebaseConfig = FirebaseOptions(
  apiKey: "AIzaSyAMqDt8myAePFpsqbw3zh2ItzPAV8VPrK4",
  authDomain: "fir-1esp.firebaseapp.com",
  databaseURL: "https://fir-1esp-default-rtdb.firebaseio.com",
  projectId: "fir-1esp",
  storageBucket: "fir-1esp.firebasestorage.app",
  messagingSenderId: "555400554508",
  appId: "1:555400554508:web:b852a56538d272018ca629",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseConfig);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: ' Smart Home Control',
      home: const IoTDashboard(),
    );
  }
}
