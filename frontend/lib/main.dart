import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import './screens/login.dart';

void main() async {
  // 1. Esto DEBE ser lo primero
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializamos el soporte de fechas
  await initializeDateFormatting('es_MX', null);
  
  // 3. Arrancamos
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tostadas App',
      
      // CONFIGURACIÓN DE IDIOMA CRÍTICA
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'), // Español
        Locale('en', 'US'), // Inglés
      ],
      locale: const Locale('es', 'MX'), // Forzamos español
      
      theme: ThemeData(
        primaryColor: const Color(0xFF2D6A4F),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D6A4F)),
        useMaterial3: true,
      ),
      
      // IMPORTANTE: Asegúrate que LoginScreen NO tenga un 'const' antes si da error
      home: LoginScreen(),
    );
  }
}

// Mantenemos tus colores aquí por si los usas en otros lados
class AppColors {
  static const Color fondoHueso = Color(0xFFF3F3ED); 
  static const Color verdeBosque = Color(0xFF2D6A4F); 
  static const Color verdeBorde = Color(0xFF40916C);  // <--- ESTA ES LA QUE TE PIDE EL LOGIN
  static const Color textoGris = Color(0xFF4F4F4F);   
  static const Color tituloNegro = Color(0xFF333333); // <--- ESTA ES LA QUE TE PEDÍA EL CORTE
}