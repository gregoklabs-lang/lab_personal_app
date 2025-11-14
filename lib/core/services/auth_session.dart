import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Maneja la informacion basica del usuario autenticado.
class AuthSession {
  AuthSession._();

  static final AuthSession I = AuthSession._();

  /// Identificador del usuario autenticado (UUID).
  String? userId;

  /// Alias en snake_case por compatibilidad con el requerimiento original.
  // ignore: non_constant_identifier_names
  String? get user_id => userId;

  /// Actualiza la informacion del usuario actual y genera logs.
  void refreshCurrentUser() {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      userId = null;
      developer.log('No hay usuario logeado.', name: 'AuthSession');
      return;
    }

    userId = user.id;
    developer.log('Usuario autenticado: ${user.email}', name: 'AuthSession');
    developer.log('user_id (UUID): $userId', name: 'AuthSession');
  }
}
