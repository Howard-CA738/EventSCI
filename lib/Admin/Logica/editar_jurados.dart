import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'filiales_service.dart';
import 'gestion_criterios.dart';

class EditarJuradosScreen extends StatefulWidget {
  const EditarJuradosScreen({super.key});

  @override
  State<EditarJuradosScreen> createState() => _EditarJuradosScreenState();
}

class _EditarJuradosScreenState extends State<EditarJuradosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();

  // ✅ NUEVO: Valores con sistema de filiales
  String? _filialSeleccionada;
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;

  // ✅ NUEVO: Listas dinámicas
  List<String> _filialesDisponibles = [];
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];
  List<Map<String, dynamic>> _jurados = [];

  bool _isLoadingFiliales = true;
  bool _isLoadingJurados = false;

  @override
  void initState() {
    super.initState();
    _cargarFiliales();
  }

  // ✅ NUEVO: Cargar filiales
  Future<void> _cargarFiliales() async {
    setState(() {
      _isLoadingFiliales = true;
    });

    try {
      final filiales = await _rubricasService.getFiliales();
      if (mounted) {
        setState(() {
          _filialesDisponibles = filiales;
          _isLoadingFiliales = false;
        });
      }
    } catch (e) {
      print('Error al cargar filiales: $e');
      if (mounted) {
        setState(() {
          _isLoadingFiliales = false;
        });
      }
    }
  }

  // ✅ NUEVO: Cuando cambia la filial
  Future<void> _onFilialChanged(String? filial) async {
    setState(() {
      _filialSeleccionada = filial;
      _facultadSeleccionada = null;
      _carreraSeleccionada = null;
      _jurados = [];
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
    });

    if (filial != null) {
      final facultades = await _rubricasService.getFacultadesByFilial(filial);
      if (mounted) {
        setState(() {
          _facultadesDisponibles = facultades;
        });
      }
    }
  }

  // ✅ NUEVO: Cuando cambia la facultad
  Future<void> _onFacultadChanged(String? facultad) async {
    setState(() {
      _facultadSeleccionada = facultad;
      _carreraSeleccionada = null;
      _jurados = [];
      _carrerasDisponibles = [];
    });

    if (_filialSeleccionada != null && facultad != null) {
      final carreras = await _rubricasService.getCarrerasByFacultad(
        _filialSeleccionada!,
        facultad,
      );
      if (mounted) {
        setState(() {
          _carrerasDisponibles = carreras;
        });
      }
    }
  }

  Future<void> _onCarreraChanged(String? carreraNombre) async {
    setState(() {
      _carreraSeleccionada = carreraNombre;
      _jurados = [];
    });

    if (carreraNombre != null &&
        _facultadSeleccionada != null &&
        _filialSeleccionada != null) {
      await _cargarJurados();
    }
  }

  // ✅ ACTUALIZADO: Cargar jurados filtrando por filial, facultad y carrera
  Future<void> _cargarJurados() async {
    if (_filialSeleccionada == null ||
        _facultadSeleccionada == null ||
        _carreraSeleccionada == null) {
      return;
    }

    setState(() {
      _isLoadingJurados = true;
    });

    try {
      final juradosSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('filial', isEqualTo: _filialSeleccionada)
          .where('facultad', isEqualTo: _facultadSeleccionada)
          .where('carrera', isEqualTo: _carreraSeleccionada)
          .get();

      final List<Map<String, dynamic>> juradosList = [];

      for (var doc in juradosSnapshot.docs) {
        final data = doc.data();

        // Manejar categorías como lista
        List<String> categorias = [];
        if (data['categorias'] != null) {
          categorias = List<String>.from(data['categorias']);
        } else if (data['categoria'] != null) {
          // Compatibilidad con datos antiguos
          categorias = [data['categoria']];
        }

        juradosList.add({
          'id': doc.id,
          'nombre': data['name'] ?? '',
          'usuario': data['usuario'] ?? '',
          'password': data['password'] ?? '',
          'filial': data['filial'] ?? '',
          'facultad': data['facultad'] ?? '',
          'carrera': data['carrera'] ?? '',
          'categorias': categorias,
        });
      }

      if (mounted) {
        setState(() {
          _jurados = juradosList;
          _isLoadingJurados = false;
        });

        if (juradosList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron jurados para estos filtros'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error al cargar jurados: $e');
      if (mounted) {
        setState(() {
          _isLoadingJurados = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar jurados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoEditar(Map<String, dynamic> jurado) {
    final nombreController = TextEditingController(text: jurado['nombre']);
    final usuarioController = TextEditingController(text: jurado['usuario']);
    final passwordController = TextEditingController(text: jurado['password']);
    List<String> categoriasSeleccionadas = List<String>.from(
      jurado['categorias'],
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5490).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit,
                  color: Color(0xFF1A5490),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Editar Jurado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ NUEVO: Mostrar ubicación del jurado (no editable)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.blue.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ubicación del Jurado',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: _rubricasService.getNombreFilial(
                          jurado['filial'],
                        ),
                        builder: (context, snapshot) {
                          final nombreFilial =
                              snapshot.data ?? jurado['filial'];
                          return Text(
                            'Campus: $nombreFilial\nFacultad: ${jurado['facultad']}\nCarrera: ${jurado['carrera']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                              height: 1.4,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo',
                    prefixIcon: const Icon(
                      Icons.person,
                      color: Color(0xFF1A5490),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A5490),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usuarioController,
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: const Icon(
                      Icons.account_circle,
                      color: Color(0xFF1A5490),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A5490),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(
                      Icons.lock,
                      color: Color(0xFF1A5490),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A5490),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de múltiples categorías
                FutureBuilder<List<String>>(
                  future: _obtenerCategorias(
                    jurado['filial'],
                    jurado['facultad'],
                    jurado['carrera'],
                  ),
                  builder: (context, catSnapshot) {
                    if (!catSnapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final categorias = catSnapshot.data!;

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.category,
                                  color: Color(0xFF1A5490),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Categorías',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                if (categoriasSeleccionadas.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A5490),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${categoriasSeleccionadas.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: categorias.length,
                              itemBuilder: (context, index) {
                                final categoria = categorias[index];
                                final isSelected = categoriasSeleccionadas
                                    .contains(categoria);

                                return CheckboxListTile(
                                  title: Text(
                                    categoria,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  value: isSelected,
                                  activeColor: const Color(0xFF1A5490),
                                  onChanged: (bool? value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        categoriasSeleccionadas.add(categoria);
                                      } else {
                                        categoriasSeleccionadas.remove(
                                          categoria,
                                        );
                                      }
                                    });
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Mostrar categorías seleccionadas como chips
                if (categoriasSeleccionadas.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: categoriasSeleccionadas.map((cat) {
                        return Chip(
                          label: Text(
                            cat,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: const Color(0xFF1A5490),
                          deleteIcon: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                          onDeleted: () {
                            setDialogState(() {
                              categoriasSeleccionadas.remove(cat);
                            });
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (categoriasSeleccionadas.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debe seleccionar al menos una categoría'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                await _actualizarJurado(
                  jurado['id'],
                  nombreController.text,
                  usuarioController.text,
                  passwordController.text,
                  categoriasSeleccionadas,
                );
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5490),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ACTUALIZADO: Obtener categorías usando filialId
  Future<List<String>> _obtenerCategorias(
    String filialId,
    String facultad,
    String carreraNombre,
  ) async {
    try {
      final eventsSnapshot = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: filialId)
          .where('facultad', isEqualTo: facultad)
          .where('carreraNombre', isEqualTo: carreraNombre)
          .get();

      final Set<String> categoriasSet = {};

      for (var eventDoc in eventsSnapshot.docs) {
        final proyectosSnapshot = await _firestore
            .collection('events')
            .doc(eventDoc.id)
            .collection('proyectos')
            .get();

        for (var proyectoDoc in proyectosSnapshot.docs) {
          final data = proyectoDoc.data();
          final clasificacion = data['Clasificación'] as String?;

          if (clasificacion != null && clasificacion.isNotEmpty) {
            categoriasSet.add(clasificacion);
          }
        }
      }

      return categoriasSet.toList()..sort();
    } catch (e) {
      print('Error al obtener categorías: $e');
      return [];
    }
  }

  Future<void> _actualizarJurado(
    String id,
    String nombre,
    String usuario,
    String password,
    List<String> categorias,
  ) async {
    try {
      await _firestore.collection('users').doc(id).update({
        'name': nombre,
        'usuario': usuario,
        'password': password,
        'categorias': categorias,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jurado actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarJurados();
      }
    } catch (e) {
      print('Error al actualizar jurado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminarJurado(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirmar Eliminación',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Está seguro de eliminar al jurado "$nombre"?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _firestore.collection('users').doc(id).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jurado eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          await _cargarJurados();
        }
      } catch (e) {
        print('Error al eliminar jurado: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Regresar',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ver y Editar Jurados',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // Filtros
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Icono
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.filter_list,
                              size: 40,
                              color: Color(0xFF1A5490),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ✅ NUEVO: Filial
                          DropdownButtonFormField<String>(
                            value: _filialSeleccionada,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Filial',
                              prefixIcon: const Icon(
                                Icons.location_city,
                                color: Color(0xFF1A5490),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1A5490),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            selectedItemBuilder: (context) {
                              return _filialesDisponibles.map((filialId) {
                                return FutureBuilder<String>(
                                  future: _rubricasService.getNombreFilial(
                                    filialId,
                                  ),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? filialId,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                );
                              }).toList();
                            },
                            items: _filialesDisponibles.map((filialId) {
                              return DropdownMenuItem(
                                value: filialId,
                                child: FutureBuilder<String>(
                                  future: _rubricasService.getNombreFilial(
                                    filialId,
                                  ),
                                  builder: (context, snapshot) {
                                    return Text(snapshot.data ?? filialId);
                                  },
                                ),
                              );
                            }).toList(),
                            onChanged: _onFilialChanged,
                            menuMaxHeight: 300,
                          ),
                          const SizedBox(height: 16),

                          // Facultad
                          DropdownButtonFormField<String>(
                            value: _facultadSeleccionada,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Facultad',
                              prefixIcon: const Icon(
                                Icons.school,
                                color: Color(0xFF1A5490),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1A5490),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            selectedItemBuilder: (context) {
                              return _facultadesDisponibles.map((value) {
                                return Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }).toList();
                            },
                            items: _facultadesDisponibles.map((facultad) {
                              return DropdownMenuItem(
                                value: facultad,
                                child: Text(facultad),
                              );
                            }).toList(),
                            onChanged: _filialSeleccionada == null
                                ? null
                                : _onFacultadChanged,
                            menuMaxHeight: 300,
                          ),
                          const SizedBox(height: 16),

                          // Carrera
                          DropdownButtonFormField<String>(
                            value: _carreraSeleccionada,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Carrera',
                              prefixIcon: const Icon(
                                Icons.book,
                                color: Color(0xFF1A5490),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1A5490),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            selectedItemBuilder: (context) {
                              return _carrerasDisponibles.map((carrera) {
                                return Text(
                                  carrera['nombre'] as String,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }).toList();
                            },
                            items: _carrerasDisponibles.map((carrera) {
                              return DropdownMenuItem(
                                value: carrera['nombre'] as String,
                                child: Text(carrera['nombre'] as String),
                              );
                            }).toList(),
                            onChanged: _facultadSeleccionada == null
                                ? null
                                : _onCarreraChanged,
                            menuMaxHeight: 300,
                          ),
                        ],
                      ),
                    ),

                    // Lista de Jurados
                    Expanded(
                      child: _isLoadingJurados
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF1A5490),
                              ),
                            )
                          : _jurados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _filialSeleccionada == null ||
                                            _facultadSeleccionada == null ||
                                            _carreraSeleccionada == null
                                        ? 'Seleccione filial, facultad y carrera'
                                        : 'No hay jurados registrados',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              itemCount: _jurados.length,
                              itemBuilder: (context, index) {
                                final jurado = _jurados[index];
                                final categorias =
                                    jurado['categorias'] as List<String>;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF1A5490),
                                      radius: 28,
                                      child: Text(
                                        jurado['nombre'][0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      jurado['nombre'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Usuario: ${jurado['usuario']}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Mostrar categorías como chips pequeños
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: categorias.map((cat) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF1A5490,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF1A5490,
                                                  ).withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                cat,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF1A5490),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Color(0xFF1A5490),
                                          ),
                                          onPressed: () =>
                                              _mostrarDialogoEditar(jurado),
                                          tooltip: 'Editar',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _eliminarJurado(
                                            jurado['id'],
                                            jurado['nombre'],
                                          ),
                                          tooltip: 'Eliminar',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
