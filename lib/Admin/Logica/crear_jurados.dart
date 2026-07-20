import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'editar_jurados.dart';
import 'gestion_criterios.dart';

class CrearJuradosScreen extends StatefulWidget {
  const CrearJuradosScreen({super.key});

  @override
  State<CrearJuradosScreen> createState() => _CrearJuradosScreenState();
}

class _CrearJuradosScreenState extends State<CrearJuradosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RubricasService _rubricasService = RubricasService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _filialSeleccionada;
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;
  List<String> _categoriasSeleccionadas = [];

  List<String> _filialesDisponibles = [];
  final Map<String, String> _nombresFiliales = {};
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];
  List<String> _categoriasDisponibles = [];
  bool _cargandoCategorias = false;

  @override
  void initState() {
    super.initState();
    _cargarFiliales();
  }

  Future<void> _cargarFiliales() async {
    try {
      final filiales = await _rubricasService.getFiliales();
      if (mounted) {
        setState(() {
          _filialesDisponibles = filiales;
        });
        for (final filialId in filiales) {
          final nombre = await _rubricasService.getNombreFilial(filialId);
          if (mounted) {
            setState(() {
              _nombresFiliales[filialId] = nombre;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar filiales: $e');
    }
  }

  Future<void> _onFilialChanged(String? filial) async {
    setState(() {
      _filialSeleccionada = filial;
      _facultadSeleccionada = null;
      _carreraSeleccionada = null;
      _categoriasSeleccionadas = [];
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
      _categoriasDisponibles = [];
      _cargandoCategorias = false;
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

  Future<void> _onFacultadChanged(String? facultad) async {
    setState(() {
      _facultadSeleccionada = facultad;
      _carreraSeleccionada = null;
      _categoriasSeleccionadas = [];
      _carrerasDisponibles = [];
      _categoriasDisponibles = [];
      _cargandoCategorias = false;
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
      _categoriasSeleccionadas = [];
      _categoriasDisponibles = [];
      _cargandoCategorias = carreraNombre != null;
    });

    if (carreraNombre == null ||
        _facultadSeleccionada == null ||
        _filialSeleccionada == null) {
      return;
    }

    try {
      final eventsSnapshot = await _firestore
          .collection('events')
          .where('filialId', isEqualTo: _filialSeleccionada)
          .where('facultad', isEqualTo: _facultadSeleccionada)
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

      if (mounted) {
        setState(() {
          _categoriasDisponibles = categoriasSet.toList()..sort();
          _cargandoCategorias = false;
        });

        if (categoriasSet.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay proyectos registrados para esta carrera'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al cargar categorías: $e');
      if (mounted) {
        setState(() {
          _cargandoCategorias = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _crearJurado() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categoriasSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar al menos una categoría'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final juradoData = {
        'name': _nombreController.text.trim(),
        'usuario': _usuarioController.text.trim(),
        'password': _passwordController.text,
        'filial': _filialSeleccionada!,
        'facultad': _facultadSeleccionada!,
        'carrera': _carreraSeleccionada!,
        'categorias': _categoriasSeleccionadas,
        'userType': 'jurado',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final existingUser = await _firestore
          .collection('users')
          .where('usuario', isEqualTo: _usuarioController.text.trim())
          .get();

      if (existingUser.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: El usuario ya está registrado'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      await _firestore.collection('users').add(juradoData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jurado creado exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      _formKey.currentState!.reset();
      _nombreController.clear();
      _usuarioController.clear();
      _passwordController.clear();
      setState(() {
        _filialSeleccionada = null;
        _facultadSeleccionada = null;
        _carreraSeleccionada = null;
        _categoriasSeleccionadas = [];
        _facultadesDisponibles = [];
        _carrerasDisponibles = [];
        _categoriasDisponibles = [];
        _cargandoCategorias = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear jurado: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF1A5490)),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF1A5490), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 375;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Regresar',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Crear Jurados',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_document,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditarJuradosScreen(),
                        ),
                      );
                    },
                    tooltip: 'Ver y Editar Jurados',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
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
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      isNarrow ? 16 : 24,
                      16,
                      isNarrow ? 16 : 24,
                      32,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),

                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/icons/jurado.png',
                                width: isNarrow ? 54 : 70,
                                height: isNarrow ? 54 : 70,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.gavel,
                                    size: isNarrow ? 54 : 70,
                                    color: const Color(0xFF1A5490),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          TextFormField(
                            controller: _nombreController,
                            style: const TextStyle(fontSize: 15),
                            decoration: _buildInputDecoration(
                              labelText: 'Nombre Completo',
                              hintText: 'Ej: Dr. Juan Pérez López',
                              prefixIcon: Icons.person,
                            ),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingrese el nombre completo';
                              }
                              if (value.trim().length < 3) {
                                return 'El nombre debe tener al menos 3 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _usuarioController,
                            style: const TextStyle(fontSize: 15),
                            decoration: _buildInputDecoration(
                              labelText: 'Usuario',
                              hintText: 'Ej: jperez',
                              prefixIcon: Icons.account_circle,
                            ),
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingrese el usuario';
                              }
                              if (value.trim().length < 3) {
                                return 'El usuario debe tener al menos 3 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passwordController,
                            style: const TextStyle(fontSize: 15),
                            decoration: _buildInputDecoration(
                              labelText: 'Contraseña',
                              hintText: 'Mínimo 6 caracteres',
                              prefixIcon: Icons.lock,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                tooltip: _obscurePassword
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _crearJurado(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingrese una contraseña';
                              }
                              if (value.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            initialValue: _filialSeleccionada,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[600],
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            decoration: _buildInputDecoration(
                              labelText: 'Filial',
                              prefixIcon: Icons.location_city,
                            ),
                            items: _filialesDisponibles.map((filialId) {
                              final nombre =
                                  _nombresFiliales[filialId] ?? filialId;
                              return DropdownMenuItem(
                                value: filialId,
                                child: Text(
                                  nombre,
                                  style: const TextStyle(fontSize: 14.5),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            selectedItemBuilder: (BuildContext context) {
                              return _filialesDisponibles.map((filialId) {
                                final nombre =
                                    _nombresFiliales[filialId] ?? filialId;
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    nombre,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            onChanged: _onFilialChanged,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor seleccione una filial';
                              }
                              return null;
                            },
                            menuMaxHeight: 300,
                            dropdownColor: Colors.white,
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            initialValue: _facultadSeleccionada,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[600],
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            decoration: _buildInputDecoration(
                              labelText: 'Facultad',
                              prefixIcon: Icons.school,
                            ),
                            selectedItemBuilder: (BuildContext context) {
                              return _facultadesDisponibles.map((String value) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    value,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            items: _facultadesDisponibles.map((facultad) {
                              return DropdownMenuItem(
                                value: facultad,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    facultad,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: _filialSeleccionada == null
                                ? null
                                : _onFacultadChanged,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor seleccione una facultad';
                              }
                              return null;
                            },
                            menuMaxHeight: 300,
                            dropdownColor: Colors.white,
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            initialValue: _carreraSeleccionada,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[600],
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            decoration: _buildInputDecoration(
                              labelText: 'Carrera',
                              prefixIcon: Icons.book,
                            ),
                            selectedItemBuilder: (BuildContext context) {
                              return _carrerasDisponibles.map((carrera) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    carrera['nombre'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            items: _carrerasDisponibles.map((carrera) {
                              return DropdownMenuItem(
                                value: carrera['nombre'] as String,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    carrera['nombre'] as String,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: _facultadSeleccionada == null
                                ? null
                                : _onCarreraChanged,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor seleccione una carrera';
                              }
                              return null;
                            },
                            menuMaxHeight: 300,
                            dropdownColor: Colors.white,
                          ),
                          const SizedBox(height: 16),

                          _CategoriasSelector(
                            categoriasDisponibles: _categoriasDisponibles,
                            categoriasSeleccionadas: _categoriasSeleccionadas,
                            carreraSeleccionada: _carreraSeleccionada,
                            cargandoCategorias: _cargandoCategorias,
                            onToggle: (categoria, isSelected) {
                              setState(() {
                                if (isSelected) {
                                  _categoriasSeleccionadas.add(categoria);
                                } else {
                                  _categoriasSeleccionadas.remove(categoria);
                                }
                              });
                            },
                          ),

                          if (_categoriasSeleccionadas.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categoriasSeleccionadas.map((cat) {
                                  return Chip(
                                    label: Text(
                                      cat,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    backgroundColor: const Color(0xFF1A5490),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _categoriasSeleccionadas.remove(cat);
                                      });
                                    },
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.padded,
                                  );
                                }).toList(),
                              ),
                            ),

                          const SizedBox(height: 28),

                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _crearJurado,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A5490),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF1A5490).withValues(
                                      alpha: 0.6,
                                    ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 4,
                                shadowColor: const Color(
                                  0xFF1A5490,
                                ).withValues(alpha: 0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Crear Jurado',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'El jurado puede evaluar una o más categorías según su selección',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade900,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriasSelector extends StatelessWidget {
  final List<String> categoriasDisponibles;
  final List<String> categoriasSeleccionadas;
  final String? carreraSeleccionada;
  final bool cargandoCategorias;
  final void Function(String categoria, bool isSelected) onToggle;

  const _CategoriasSelector({
    required this.categoriasDisponibles,
    required this.categoriasSeleccionadas,
    required this.carreraSeleccionada,
    required this.cargandoCategorias,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.category, color: Color(0xFF1A5490)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Categorías / Proyectos',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (categoriasSeleccionadas.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A5490),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${categoriasSeleccionadas.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (cargandoCategorias)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cargando categorías...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else if (categoriasDisponibles.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                carreraSeleccionada == null
                    ? 'Seleccione una carrera primero'
                    : 'No hay categorías disponibles',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoriasDisponibles.length,
              itemBuilder: (context, index) {
                final categoria = categoriasDisponibles[index];
                final isSelected = categoriasSeleccionadas.contains(categoria);

                return CheckboxListTile(
                  title: Text(
                    categoria,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  value: isSelected,
                  activeColor: const Color(0xFF1A5490),
                  onChanged: (bool? value) {
                    onToggle(categoria, value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: false,
                  minVerticalPadding: 8,
                );
              },
            ),
        ],
      ),
    );
  }
}