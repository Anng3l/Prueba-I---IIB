import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// Obtener comentarios raíz con información de usuario y respuestas
Future<List<Map<String, dynamic>>> fetchCommentsWithReplies(String entryId) async {
  final response = await supabase
      .from('comments')
      .select('''
        id,
        content,
        created_at,
        entry_id,
        user_id,
        parent_id,
        profiles:user_id (id, nombre, foto_url),
        replies:comments!parent_id (
          id,
          content,
          created_at,
          user_id,
          parent_id,
          profiles:user_id (id, nombre, foto_url)
        )
      ''')
      .eq('entry_id', entryId)
      .isFilter("parent_id", null)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
}

/// Crear comentario (o respuesta)
Future<Map<String, dynamic>> postComment({
  required String entryId,
  required String content,
  String? parentId,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception("No autenticado");

  if (content.isEmpty) return {};

  final response = await supabase
      .from('comments')
      .insert({
        'entry_id': entryId,
        'content': content,
        'user_id': user.id,
        'parent_id': parentId,
      })
      .select('''
        id,
        content,
        created_at,
        user_id,
        parent_id,
        profiles:user_id (id, nombre, foto_url)
      ''')
      .single();

  return response as Map<String, dynamic>;
}

/// Obtener respuestas de un comentario con información de usuario
Future<List<Map<String, dynamic>>> fetchRepliesWithProfile(String parentId) async {
  final response = await supabase
      .from('comments')
      .select('''
        id,
        content,
        created_at,
        user_id,
        parent_id,
        profiles:user_id (id, nombre, foto_url)
      ''')
      .eq('parent_id', parentId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
}