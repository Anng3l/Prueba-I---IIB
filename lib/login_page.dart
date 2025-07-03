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
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;

  Future<void> login() async {
    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text,
        password: passwordController.text,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $e')),
      );
    }
  }

  Future<void> signup() async {
    try {
      final response = await supabase.auth.signUp(
        email: emailController.text,
        password: passwordController.text);

      //Agregar el usuario creado a la tabla profiles para asignarle efectivamente un rol
      if (response.user != null)
      {
        final userId = response.user!.id;

        await supabase
        .from("profiles")
        .insert(
          {
            "id": userId,
            "role": roleSelected
          }
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Supabase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: login, child: const Text('Iniciar sesión')),
            TextButton(onPressed: signup, child: const Text('Registrarse')),
            DropDownBox(
              onRoleSelected: (role) {
                setState(() {
                  roleSelected = role;
                });
              },
            )
          ],
        ),
      ),
    );
  }
}