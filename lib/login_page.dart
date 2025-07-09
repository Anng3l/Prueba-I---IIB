import 'package:archivos_app/blog_page.dart';
import 'package:archivos_app/blog_page_publishers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DropDownBox extends StatefulWidget {
  final Function(String?) onRoleSelected;

  const DropDownBox({super.key, required this.onRoleSelected});

  @override
  State<DropDownBox> createState() => _DropDownBoxState();
}

class _DropDownBoxState extends State<DropDownBox> {
  String? selectedRole;
  final List<String> roles = ["visitante", "publicador"];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      hint: const Text("Seleccione su rol"),
      value: selectedRole,
      items: roles.map((role) {
        return DropdownMenuItem(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedRole = value;
        });
        widget.onRoleSelected(value);
      },
    );
  }
}








class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? roleSelected;
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;

  Future<void> login() async {
    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text,
        password: passwordController.text,
      );
      
      await checkSessionAndNavigate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $e')),
      );
    }
  }

  Future<void> signup() async {
    if (roleSelected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, seleccione un rol")),
      );
      return;
    }

    if (nameController.text.isEmpty)
    {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, ingrese un nombre"))
      );
      return;
    }

    try {
      final response = await supabase.auth.signUp(
        email: emailController.text,
        password: passwordController.text
      );

      if (response.user != null) {
        final userId = response.user!.id;

        await supabase.from("profiles").insert({
          "id": userId,
          "role": roleSelected,
          "nombre": nameController.text
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa tu correo para confirmar tu cuenta.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrarse: $e')),
      );
    }
  }


  Future<void> checkSessionAndNavigate() async {
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
        } else if (role == 'publicador') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PublisherBlogPage()),
          );
        } else {
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



  Future<void> logout() async {
    try
    {
      await Supabase.instance.client.auth.signOut();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false 
      );
    }
    catch(e)
    {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cerrar sesión"))
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Supabase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nombre (sólo si se va a registrar)")
            ),
            const SizedBox(height: 16),
            DropDownBox(
              onRoleSelected: (role) {
                setState(() {
                  roleSelected = role;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: login,
              child: const Text('Iniciar sesión'),
            ),
            TextButton(
              onPressed: signup,
              child: const Text('Registrarse'),
            ),
          ],
        ),
      ),
    );
  }
}
