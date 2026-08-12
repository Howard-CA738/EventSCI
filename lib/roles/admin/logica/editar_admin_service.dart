import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditarAdminService {
  Future<Map<String, dynamic>?> cargarDatos(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('superadmins').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> reautenticar(User user, String currentPassword) {
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    return user.reauthenticateWithCredential(credential);
  }

  Future<void> actualizarPassword(User user, String nuevaPassword) {
    return user.updatePassword(nuevaPassword);
  }

  Future<void> actualizarEmail(User user, String nuevoEmail) {
    return user.verifyBeforeUpdateEmail(nuevoEmail);
  }

  Future<void> guardarDatos({
    required String uid,
    required String nombre,
    required String nuevoEmail,
    required bool emailCambia,
  }) {
    return FirebaseFirestore.instance.collection('superadmins').doc(uid).update({
      'nombre': nombre,
      if (!emailCambia) 'email': nuevoEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
