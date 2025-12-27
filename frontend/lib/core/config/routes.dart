/// SMARTCARE+ Route Configuration
///
/// App navigation routes

import 'package:flutter/material.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/home/dashboard_screen.dart';

class AppRoutes {
  AppRoutes._();

  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  
  // Physio routes
  static const String physioHome = '/physio';
  static const String gaitAnalysis = '/physio/gait';
  static const String tugTest = '/physio/tug';
  static const String exercises = '/physio/exercises';
  
  // Nutrition routes
  static const String nutritionHome = '/nutrition';
  static const String foodScanner = '/nutrition/scanner';
  static const String mealPlan = '/nutrition/meal-plan';
  static const String hydration = '/nutrition/hydration';
  
  // Guardian routes
  static const String guardianHome = '/guardian';
  static const String liveMonitor = '/guardian/monitor';
  static const String alerts = '/guardian/alerts';
  static const String geofence = '/guardian/geofence';

  /// Generate routes
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        // TODO: Replace with actual splash screen
        return _fadeRoute(const LoginScreen(), settings);
      
      case login:
        return _fadeRoute(const LoginScreen(), settings);
      
      case dashboard:
        return _fadeRoute(const DashboardScreen(), settings);
      
      // TODO: Add more routes as screens are created
      
      default:
        return _fadeRoute(
          Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
          settings,
        );
    }
  }

  /// Fade transition route
  static PageRoute _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Slide transition route
  static PageRoute slideRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
