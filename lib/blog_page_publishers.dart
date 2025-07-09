import 'dart:io';

import 'package:archivos_app/login_page.dart';
import 'package:archivos_app/services/supabase_service.dart';
import 'package:archivos_app/widgets/CommentWidget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
//import 'package:flutter/cupertino.dart';
//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:uuid/uuid.dart';

class PublisherBlogPage extends StatefulWidget {
  const PublisherBlogPage({super.key});

  @override
  State<PublisherBlogPage> createState() => _PublisherBlogPageState();
}

class _PublisherBlogPageState extends State<PublisherBlogPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _refreshEntries();
  }

  Future<void> _refreshEntries() {
    setState(() {
      _entriesFuture = _fetchEntriesWithData();
    });
    return _entriesFuture;
  }

  Future<List<Map<String, dynamic>>> _fetchEntriesWithData() async {
    try {
      // 1. Obtener entradas principales
      final entriesResponse = await supabase
          .from('entries')
          .select('''
            id, author, description, images, created_at,
            coordenadax, coordenaday, lugar, user_id
          ''')
          .order('created_at', ascending: false);

      final entries = (entriesResponse as List).cast<Map<String, dynamic>>();

      // 2. Obtener perfiles correspondientes
      final userIds = entries
          .where((e) => e['user_id'] != null)
          .map((e) => e['user_id'].toString())
          .toSet()
          .toList();

      final profilesResponse = userIds.isNotEmpty
          ? await supabase
              .from('profiles')
              .select('id, nombre, role, foto_url')
              .inFilter('id', userIds)
          : [];

      final profilesMap = {
        for (var profile in profilesResponse)
          profile['id'].toString(): profile
      };

      // 3. Combinar datos
      return entries.map((entry) {
        final userId = entry['user_id']?.toString();
        return {
          ...entry,
          'profile': userId != null ? profilesMap[userId] : null,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching entries: $e');
      throw Exception('Error al cargar publicaciones: ${e.toString()}');
    }
  }


  Future<void> _logout(BuildContext context) async {
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al cerrar sesión")),
      );
    }
  }

  Widget _buildImageGallery(List<dynamic> imageUrls) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: 8,
              left: index == 0 ? 0 : 8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[index],
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  return progress == null
                      ? child
                      : Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Blog del Publicador"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Nueva publicación",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewEntryPage()),
              );
              _refreshEntries();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualizar publicaciones",
            onPressed: _refreshEntries,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar sesión",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshEntries,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("${snapshot.error}"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshEntries,
                      child: const Text("Reintentar"),
                    ),
                  ],
                ),
              );
            }

            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No hay publicaciones aún"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NewEntryPage()),
                        ).then((_) => _refreshEntries());
                      },
                      child: const Text("Crear primera publicación"),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final profile = entry['profiles'] as Map<String, dynamic>? ?? {};
                final photos = entry['entries_photos'] as List<dynamic>? ?? [];
                final imageUrls = entry['images'] as List<dynamic>? ?? [];
                final allImages = [...imageUrls, ...photos.map((p) => p['url'])];

                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado con información del autor
                        Row(
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry['author'] ?? 'Anónimo',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (profile['name'] != null)
                                  Text(
                                    profile['name'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            if (entry['created_at'] != null)
                              Text(
                                _formatDate(DateTime.parse(entry['created_at'])),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildImageGallery(allImages),
                        const SizedBox(height: 16),

                        // Descripción
                        if (entry['description'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              entry['description'],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),

                        // Ubicación y coordenadas
                        if (entry['lugar'] != null || 
                            (entry['coordenadax'] != null && entry['coordenaday'] != null))
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (entry['lugar'] != null)
                                Chip(
                                  label: Text(entry['lugar']),
                                  avatar: const Icon(Icons.location_on, size: 18),
                                ),
                              if (entry['coordenadax'] != null && entry['coordenaday'] != null)
                                Chip(
                                  label: Text(
                                    '${entry['coordenadax'].toStringAsFixed(4)}, '
                                    '${entry['coordenaday'].toStringAsFixed(4)}',
                                  ),
                                  avatar: const Icon(Icons.map, size: 18),
                                ),
                            ],
                          ),
                        const Divider(height: 24),

                        // Sección de comentarios
                        CommentSection(entryId: entry['id']),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

































class PublicationEntries extends StatelessWidget {
  final List<String> imageUrls;
  final String author;
  final String description;
  final double coordenadaX;
  final double coordenadaY;
  final String lugar;
  final DateTime? createdAt;

  const PublicationEntries({
    super.key,
    required this.imageUrls,
    required this.author,
    required this.description,
    required this.coordenadaX,
    required this.coordenadaY,
    required this.lugar,
    this.createdAt,
  }) : assert(imageUrls != null),
       assert(author != null),
       assert(description != null),
       assert(coordenadaX != null),
       assert(coordenadaY != null),
       assert(lugar != null);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección de imágenes con PageView
          if (imageUrls.isNotEmpty)
            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
                child: PageView.builder(
                  itemCount: imageUrls.length,
                  itemBuilder: (_, index) => CachedNetworkImage(
                    imageUrl: imageUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (_, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                ),
              ),
            ),

          // Sección de contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Autor y fecha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        _formatDate(createdAt!),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Descripción
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 12),

                // Ubicación y coordenadas
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip(Icons.location_on, lugar),
                    _buildInfoChip(
                      Icons.map,
                      '${coordenadaX.toStringAsFixed(4)}, ${coordenadaY.toStringAsFixed(4)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para chips de información
  Widget _buildInfoChip(IconData icon, String text) {
    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(left: -4, right: 8),
      avatar: Icon(icon, size: 18),
      label: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  // Formateador de fecha
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}














































class CommentSection extends StatefulWidget {
  final String entryId;

  const CommentSection({super.key, required this.entryId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> _commentsFuture;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  void _loadComments() {
    setState(() {
      _commentsFuture = fetchCommentsWithReplies(widget.entryId);
    });
  }

  Future<void> _postComment(BuildContext context) async {
    if (_controller.text.trim().isEmpty) return;

    try {
      await postComment(
        entryId: widget.entryId,
        content: _controller.text.trim(),
      );
      _controller.clear();
      _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comentarios',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "Escribe un comentario...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _postComment(context),
              tooltip: 'Publicar comentario',
            ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _commentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            final comments = snapshot.data ?? [];
            if (comments.isEmpty) {
              return const Center(
                child: Text('No hay comentarios aún'),
              );
            }

            return Column(
              children: comments
                  .map((comment) => CommentWidget(
                        comment: comment,
                        onReplyPosted: _loadComments,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}


































class NewEntryPage extends StatefulWidget {
  const NewEntryPage({super.key});

  @override
  State<NewEntryPage> createState() => _NewEntryPageState();
}

class _NewEntryPageState extends State<NewEntryPage> {
  final _descController = TextEditingController();
  final _lugarController = TextEditingController();
  final _coordXController = TextEditingController();
  final _coordYController = TextEditingController();

  final List<File> _images = [];
  final _uuid = const Uuid();
  final supabase = Supabase.instance.client;

  Future<File> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.path}_compressed.jpg',
      quality: 70,
    );
    return File(result!.path);
  }

  Future<void> _pickImages(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newImages = <File>[];
        
        for (final platformFile in result.files) {
          try {
            // Imágenes sólo de hasta 2MB
            if (platformFile.size > 2 * 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("La imagen '${platformFile.name}' supera los 2MB.")),
                );
              }
              continue; // saltar este archivo
            }

            if (platformFile.path != null) {
              final file = File(platformFile.path!);
              // Comprimir solo imágenes mayores a 500KB
              final compressedFile = platformFile.size > 500 * 1024
                  ? await _compressImage(file)
                  : file;
              newImages.add(compressedFile);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error al procesar: ${platformFile.name}")),
              );
            }
          }
        }

        if (mounted) {
          setState(() {
            _images.addAll(newImages);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al seleccionar imágenes")),
        );
      }
    }
  }

  Future<void> _submit(BuildContext context) async 
  {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
                          .from("profiles")
                          .select("nombre")
                          .eq("id", user.id)
                          .single();
    final nombre = response["nombre"] as String;

    final desc = _descController.text.trim();
    final lugar = _lugarController.text.trim();
    final xStr = _coordXController.text.trim();
    final yStr = _coordYController.text.trim();
    final x = double.tryParse(xStr);
    final y = double.tryParse(yStr);

    if (desc.isEmpty || _images.isEmpty || lugar.isEmpty || x == null || y == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos correctamente')),
      );
      return;
    }

    final entryId = _uuid.v4();
    final List<String> imageUrls = []; // Lista para almacenar URLs

    final List<Future<String>> uploadTasks = [];
    // 1. Subir imágenes y obtener URLs
    for (final image in _images) {
      final fileExt = extension(image.path);
      final fileName = '${_uuid.v4()}$fileExt';
      final filePath = 'entries/$entryId/$fileName';

      uploadTasks.add(() async {
        try {
          // Subir imagen
          await supabase.storage
              .from('entries')
              .uploadBinary(filePath, await image.readAsBytes());

          // Obtener URL pública
          final publicUrl = supabase.storage
              .from('entries')
              .getPublicUrl(filePath);

          imageUrls.add(publicUrl); // Guardar URL en la lista

          return publicUrl;
        }
        catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir imagen: ${e.toString()}')),
          );
          rethrow;
        }
      }());
    }
    
    try
    {
      final imageUrls = await Future.wait(uploadTasks);
        await supabase.from('entries').insert({
        'id': entryId,
        "author": nombre,
        'user_id': user.id,
        'description': desc,
        'lugar': lugar,
        'coordenadax': x,
        'coordenaday': y,
        'images': imageUrls,
      });

      Navigator.pop(context);
    }
    catch(e)
    {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al registrar la nueva reseña '${e}'"))
      );
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _lugarController.dispose();
    _coordXController.dispose();
    _coordYController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lugarController,
              decoration: const InputDecoration(
                labelText: 'Lugar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coordXController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Coordenada X',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _coordYController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Coordenada Y',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _pickImages(context),
              icon: const Icon(Icons.photo_library),
              label: const Text("Seleccionar imágenes"),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _images.map((file) => _buildImageThumbnail(file)).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _submit(context);
              },
              child: const Text("Publicar"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(File file) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 100,
              height: 100,
              color: Colors.grey,
              child: const Icon(Icons.error),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _images.remove(file);
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}