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

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _PublisherBlogPageState();
}

class _PublisherBlogPageState extends State<BlogPage> {
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
        title: const Text("Blog del Visitante"),
        actions: [
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


