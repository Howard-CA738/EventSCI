import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BuscarEstudianteGlobalScreen extends StatefulWidget {
  const BuscarEstudianteGlobalScreen({super.key});

  @override
  State<BuscarEstudianteGlobalScreen> createState() =>
      _BuscarEstudianteGlobalScreenState();
}

class _BuscarEstudianteGlobalScreenState
    extends State<BuscarEstudianteGlobalScreen> {
  static const Color _primaryColor = Color(0xFF1E3A5F);
  static const Color _surfaceColor = Color(0xFFE8EDF2);
  static const Color _subtextColor = Color(0xFF64748B);
  static const double _minTapTarget = 44.0;
  static const int _minChars = 2;
  static const int _resultLimit = 20;
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  int _searchToken = 0;

  bool _isSearching = false;
  bool _hasSearched = false;
  bool _hasError = false;
  List<Map<String, dynamic>> _results = [];
  String _searchTerm = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _normalizar(String texto) {
    var normalized = texto.trim().toLowerCase();
    const acentos = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    acentos.forEach((a, r) => normalized = normalized.replaceAll(a, r));
    return normalized.replaceAll(RegExp(r'\s+'), '');
  }

  void _onSearchChanged(String value) {
    setState(() => _searchTerm = value);
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < _minChars) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _hasError = false;
        _results = [];
      });
      return;
    }
    _debounce = Timer(_debounceDuration, () => _ejecutarBusqueda(trimmed));
  }

  Future<void> _ejecutarBusqueda(String term) async {
    final int currentToken = ++_searchToken;
    setState(() {
      _isSearching = true;
      _hasError = false;
    });

    try {
      final normUsername = _normalizar(term);
      final codigoTerm = term.trim();

      final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _firestore
            .collectionGroup('students')
            .orderBy('codigoUniversitario')
            .startAt([codigoTerm])
            .endAt(['$codigoTerm\uf8ff'])
            .limit(_resultLimit)
            .get(),
        _firestore
            .collectionGroup('students')
            .orderBy('username')
            .startAt([normUsername])
            .endAt(['$normUsername\uf8ff'])
            .limit(_resultLimit)
            .get(),
      ];

      final snapshots = await Future.wait(futures);

      if (!mounted || currentToken != _searchToken) return;

      final Map<String, Map<String, dynamic>> merged = {};
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['path'] = doc.reference.path;
          merged[doc.reference.path] = data;
        }
      }

      final results = merged.values.toList()
        ..sort((a, b) =>
            (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

      setState(() {
        _results = results;
        _isSearching = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted || currentToken != _searchToken) return;
      setState(() {
        _hasError = true;
        _isSearching = false;
        _hasSearched = true;
        _results = [];
      });
    }
  }

  void _limpiarBusqueda() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchTerm = '';
      _results = [];
      _isSearching = false;
      _hasSearched = false;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
      child: Row(
        children: [
          SizedBox(
            width: _minTapTarget,
            height: _minTapTarget,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Volver',
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Buscar Estudiante',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: _minTapTarget, height: _minTapTarget),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: Column(
          children: [
            _buildSearchField(),
            Expanded(child: _buildResultsArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Código, nombre o apellido...',
              hintStyle: const TextStyle(color: _subtextColor, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: _primaryColor),
              suffixIcon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_primaryColor),
                        ),
                      ),
                    )
                  : (_searchTerm.isNotEmpty
                      ? SizedBox(
                          width: _minTapTarget,
                          height: _minTapTarget,
                          child: IconButton(
                            icon: const Icon(Icons.clear,
                                color: _subtextColor, size: 20),
                            onPressed: _limpiarBusqueda,
                            tooltip: 'Limpiar',
                          ),
                        )
                      : null),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primaryColor, width: 2),
              ),
            ),
          ),
          if (_searchTerm.trim().isNotEmpty &&
              _searchTerm.trim().length < _minChars) ...[
            const SizedBox(height: 10),
            Text(
              'Escribe al menos $_minChars caracteres para buscar',
              style: const TextStyle(fontSize: 12, color: _subtextColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    final trimmed = _searchTerm.trim();

    if (trimmed.length < _minChars) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search,
                    size: 46, color: _primaryColor),
              ),
              const SizedBox(height: 20),
              const Text(
                'Busca un estudiante',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escribe un código universitario, nombre o apellido.\n'
                'La búsqueda incluye todas las sedes, facultades y carreras.',
                style: TextStyle(fontSize: 13, color: _subtextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_isSearching && !_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            SizedBox(height: 16),
            Text('Buscando...',
                style: TextStyle(color: _subtextColor, fontSize: 13)),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'No se pudo realizar la búsqueda',
                style: TextStyle(
                    color: _primaryColor, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _ejecutarBusqueda(trimmed),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No se encontraron estudiantes para "$_searchTerm"',
                style: const TextStyle(
                    color: _primaryColor, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildStudentCard(_results[index]),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = (student['name'] ?? 'Sin nombre').toString();
    final codigo = (student['codigoUniversitario'] ?? 'Sin código').toString();
    final filial = (student['filial'] ?? '—').toString();
    final facultad = (student['facultad'] ?? '—').toString();
    final carrera = (student['carrera'] ?? '—').toString();
    final celular = (student['celular'] ?? '').toString();
    final email = (student['email'] ?? '').toString();
    final inicial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      inicial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _highlightedText(
                        name,
                        _searchTerm,
                        const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _highlightedText(
                        codigo,
                        _searchTerm,
                        TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _miniInfoRow(Icons.location_city, filial),
                  const SizedBox(height: 4),
                  _miniInfoRow(Icons.business, facultad),
                  const SizedBox(height: 4),
                  _miniInfoRow(Icons.school, carrera),
                ],
              ),
            ),
            if (celular.isNotEmpty || email.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (celular.isNotEmpty) _smallInfo(Icons.phone, celular),
                  if (email.isNotEmpty) _smallInfo(Icons.email, email),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _primaryColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: _primaryColor,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _smallInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _highlightedText(String text, String term, TextStyle style) {
    final trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return Text(text,
          style: style, overflow: TextOverflow.ellipsis, maxLines: 2);
    }
    final lowerText = text.toLowerCase();
    final lowerTerm = trimmedTerm.toLowerCase();
    final startIndex = lowerText.indexOf(lowerTerm);
    if (startIndex == -1) {
      return Text(text,
          style: style, overflow: TextOverflow.ellipsis, maxLines: 2);
    }
    final endIndex = startIndex + trimmedTerm.length;
    return RichText(
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: style.copyWith(
              backgroundColor: const Color(0xFFFFF3B0),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }
}