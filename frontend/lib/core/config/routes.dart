/// SMARTCARE+ Route Configuration
///
/// App navigation routes

import 'package:flutter/material.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/home/role_based_dashboard.dart';
import '../../screens/physio/physio_home_screen.dart';
import '../../screens/physio/gait_analysis_screen.dart';
import '../../screens/physio/tug_test_screen.dart';
import '../../screens/physio/exercise_library_screen.dart';
import '../../screens/physio/exercise_schedule_screen.dart';
import '../../screens/nutrition/nutrition_home_screen.dart';
import '../../screens/nutrition/food_scanner_screen.dart';
import '../../screens/nutrition/meal_log_screen.dart';
import '../../screens/nutrition/meal_plan_screen.dart';
import '../../screens/nutrition/hydration_screen.dart';
import '../../screens/guardian/guardian_home_screen.dart';
import '../../screens/guardian/live_monitor_screen.dart';
import '../../screens/guardian/alerts_screen.dart';
import '../../screens/guardian/activity_log_screen.dart';
import '../../screens/connections/connection_screen.dart';

class AppRoutes {
  AppRoutes._();

  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String connections = '/connections';
  
  // Physio routes
  static const String physioHome = '/physio';
  static const String gaitAnalysis = '/physio/gait';
  static const String tugTest = '/physio/tug';
  static const String exercises = '/physio/exercises';
  static const String exerciseSchedule = '/physio/schedule';
  
  // Nutrition routes
  static const String nutritionHome = '/nutrition';
  static const String foodScanner = '/nutrition/scanner';
  static const String mealLog = '/nutrition/meal-log';
  static const String mealPlan = '/nutrition/meal-plan';
  static const String hydration = '/nutrition/hydration';
  
  // Guardian routes
  static const String guardianHome = '/guardian';
  static const String liveMonitor = '/guardian/monitor';
  static const String alerts = '/guardian/alerts';
  static const String activityLog = '/guardian/activity';
  static const String geofence = '/guardian/geofence';

  /// Generate routes
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fadeRoute(const SplashScreen(), settings);
      
      case login:
        return _fadeRoute(const LoginScreen(), settings);
      
      case register:
        return _slideRoute(const RegisterScreen(), settings);
      
      case dashboard:
        return _fadeRoute(const RoleBasedDashboard(), settings);
      
      // Physio routes
      case physioHome:
        return _slideRoute(const PhysioHomeScreen(), settings);
      case gaitAnalysis:
        return _slideRoute(const GaitAnalysisScreen(), settings);
      case tugTest:
        return _slideRoute(const TUGTestScreen(), settings);
      case exercises:
        return _slideRoute(const ExerciseLibraryScreen(), settings);
      case exerciseSchedule:
        return _slideRoute(const ExerciseScheduleScreen(), settings);
      
      // Nutrition routes
      case nutritionHome:
        return _slideRoute(const NutritionHomeScreen(), settings);
      case foodScanner:
        return _slideRoute(const FoodScannerScreen(), settings);
      case mealLog:
        return _slideRoute(const MealLogScreen(), settings);
      case mealPlan:
        return _slideRoute(const MealPlanScreen(), settings);
      case hydration:
        return _slideRoute(const HydrationScreen(), settings);
      
      // Guardian routes
      case guardianHome:
        return _slideRoute(const GuardianHomeScreen(), settings);
      case liveMonitor:
        return _slideRoute(const LiveMonitorScreen(), settings);
      case alerts:
        return _slideRoute(const AlertsScreen(), settings);
      case activityLog:
        return _slideRoute(const ActivityLogScreen(), settings);
      
      // Connections route
      case connections:
        return _slideRoute(const ConnectionScreen(), settings);
      
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

  /// Slide transition route (from right)
  static PageRoute _slideRoute(Widget page, RouteSettings settings) {
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

  /// Slide transition route (legacy - for external use)
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

/// Alias for easier access
typedef Routes = AppRoutes;
