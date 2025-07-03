

import 'dart:async';
import 'dart:ffi';

import 'package:archivos_app/blog_page.dart';
import 'package:archivos_app/login_page.dart';
import 'package:archivos_app/visitante_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: "https://zyrtathsdzkxwlnywkoz.supabase.co",
      anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5cnRhdGhzZHpreHdsbnl3a296Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzAyODQsImV4cCI6MjA2NzE0NjI4NH0.h43Dbf_fXiPYkVtpbAiUYxnL1nMtj8j_92qNcyT7fJE"
  );

  runApp(const MyApp());

}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Supabae Upload App",
      theme: ThemeData(primarySwatch: Colors.amber),
      home: const AuthGate(),
    );
  }
}


class AuthGate extends StatelessWidget {
  
  const AuthGate({super.key});


  Future<Void?> getProfilesRole(BuildContext context, String userId) async {
    // Consulta el perfil para obtener el rol
    final response = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();  // Obtiene solo un registro

    
    String rol = response['role'];

    if (rol == "visitante")
    {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const VisitantePage())
      );
    }
    else if (rol == "publicador")
    {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const BlogPage())
        );
    }
    /*
    List<dynamic> valuesList = response.values.toList();
    return valuesList[0]['role'];
    */
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange, 
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        final userId = session!.user.id;

        return FutureBuilder(
          future: getProfilesRole(context, userId), 
          builder: (context, snapshot) {
//            return const Padding(padding: EdgeInsetsGeometry.all(30), child: CircularProgressIndicator(),);
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            else if (snapshot.hasError)
            {
              return Text("Error: ${snapshot.error}");
            }
            else
            {
              return const Text("Perfil cargado correctamente");
            }
          }
        );      
      }
    );
  }
}