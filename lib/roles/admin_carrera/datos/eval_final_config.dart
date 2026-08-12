import 'package:cloud_firestore/cloud_firestore.dart';

class EvalFinalConfig {
  double pctAsistNoSel;
  double pctDocenteNoSel;
  bool incluirDocenteNoSel;
  String modalidad;
  double pctAsistSel;
  double pctJuradoSel;
  double pctAsistSelMixta;
  double pctJuradoSelMixta;
  double pctDocenteSelMixta;

  EvalFinalConfig({
    this.pctAsistNoSel = 100,
    this.pctDocenteNoSel = 0,
    this.incluirDocenteNoSel = false,
    this.modalidad = 'jurado',
    this.pctAsistSel = 40,
    this.pctJuradoSel = 60,
    this.pctAsistSelMixta = 30,
    this.pctJuradoSelMixta = 50,
    this.pctDocenteSelMixta = 20,
  });

  factory EvalFinalConfig.fromMap(Map<String, dynamic> m) => EvalFinalConfig(
        pctAsistNoSel: ((m['pctAsistNoSel'] ?? 100) as num).toDouble(),
        pctDocenteNoSel: ((m['pctDocenteNoSel'] ?? 0) as num).toDouble(),
        incluirDocenteNoSel: (m['incluirDocenteNoSel'] as bool?) ?? false,
        modalidad: (m['modalidad'] as String?) ?? 'jurado',
        pctAsistSel: ((m['pctAsistSel'] ?? 40) as num).toDouble(),
        pctJuradoSel: ((m['pctJuradoSel'] ?? 60) as num).toDouble(),
        pctAsistSelMixta: ((m['pctAsistSelMixta'] ?? 30) as num).toDouble(),
        pctJuradoSelMixta: ((m['pctJuradoSelMixta'] ?? 50) as num).toDouble(),
        pctDocenteSelMixta:
            ((m['pctDocenteSelMixta'] ?? 20) as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'pctAsistNoSel': pctAsistNoSel,
        'pctDocenteNoSel': pctDocenteNoSel,
        'incluirDocenteNoSel': incluirDocenteNoSel,
        'modalidad': modalidad,
        'pctAsistSel': pctAsistSel,
        'pctJuradoSel': pctJuradoSel,
        'pctAsistSelMixta': pctAsistSelMixta,
        'pctJuradoSelMixta': pctJuradoSelMixta,
        'pctDocenteSelMixta': pctDocenteSelMixta,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
