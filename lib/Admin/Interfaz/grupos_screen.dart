import 'package:flutter/material.dart';
import '/admin/logica/grupos.dart';
import '/admin/logica/agregar_proyectos.dart';

class GruposScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;

  const GruposScreen({super.key, required this.eventData});

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen>
    with TickerProviderStateMixin {
  final GruposService _gruposService = GruposService();
  bool _isLoading = false;
  bool _isLoadingProjects = false;
  List<Map<String, dynamic>> _estudiantesImportados = [];
  Map<String, List<Map<String, dynamic>>> _estudiantesPorCategoria = {};
  List<Map<String, dynamic>> _proyectosExistentes = [];

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _cargarProyectosExistentes();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C5F7C),
      appBar: AppBar(
        title: Text(
          'Grupos - ${widget.eventData['name']}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2C5F7C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add_box),
              onPressed: _navegarAAgregarProyecto,
              tooltip: 'Agregar proyecto manualmente',
            ),
          ),
          if (_proyectosExistentes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: _mostrarDialogoEliminarTodos,
                tooltip: 'Eliminar todos los proyectos',
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImportCard(),
                  const SizedBox(height: 20),
                  if (_isLoadingProjects) ...[
                    _buildLoadingIndicator(),
                  ] else if (_proyectosExistentes.isNotEmpty) ...[
                    _buildExistingProjectsCard(),
                    const SizedBox(height: 20),
                  ],
                  if (_estudiantesPorCategoria.isNotEmpty) ...[
                    _buildImportedProjectsCard(),
                  ] else if (_proyectosExistentes.isEmpty) ...[
                    _buildEmptyState(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navegarAAgregarProyecto() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AgregarProyectoScreen(
          eventData: widget.eventData,
          gruposService: _gruposService,
          onProyectoAgregado: _cargarProyectosExistentes,
        ),
      ),
    );
  }

  Widget _buildImportCard() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _isLoading ? null : _importarExcel,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.upload_file,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Importar Proyectos',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _isLoading ? null : _importarExcel,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLoading)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Color(0xFF4CAF50),
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.cloud_upload,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isLoading
                                        ? 'Importando...'
                                        : 'Seleccionar Archivo Excel',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExistingProjectsCard() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9800), Color(0xFFFF6F00)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.folder_open,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Proyectos Existentes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_proyectosExistentes.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF9800),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildProyectosExistentes(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportedProjectsCard() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Proyectos Recién Importados',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_estudiantesImportados.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildCategoriesList(_estudiantesPorCategoria),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesList(
    Map<String, List<Map<String, dynamic>>> categorias,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categorias.keys.length,
      itemBuilder: (context, index) {
        final categoria = categorias.keys.elementAt(index);
        final estudiantes = categorias[categoria]!;
        return _buildCategoryCard(categoria, estudiantes, index);
      },
    );
  }

  Widget _buildCategoryCard(
    String categoria,
    List<Map<String, dynamic>> items,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getColorForCategory(index).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getColorForCategory(index).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    categoria,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${items.length} proyecto${items.length != 1 ? 's' : ''}',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getColorForCategory(index),
                          _getColorForCategory(index).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        items.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  children:
                      items.map((item) => _buildProjectItem(item)).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.assignment,
            size: 20,
            color: Color(0xFF2C5F7C),
          ),
        ),
        title: Text(
          item['Código'] ?? 'Sin código',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['Título'] != null) ...[
              const SizedBox(height: 4),
              Text(
                item['Título'],
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item['Integrantes'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item['Integrantes'],
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProyectosExistentes() {
    final proyectosPorCategoria =
        _gruposService.agruparPorCategoria(_proyectosExistentes);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: proyectosPorCategoria.keys.length,
      itemBuilder: (context, index) {
        final categoria = proyectosPorCategoria.keys.elementAt(index);
        final proyectos = proyectosPorCategoria[categoria]!;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      categoria,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${proyectos.length} proyecto${proyectos.length != 1 ? 's' : ''}',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getColorForCategory(index),
                            _getColorForCategory(index).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          proyectos.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    children: proyectos
                        .map((p) => _buildExistingProjectItem(p))
                        .toList(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExistingProjectItem(Map<String, dynamic> proyecto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _navegarADetallesProyecto(proyecto),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.assignment,
            size: 20,
            color: Color(0xFF2C5F7C),
          ),
        ),
        title: Text(
          proyecto['Código'] ?? 'Sin código',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (proyecto['Título'] != null) ...[
              const SizedBox(height: 4),
              Text(
                proyecto['Título'],
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (proyecto['Integrantes'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      proyecto['Integrantes'],
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (proyecto['importedAt'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 11, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _gruposService.formatDate(proyecto['importedAt']),
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _navegarADetallesProyecto(Map<String, dynamic> proyecto) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetalleProyectoScreen(
          proyecto: proyecto,
          eventData: widget.eventData,
          gruposService: _gruposService,
          onProyectoActualizado: _cargarProyectosExistentes,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF2C5F7C)),
            ),
            const SizedBox(height: 20),
            Text(
              'Cargando proyectos...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C5F7C).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 60,
                    color: const Color(0xFF2C5F7C).withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No hay proyectos importados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Importa un archivo Excel para comenzar',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarDialogoEliminarTodos() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF44336).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_sweep,
                    color: Color(0xFFF44336)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child:
                    Text('Eliminar Todos', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar TODOS los ${_proyectosExistentes.length} proyectos del evento?\n\nEsta acción no se puede deshacer.',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _eliminarTodosLosProyectos();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF44336),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Eliminar Todos'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _eliminarTodosLosProyectos() async {
    setState(() => _isLoadingProjects = true);
    try {
      await _gruposService.eliminarTodosLosProyectos(
          widget.eventData['id']);
      await _cargarProyectosExistentes();
      _mostrarMensaje(
        'Todos los proyectos han sido eliminados exitosamente',
        Colors.orange,
      );
    } catch (e) {
      _mostrarError('Error al eliminar los proyectos');
    } finally {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _cargarProyectosExistentes() async {
    setState(() => _isLoadingProjects = true);
    try {
      final proyectos = await _gruposService.cargarProyectosExistentes(
        widget.eventData['id'],
      );
      setState(() {
        _proyectosExistentes = proyectos;
        _isLoadingProjects = false;
      });
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _importarExcel() async {
    try {
      setState(() => _isLoading = true);

      final proyectos = await _gruposService.importarExcel();

      if (proyectos != null && proyectos.isNotEmpty) {
        setState(() {
          _estudiantesImportados = proyectos;
          _estudiantesPorCategoria =
              _gruposService.agruparPorCategoria(proyectos);
        });
        await _guardarProyectosEnEvento();
        await _cargarProyectosExistentes();
        _mostrarMensajeExito();
      } else if (proyectos != null && proyectos.isEmpty) {
        _mostrarError(
          'No se encontraron datos válidos en el archivo Excel. '
          'Verifica que tenga las columnas: CÓDIGO, TÍTULO DE INVESTIGACIÓN/PROYECTO, INTEGRANTES, CLASIFICACIÓN',
        );
      }
    } catch (e) {
      _mostrarError('Error al importar archivo: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarProyectosEnEvento() async {
    if (_estudiantesImportados.isEmpty) return;

    try {
      // [FIX] Se pasa eventData para que cada proyecto guarde
      // filialId, facultad, carreraId y carreraNombre.
      await _gruposService.guardarProyectosEnEvento(
        widget.eventData['id'],
        _estudiantesImportados,
        eventData: widget.eventData, // ← nuevo
      );
      setState(() {
        _estudiantesImportados.clear();
        _estudiantesPorCategoria.clear();
      });
    } catch (e) {
      _mostrarError('Error al guardar proyectos en la base de datos');
    }
  }

  Color _getColorForCategory(int index) {
    const colors = [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFFF44336),
      Color(0xFF009688),
      Color(0xFFFFEB3B),
      Color(0xFF3F51B5),
    ];
    return colors[index % colors.length];
  }

  void _mostrarMensajeExito() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Se importaron ${_estudiantesImportados.length} proyectos '
                'exitosamente al evento "${widget.eventData['name']}"',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
                child: Text(mensaje, style: const TextStyle(fontSize: 15))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
                child: Text(mensaje, style: const TextStyle(fontSize: 15))),
          ],
        ),
        backgroundColor: const Color(0xFFF44336),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ── Detalle del Proyecto (sin cambios) ───────────────────────────────────────
class DetalleProyectoScreen extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final Map<String, dynamic> eventData;
  final GruposService gruposService;
  final VoidCallback onProyectoActualizado;

  const DetalleProyectoScreen({
    super.key,
    required this.proyecto,
    required this.eventData,
    required this.gruposService,
    required this.onProyectoActualizado,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C5F7C),
      appBar: AppBar(
        title: const Text(
          'Detalles del Proyecto',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2C5F7C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editarProyecto(context),
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _eliminarProyecto(context),
            tooltip: 'Eliminar',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 20),
              _buildDetailCard(
                icon: Icons.qr_code,
                label: 'Código del Proyecto',
                value: proyecto['Código'] ?? 'Sin código',
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                icon: Icons.title,
                label: 'Título del Proyecto',
                value: proyecto['Título'] ?? 'Sin título',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                icon: Icons.people,
                label: 'Integrantes',
                value: proyecto['Integrantes'] ?? 'Sin integrantes',
                color: const Color(0xFFFF9800),
              ),
              const SizedBox(height: 16),
              _buildDetailCard(
                icon: Icons.category,
                label: 'Clasificación',
                value: proyecto['Clasificación'] ?? 'Sin clasificación',
                color: const Color(0xFF9C27B0),
              ),
              if (proyecto['Sala'] != null &&
                  proyecto['Sala'].toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDetailCard(
                  icon: Icons.meeting_room,
                  label: 'Sala Asignada',
                  value: proyecto['Sala'],
                  color: const Color(0xFF009688),
                ),
              ],
              if (proyecto['importedAt'] != null) ...[
                const SizedBox(height: 16),
                _buildDetailCard(
                  icon: Icons.access_time,
                  label: 'Fecha de Importación',
                  value: gruposService.formatDate(proyecto['importedAt']),
                  color: const Color(0xFF607D8B),
                ),
              ],
              const SizedBox(height: 32),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C5F7C), Color(0xFF1E4A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C5F7C).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.assignment,
                color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Proyecto',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  proyecto['Código'] ?? 'Sin código',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _actualizarScansExistentes(context),
            icon: const Icon(Icons.sync, size: 20),
            label: const Text(
              'Actualizar Asistencias Registradas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _editarProyecto(context),
                icon: const Icon(Icons.edit, size: 20),
                label: const Text('Editar Proyecto',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _eliminarProyecto(context),
                icon: const Icon(Icons.delete, size: 20),
                label: const Text('Eliminar',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _actualizarScansExistentes(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sync, color: Color(0xFFFF9800)),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Actualizar Asistencias')),
          ],
        ),
        content: Text(
          '¿Deseas actualizar todas las asistencias registradas del proyecto '
          '"${proyecto['Código']}" con la nueva clasificación '
          '"${proyecto['Clasificación']}"?\n\n'
          'Esto afectará todos los registros de asistencia existentes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Actualizando asistencias...',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Esto puede tomar unos momentos',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    try {
      await gruposService.actualizarCategoriaDeScansPorProyecto(
        eventData['id'],
        proyecto['Código'],
        proyecto['Clasificación'],
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        onProyectoActualizado();
        _mostrarMensaje(context,
            'Todas las asistencias fueron actualizadas exitosamente',
            Colors.green);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _mostrarError(context, 'Error al actualizar las asistencias: $e');
      }
    }
  }

  void _editarProyecto(BuildContext context) {
    final codigoCtrl =
        TextEditingController(text: proyecto['Código'] ?? '');
    final tituloCtrl =
        TextEditingController(text: proyecto['Título'] ?? '');
    final integrantesCtrl =
        TextEditingController(text: proyecto['Integrantes'] ?? '');
    final clasificacionCtrl =
        TextEditingController(text: proyecto['Clasificación'] ?? '');
    final salaCtrl =
        TextEditingController(text: proyecto['Sala'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: Color(0xFF2196F3)),
            ),
            const SizedBox(width: 12),
            const Text('Editar Proyecto'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(codigoCtrl, 'Código', Icons.qr_code),
              const SizedBox(height: 16),
              _buildTextField(tituloCtrl, 'Título', Icons.title,
                  maxLines: 2),
              const SizedBox(height: 16),
              _buildTextField(
                  integrantesCtrl, 'Integrantes', Icons.people,
                  maxLines: 2),
              const SizedBox(height: 16),
              _buildTextField(
                  clasificacionCtrl, 'Clasificación', Icons.category),
              const SizedBox(height: 16),
              _buildTextField(
                  salaCtrl, 'Sala (Opcional)', Icons.meeting_room),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _actualizarProyecto(context, {
                'Código': codigoCtrl.text.trim(),
                'Título': tituloCtrl.text.trim(),
                'Integrantes': integrantesCtrl.text.trim(),
                'Clasificación': clasificacionCtrl.text.trim(),
                'Sala': salaCtrl.text.trim(),
              });
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2C5F7C)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF2C5F7C), width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Future<void> _actualizarProyecto(
      BuildContext context, Map<String, dynamic> nuevosDatos) async {
    final clasificacionCambio =
        proyecto['Clasificación'] != nuevosDatos['Clasificación'];

    try {
      if (clasificacionCambio) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Actualizando proyecto...',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'También se actualizarán las asistencias registradas',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      }

      await gruposService.actualizarProyecto(
          eventData['id'], proyecto['docId'], nuevosDatos);

      if (clasificacionCambio && context.mounted) {
        Navigator.of(context).pop();
      }

      onProyectoActualizado();
      _mostrarMensaje(
        context,
        clasificacionCambio
            ? 'Proyecto y asistencias actualizados exitosamente'
            : 'Proyecto actualizado exitosamente',
        Colors.green,
      );
    } catch (e) {
      if (clasificacionCambio && context.mounted) {
        Navigator.of(context).pop();
      }
      _mostrarError(context, 'Error al actualizar el proyecto');
    }
  }

  void _eliminarProyecto(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF44336).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever,
                  color: Color(0xFFF44336)),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar el proyecto "${proyecto['Código']}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _eliminarProyectoConfirmado(context);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarProyectoConfirmado(BuildContext context) async {
    try {
      await gruposService.eliminarProyectoIndividual(
          eventData['id'], proyecto['docId']);
      onProyectoActualizado();
      _mostrarMensaje(
          context, 'Proyecto eliminado exitosamente', Colors.orange);
    } catch (e) {
      _mostrarError(context, 'Error al eliminar el proyecto');
    }
  }

  void _mostrarMensaje(
      BuildContext context, String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
            child: Text(mensaje, style: const TextStyle(fontSize: 15))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
            child: Text(mensaje, style: const TextStyle(fontSize: 15))),
      ]),
      backgroundColor: const Color(0xFFF44336),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
    ));
  }
}