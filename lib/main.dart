// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_provider.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Load robot URL đã lưu → sẵn sàng gửi token ngay sau khi login
  final prefs = await SharedPreferences.getInstance();
  final savedRobotUrl = prefs.getString('camera_base_url');
  if (savedRobotUrl != null && savedRobotUrl.isNotEmpty) {
    ApiService.setRobotUrl(savedRobotUrl);
  }

  runApp(const AlphaMiniApp());
}

class AlphaMiniApp extends StatelessWidget {
  const AlphaMiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Alpha Mini Family',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
