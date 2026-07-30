
import 'package:cloud_firestore/cloud_firestore.dart';




({String mime, String ext}) mimeDesdeRuta(String ruta) {
  final e = ruta.split('.').last.toLowerCase();
  if (e == 'jpg' || e == 'jpeg') return (mime: 'image/jpeg', ext: 'jpeg');
  return (mime: 'image/png', ext: 'png');
}

class FirmanteModel {
  final String docId;
  final String grado;
  final String nombre;
  final String cargo;
  final String storageUrl;
  final String storagePath;

  const FirmanteModel({
    required this.docId,
    required this.grado,
    required this.nombre,
    required this.cargo,
    required this.storageUrl,
    required this.storagePath,
  });

  bool get tieneImagen => storageUrl.isNotEmpty;
  bool get tieneDatos  => nombre.isNotEmpty;
  String get nombreCompleto => '$grado $nombre'.trim();





  factory FirmanteModel.vacio(String docId, String storageBasePath) =>
      FirmanteModel(
        docId: docId, grado: '', nombre: '', cargo: '',
        storageUrl: '', storagePath: storageBasePath,
      );

  factory FirmanteModel.fromMap(
      Map<String, dynamic> d, String docId, String storageBasePath) =>
      FirmanteModel(
        docId:       docId,
        grado:       d['grado']      ?? '',
        nombre:      d['nombre']     ?? '',
        cargo:       d['cargo']      ?? '',
        storageUrl:  d['storageUrl'] ?? '',
        storagePath: storageBasePath,
      );

  Map<String, dynamic> toMap() => {
    'grado':         grado,
    'nombre':        nombre,
    'cargo':         cargo,
    'storageUrl':    storageUrl,
    'actualizadoEn': FieldValue.serverTimestamp(),
  };

  FirmanteModel copyWith({
    String? grado, String? nombre, String? cargo, String? storageUrl,
  }) => FirmanteModel(
    docId:       docId,
    grado:       grado      ?? this.grado,
    nombre:      nombre     ?? this.nombre,
    cargo:       cargo      ?? this.cargo,
    storageUrl:  storageUrl ?? this.storageUrl,
    storagePath: storagePath,
  );
}