import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class GeoPage extends StatefulWidget {
  const GeoPage({super.key});

  @override
  State<GeoPage> createState() => _GeoPageState();
}

class _GeoPageState extends State<GeoPage> {
  String _locationMessage = 'Ubicación no obtenida';
  String _link = "";

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verifica si los servicios de ubicación están habilitados
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Los servicios de ubicación están desactivados.';
      });
      return;
    }

    // Verifica permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = 'Permisos de ubicación denegados';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage =
            'Los permisos están permanentemente denegados, no podemos solicitar permisos.';
      });
      return;
    }

    // Obtiene la ubicación
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _locationMessage = 'Latitud: ${position.latitude}, Longitud: ${position.longitude}\n';
      _link = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    });
  }

  Future<void> logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.of(context).pop(); // Regresa a la pantalla de login
  }

  void openLink() async {
    await launchUrl(Uri.parse(_link));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geolocalización')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_locationMessage, textAlign: TextAlign.center),
            ElevatedButton(
              onPressed: () => openLink(),
              child: Text(_link, textAlign: TextAlign.center),              
            ),
            
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: const Text('Obtener ubicación'),
            ),
            ElevatedButton(onPressed: () => logout(context), child: const Text("Cerrar sesión"),)
          ],
        ),
      ),
    );
  }
}