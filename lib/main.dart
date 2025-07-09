import 'package:archivos_app/blog_page.dart';
import 'package:archivos_app/blog_page_publishers.dart';
import 'package:archivos_app/login_page.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: "",
    anonKey: ""
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Supabase Upload App",
      theme: ThemeData(primarySwatch: Colors.amber),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {

  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Usuario no autenticado -> Login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      });
      return;
    }

    final userId = session.user.id;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = response['role'] as String;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (role == 'visitante') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BlogPage()),
          );
        } 
        else if (role == 'publicador') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PublisherBlogPage()),
          );
        } 
        else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rol no reconocido')),
          );
        }
      });
    } catch (e) {
      print("Error al obtener rol: $e");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al obtener perfil: $e")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
