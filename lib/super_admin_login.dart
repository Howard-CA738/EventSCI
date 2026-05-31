import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/prefs_helper.dart';

const _kEmailJSServiceId  = 'service_cuw8hja';
const _kEmailJSTemplateId = 'template_bvsuc3e';
const _kEmailJSPublicKey  = 'sj0VpynB7nsm9tHbV';

class SuperAdminAuthService {
  static const String _userTypeSuperAdmin = 'superAdmin';

  static Future<String?> login(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('superadmins')
          .doc(uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        return 'No tienes permisos de administrador.';
      }

      await PrefsHelper.saveUserData(
        userType: _userTypeSuperAdmin,
        userName: doc.data()?['nombre'] ?? 'Administrador',
        userId: uid,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'Error inesperado. Intenta de nuevo.';
    }
  }

  static Future<String?> enviarCodigoEmail(String uid, String email) async {
  try {
    final codigo = (100000 + Random().nextInt(900000)).toString();
    final expira = DateTime.now().add(const Duration(minutes: 5));

    await FirebaseFirestore.instance
        .collection('superadmins')
        .doc(uid)
        .collection('otp_codes')
        .doc('current')
        .set({
      'code': codigo,
      'expiresAt': Timestamp.fromDate(expira),
      'usado': false,
    });

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': _kEmailJSServiceId,
        'template_id': _kEmailJSTemplateId,
        'user_id': _kEmailJSPublicKey,
        'template_params': {
          'to_email': email,
          'codigo': codigo,
        },
      }),
    );

    debugPrint('EmailJS status: ${response.statusCode}');
    debugPrint('EmailJS body: ${response.body}');

    if (response.statusCode != 200) {
      return 'Error al enviar el correo. Intenta de nuevo.';
    }

    return null;
  } catch (e) {
    debugPrint('Error enviando email: $e');
    return 'Error al enviar el correo.';
  }
}

  static Future<String?> verificarCodigo(String uid, String codigo) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('superadmins')
          .doc(uid)
          .collection('otp_codes')
          .doc('current')
          .get();

      if (!doc.exists) return 'Solicita un nuevo código.';

      final data = doc.data()!;
      final expira = (data['expiresAt'] as Timestamp).toDate();
      final usado  = data['usado'] as bool? ?? false;

      if (usado) return 'El código ya fue usado. Solicita uno nuevo.';
      if (DateTime.now().isAfter(expira)) return 'El código expiró. Solicita uno nuevo.';
      if (data['code'] != codigo) return 'Código incorrecto. Verifica e intenta de nuevo.';

      await FirebaseFirestore.instance
          .collection('superadmins')
          .doc(uid)
          .collection('otp_codes')
          .doc('current')
          .update({'usado': true});

      return null;
    } catch (e) {
      debugPrint('Error verificando código: $e');
      return 'Error al verificar el código.';
    }
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await PrefsHelper.logout();
  }

  static Future<bool> sesionActiva() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final tipo = await PrefsHelper.getUserType();
    return tipo == _userTypeSuperAdmin;
  }

  static String _mensajeError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contraseña incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'Error al iniciar sesión ($code).';
    }
  }
}