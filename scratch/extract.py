import os

def main():
    with open('lib/main.dart', 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    def get_lines(start, end):
        return "".join(lines[start-1:end])
        
    splash_code = get_lines(56, 193)
    dashboard_code = get_lines(196, 261)
    home_code = get_lines(264, 1191)
    tests_code = get_lines(1194, 1289)
    history_code = get_lines(1291, 1321)
    profile_code = get_lines(1324, 1592)
    
    splash_file = """import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_helper.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';

""" + splash_code
    
    dashboard_file = """import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'tests_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

""" + dashboard_code
    
    home_file = """import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'tests/spiral_test_screen.dart';
import 'tests/voice_test_screen.dart';
import 'tests/gait_test_screen.dart';
import 'tests/tapping_test_screen.dart';
import '../services/stats_service.dart';

""" + home_code

    tests_file = """import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'tests/spiral_test_screen.dart';
import 'tests/voice_test_screen.dart';
import 'tests/gait_test_screen.dart';
import 'tests/tapping_test_screen.dart';

""" + tests_code

    history_file = """import 'package:flutter/material.dart';
import 'dart:math' as math;

""" + history_code

    profile_file = """import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'register_screen.dart';
import 'tests/database_viewer.dart';

""" + profile_code

    main_file = """import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkinson Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SplashScreen(),
    );
  }
}
"""

    with open('lib/screens/splash_screen.dart', 'w', encoding='utf-8') as f: f.write(splash_file)
    with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f: f.write(dashboard_file)
    with open('lib/screens/home_screen.dart', 'w', encoding='utf-8') as f: f.write(home_file)
    with open('lib/screens/tests_screen.dart', 'w', encoding='utf-8') as f: f.write(tests_file)
    with open('lib/screens/history_screen.dart', 'w', encoding='utf-8') as f: f.write(history_file)
    with open('lib/screens/profile_screen.dart', 'w', encoding='utf-8') as f: f.write(profile_file)
    with open('lib/main.dart', 'w', encoding='utf-8') as f: f.write(main_file)

if __name__ == '__main__':
    main()
