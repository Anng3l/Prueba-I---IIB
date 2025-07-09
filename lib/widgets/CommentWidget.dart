import 'package:archivos_app/services/supabase_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class CommentWidget extends StatefulWidget {
  final Map<String, dynamic> comment;
  final VoidCallback? onReplyPosted;

  const CommentWidget({
    super.key,
    required this.comment,
    this.onReplyPosted,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  List<Map<String, dynamic>> replies = [];
  bool showReplyField = false;
  bool isLoadingReplies = false;
  final replyController = TextEditingController();
  final profile = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    // Cargar respuestas iniciales si existen
    if (widget.comment['replies'] != null) {
      replies = List<Map<String, dynamic>>.from(widget.comment['replies']);
    }
  }

  Future<void> _loadReplies() async {
    setState(() => isLoadingReplies = true);
    try {
      final res = await fetchRepliesWithProfile(widget.comment['id']);
      setState(() => replies = res);
    } finally {
      setState(() => isLoadingReplies = false);
    }
  }

  Future<void> _postReply() async {


    try {
      await postComment(
        entryId: widget.comment['entry_id'],
        content: replyController.text.trim(),
        parentId: widget.comment['id'],
      );
      replyController.clear();
      setState(() => showReplyField = false);
      await _loadReplies();
      widget.onReplyPosted?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar asdasd: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentProfile = widget.comment['profiles'] ?? {};
    final createdAt = widget.comment['created_at'] != null
        ? DateTime.parse(widget.comment['created_at']).toLocal()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Colors.grey.shade300,
            width: 2,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del comentario
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: commentProfile['foto_url'] != null
                      ? NetworkImage(commentProfile['foto_url'])
                      : null,
                  child: commentProfile['foto_url'] == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commentProfile['nombre'] ?? 'Anónimo',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Contenido del comentario
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(widget.comment['content'] ?? ''),
            ),
            const SizedBox(height: 8),

            // Botones de acción
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Column(
                children: [
                  widget.comment["parent_id"] != null ? Column(children: []) :
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                    ),
                    onPressed: () => setState(() => showReplyField = !showReplyField),
                    child: Text(
                      "Responder",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  if (replies.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                      ),
                      onPressed: isLoadingReplies ? null : _loadReplies,
                      child: Text(
                        "\n${replies.length} ${replies.length == 1 ? 'respuesta' : 'respuestas'}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Campo para responder
            if (showReplyField)
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: replyController,
                      decoration: InputDecoration(
                        hintText: "Escribe tu respuesta...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => showReplyField = false),
                          child: const Text("Cancelar"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _postReply,
                          child: const Text("Responder"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Lista de respuestas
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Column(
                  children: replies
                      .map((reply) => CommentWidget(
                            comment: reply,
                            onReplyPosted: () {
                              _loadReplies();
                              widget.onReplyPosted?.call();
                            },
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return 'Hace ${(difference.inDays / 365).floor()} años';
    } else if (difference.inDays > 30) {
      return 'Hace ${(difference.inDays / 30).floor()} meses';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minutos';
    } else {
      return 'Justo ahora';
    }
  }
}