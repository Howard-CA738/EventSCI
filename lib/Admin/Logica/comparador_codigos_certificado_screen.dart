import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kPrimario       = Color(0xFF1E3A5F);
const _kPrimario10     = Color(0x1A1E3A5F);
const _kPrimario40     = Color(0x661E3A5F);
const _kTextoGris      = Color(0xFF64748B);
const _kTextoGrisClaro = Color(0xFF94A3B8);
const _kTextoOscuro    = Color(0xFF334155);
const _kFondo          = Color(0xFFE8EDF2);
const _kCampoFondo     = Color(0xFFF8FAFC);
const _kVerde          = Color(0xFF16A34A);
const _kAmbar          = Color(0xFFF59E0B);
const _kRojo           = Color(0xFFDC2626);
const _kAzulInfo       = Color(0xFF2563EB);

/// Par código de estudiante ↔ código de certificado, construido desde
/// los campos 1 y 2 (misma posición/orden en ambas listas pegadas).
class _ParEntry {
  final String codigoEstudiante;
  final String codigoCertificado;
  const _ParEntry({required this.codigoEstudiante, required this.codigoCertificado});
}

class ComparadorCodigosCertificadoScreen extends StatefulWidget {
  const ComparadorCodigosCertificadoScreen({super.key});

  @override
  State<ComparadorCodigosCertificadoScreen> createState() =>
      _ComparadorCodigosCertificadoScreenState();
}

class _ComparadorCodigosCertificadoScreenState
    extends State<ComparadorCodigosCertificadoScreen> {
  // Campo 1 y 2: base completa pegada desde Excel.
  final _campo1Controller = TextEditingController(); // códigos de estudiante
  final _campo2Controller = TextEditingController(); // códigos de certificado

  // Campo 3: subconjunto de códigos a buscar dentro de la base.
  final _campo3Controller = TextEditingController();

  // Resultados: dos campos separados y copiables, en el mismo orden entre sí.
  final _resultadoCodigosController = TextEditingController();
  final _resultadoCertificadosController = TextEditingController();

  bool _listo = false; // true cuando campo1/campo2 ya fueron validados
  Map<String, _ParEntry> _mapa = {}; // clave normalizada -> par

  List<String> _noEncontrados = [];
  List<String> _duplicadosEnBase = [];
  int _totalBuscados = 0;
  int _totalEncontrados = 0;

  @override
  void dispose() {
    _campo1Controller.dispose();
    _campo2Controller.dispose();
    _campo3Controller.dispose();
    _resultadoCodigosController.dispose();
    _resultadoCertificadosController.dispose();
    super.dispose();
  }

  List<String> _parsearLineas(String texto) {
    return texto
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _normalizar(String s) => s.trim().toLowerCase();

  void _snack(String msg, {Color color = _kPrimario}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Paso 1: validar/emparejar campo 1 con campo 2 ──────────────────
  void _validarBase() {
    final codigos = _parsearLineas(_campo1Controller.text);
    final certificados = _parsearLineas(_campo2Controller.text);

    if (codigos.isEmpty || certificados.isEmpty) {
      _snack('⚠️ Pega los códigos de estudiante y de certificado', color: _kAmbar);
      return;
    }
    if (codigos.length != certificados.length) {
      _snack(
        '⚠️ Cantidad distinta: ${codigos.length} códigos de estudiante vs '
        '${certificados.length} códigos de certificado. Deben coincidir en '
        'cantidad y orden.',
        color: _kAmbar,
      );
      setState(() {
        _listo = false;
        _mapa = {};
      });
      return;
    }

    final mapa = <String, _ParEntry>{};
    final duplicados = <String>[];
    final vistos = <String>{};

    for (int i = 0; i < codigos.length; i++) {
      final key = _normalizar(codigos[i]);
      if (vistos.contains(key)) {
        duplicados.add(codigos[i]);
      }
      vistos.add(key);
      // Si el código está repetido, se queda con el último valor (igual
      // que el patrón usado en tus otras pantallas de importación).
      mapa[key] = _ParEntry(
        codigoEstudiante: codigos[i],
        codigoCertificado: certificados[i],
      );
    }

    setState(() {
      _mapa = mapa;
      _listo = true;
      _duplicadosEnBase = duplicados;
      _resultadoCodigosController.clear();
      _resultadoCertificadosController.clear();
      _noEncontrados = [];
      _totalBuscados = 0;
      _totalEncontrados = 0;
    });

    if (duplicados.isEmpty) {
      _snack('✅ ${codigos.length} pares código-certificado listos para buscar', color: _kVerde);
    } else {
      _snack(
        '⚠️ Base lista, pero hay ${duplicados.length} código(s) repetido(s) '
        '(se usó el último valor de cada uno)',
        color: _kAmbar,
      );
    }
  }

  // ── Paso 2: buscar códigos del campo 3 dentro de la base ───────────
  void _buscar() {
    if (!_listo) {
      _snack('⚠️ Primero valida la base (paso 1)', color: _kAmbar);
      return;
    }
    final buscados = _parsearLineas(_campo3Controller.text);
    if (buscados.isEmpty) {
      _snack('⚠️ Pega los códigos de estudiante que quieres buscar', color: _kAmbar);
      return;
    }

    final codigosResultado = <String>[];
    final certResultado = <String>[];
    final noEncontrados = <String>[];

    for (final codigo in buscados) {
      final par = _mapa[_normalizar(codigo)];
      if (par == null) {
        noEncontrados.add(codigo);
        continue;
      }
      codigosResultado.add(par.codigoEstudiante);
      certResultado.add(par.codigoCertificado);
    }

    setState(() {
      _resultadoCodigosController.text = codigosResultado.join('\n');
      _resultadoCertificadosController.text = certResultado.join('\n');
      _noEncontrados = noEncontrados;
      _totalBuscados = buscados.length;
      _totalEncontrados = codigosResultado.length;
    });

    if (noEncontrados.isEmpty) {
      _snack('✅ ${codigosResultado.length} código(s) encontrados y emparejados', color: _kVerde);
    } else {
      _snack(
        '⚠️ ${codigosResultado.length} encontrados, ${noEncontrados.length} '
        'no encontrados en la base',
        color: _kAmbar,
      );
    }
  }

  Future<void> _copiar(String texto, String etiqueta) async {
    if (texto.isEmpty) {
      _snack('Nada que copiar en $etiqueta', color: _kAmbar);
      return;
    }
    await Clipboard.setData(ClipboardData(text: texto));
    _snack('$etiqueta copiado al portapapeles', color: _kVerde);
  }

  void _limpiarTodo() {
    setState(() {
      _campo1Controller.clear();
      _campo2Controller.clear();
      _campo3Controller.clear();
      _resultadoCodigosController.clear();
      _resultadoCertificadosController.clear();
      _listo = false;
      _mapa = {};
      _noEncontrados = [];
      _duplicadosEnBase = [];
      _totalBuscados = 0;
      _totalEncontrados = 0;
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPrimario,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kFondo,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildCampo1Card(),
                  const SizedBox(height: 14),
                  _buildCampo2Card(),
                  const SizedBox(height: 14),
                  _buildValidarButton(),
                  if (_listo) ...[
                    const SizedBox(height: 14),
                    _buildResumenBase(),
                  ],
                  const SizedBox(height: 14),
                  _buildCampo3Card(),
                  if (_totalBuscados > 0) ...[
                    const SizedBox(height: 14),
                    _buildResultados(),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.search_rounded, color: _kPrimario, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Comparar Códigos de Certificado',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('Busca códigos de estudiante y obtén su certificado',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            tooltip: 'Limpiar todo',
            onPressed: _limpiarTodo,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      );

  Widget _card({required Widget child}) => Card(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _sectionTitle(IconData icon, String title, {Color color = _kPrimario}) => Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );

  Widget _buildCampo1Card() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.looks_one_rounded, '1. Códigos de estudiante (Excel)'),
        const SizedBox(height: 6),
        const Text(
          'Pega aquí TODOS los códigos de estudiante de tu Excel, en el mismo '
          'orden en que aparecen sus códigos de certificado en el campo 2.',
          style: TextStyle(fontSize: 11, color: _kTextoGrisClaro),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _campo1Controller,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Ej: 202012345\n202012346\n202012347...',
            hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
            filled: true, fillColor: _kCampoFondo,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ]),
    );
  }

  Widget _buildCampo2Card() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.looks_two_rounded, '2. Códigos de certificado (Excel)'),
        const SizedBox(height: 6),
        const Text(
          'Pega aquí los códigos de certificado, en el mismo orden y cantidad '
          'que los códigos de estudiante del campo 1.',
          style: TextStyle(fontSize: 11, color: _kTextoGrisClaro),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _campo2Controller,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Ej: EVT-26-F0401001\nEVT-26-F0401002...',
            hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
            filled: true, fillColor: _kCampoFondo,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ]),
    );
  }

  Widget _buildValidarButton() {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton.icon(
        onPressed: _validarBase,
        icon: const Icon(Icons.fact_check_outlined, size: 20),
        label: const Text('Validar y emparejar base'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimario, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildResumenBase() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.checklist_rounded, 'Base lista', color: _kVerde),
        const SizedBox(height: 8),
        Text('${_mapa.length} par(es) código-certificado cargados.',
            style: const TextStyle(fontSize: 12, color: _kTextoGris)),
        if (_duplicadosEnBase.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Códigos repetidos en la base (se usó el último valor de cada '
              'uno): ${_duplicadosEnBase.join(", ")}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildCampo3Card() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.looks_3_rounded, '3. Códigos a buscar',
            color: _listo ? _kPrimario : _kTextoGrisClaro),
        const SizedBox(height: 6),
        Text(
          _listo
              ? 'Pega los códigos de estudiante que quieres buscar dentro de la base cargada.'
              : 'Valida primero la base (paso 1) para habilitar la búsqueda.',
          style: const TextStyle(fontSize: 11, color: _kTextoGrisClaro),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _campo3Controller,
          enabled: _listo,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Ej: 202012345\n202012346...',
            hintStyle: const TextStyle(fontSize: 12, color: _kTextoGrisClaro),
            filled: true,
            fillColor: _listo ? _kCampoFondo : Colors.grey.shade100,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: _listo ? _buscar : null,
            icon: const Icon(Icons.search_rounded, size: 20),
            label: const Text('Buscar y emparejar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimario, foregroundColor: Colors.white,
              disabledBackgroundColor: _kPrimario40,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildResultados() {
    final encontrados = _totalEncontrados;
    final noEncontrados = _noEncontrados.length;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.done_all_rounded, 'Resultado de la búsqueda',
            color: noEncontrados == 0 ? _kVerde : _kAmbar),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statMini('$_totalBuscados', 'Buscados', _kPrimario)),
          const SizedBox(width: 6),
          Expanded(child: _statMini('$encontrados', 'Encontrados', _kVerde)),
          const SizedBox(width: 6),
          Expanded(
            child: _statMini('$noEncontrados', 'No encontrados',
                noEncontrados > 0 ? _kRojo : _kTextoGrisClaro),
          ),
        ]),
        const SizedBox(height: 14),

        // Campo A: códigos de estudiante encontrados.
        Row(children: [
          const Expanded(
            child: Text('Códigos de estudiante encontrados',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
          ),
          TextButton.icon(
            onPressed: () => _copiar(_resultadoCodigosController.text, 'Códigos de estudiante'),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: _kAzulInfo, padding: EdgeInsets.zero),
          ),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _resultadoCodigosController,
          readOnly: true,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: _kTextoOscuro),
          decoration: InputDecoration(
            filled: true, fillColor: _kCampoFondo,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),

        const SizedBox(height: 14),

        // Campo B: códigos de certificado correspondientes, mismo orden que el campo A.
        Row(children: [
          const Expanded(
            child: Text('Códigos de certificado (mismo orden)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimario)),
          ),
          TextButton.icon(
            onPressed: () => _copiar(_resultadoCertificadosController.text, 'Códigos de certificado'),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: _kAzulInfo, padding: EdgeInsets.zero),
          ),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _resultadoCertificadosController,
          readOnly: true,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: _kVerde, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true, fillColor: _kCampoFondo,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),

        if (_noEncontrados.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.error_outline, size: 16, color: _kRojo),
                SizedBox(width: 8),
                Expanded(
                  child: Text('No se encontraron en la base:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kRojo)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(_noEncontrados.join(', '),
                  style: const TextStyle(fontSize: 11.5, color: _kRojo, fontFamily: 'monospace')),
            ]),
          ),
        ],

        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _kPrimario10, borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 16, color: _kPrimario),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Copia cada campo por separado y pégalo en "Importar Códigos de '
                'Certificado": el primero en "Códigos de estudiante" y el '
                'segundo en "Códigos de certificado". Van en el mismo orden.',
                style: TextStyle(fontSize: 11, color: _kPrimario),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _statMini(String value, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.85))),
        ]),
      );
}