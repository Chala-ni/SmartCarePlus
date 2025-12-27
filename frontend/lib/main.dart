/// SMARTCARE+ Flutter Application
///
/// AI-Powered Elderly Care Ecosystem
/// Dark Futuristic Theme with Glassmorphism

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/config/theme.dart';
import 'core/config/routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E17),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const SmartCarePlusApp());
}

class SmartCarePlusApp extends StatelessWidget {
  const SmartCarePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMARTCARE+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkFuturistic,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
