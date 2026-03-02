import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'editar_jurados.dart';
import 'filiales_service.dart';
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

  // ✅ NUEVO: Valores con sistema de filiales
  String? _filialSeleccionada;
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;
  List<String> _categoriasSeleccionadas = [];

  // ✅ NUEVO: Listas dinámicas
  List<String> _filialesDisponibles = [];
  String _nombreFilialSeleccionada = '';
  List<String> _facultadesDisponibles = [];
  List<Map<String, dynamic>> _carrerasDisponibles = [];
  List<String> _categoriasDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarFiliales();
  }

  // ✅ NUEVO: Cargar filiales
  Future<void> _cargarFiliales() async {
    try {
      final filiales = await _rubricasService.getFiliales();
      if (mounted) {
        setState(() {
          _filialesDisponibles = filiales;
        });
      }
    } catch (e) {
      print('Error al cargar filiales: $e');
    }
  }

  // ✅ NUEVO: Cuando cambia la filial
  Future<void> _onFilialChanged(String? filial) async {
    setState(() {
      _filialSeleccionada = filial;
      _facultadSeleccionada = null;
      _carreraSeleccionada = null;
      _categoriasSeleccionadas = [];
      _facultadesDisponibles = [];
      _carrerasDisponibles = [];
      _categoriasDisponibles = [];
    });

    if (filial != null) {
      _nombreFilialSeleccionada = await _rubricasService.getNombreFilial(
        filial,
      );
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
      _categoriasSeleccionadas = [];
      _carrerasDisponibles = [];
      _categoriasDisponibles = [];
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

  // ✅ ACTUALIZADO: Cargar categorías usando filialId
  Future<void> _onCarreraChanged(String? carreraNombre) async {
    setState(() {
      _carreraSeleccionada = carreraNombre;
      _categoriasSeleccionadas = [];
      _categoriasDisponibles = [];
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
      print('Error al cargar categorías: $e');
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
      // ✅ NUEVO: Crear jurado con filialId
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

      // Verificar si el usuario ya existe
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

      // Limpiar formulario
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
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Regresar',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Crear Jurados',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),

                        // Icono de jurado
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
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
                            child: Image.asset(
                              'assets/icons/jurado.png',
                              width: 70,
                              height: 70,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.gavel,
                                  size: 70,
                                  color: Color(0xFF1A5490),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Nombre completo
                        TextFormField(
                          controller: _nombreController,
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Nombre Completo',
                            hintText: 'Ej: Dr. Juan Pérez López',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: Color(0xFF1A5490),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
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
                        const SizedBox(height: 18),

                        // Usuario
                        TextFormField(
                          controller: _usuarioController,
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Usuario',
                            hintText: 'Ej: jperez',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.account_circle,
                              color: Color(0xFF1A5490),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          autocorrect: false,
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
                        const SizedBox(height: 18),

                        // Contraseña
                        TextFormField(
                          controller: _passwordController,
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            hintText: 'Mínimo 6 caracteres',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Color(0xFF1A5490),
                            ),
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
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          obscureText: _obscurePassword,
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
                        const SizedBox(height: 18),

                        // ✅ NUEVO: Filial
                        DropdownButtonFormField<String>(
                          value: _filialSeleccionada,
                          isExpanded: true,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey[600],
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Filial',
                            prefixIcon: const Icon(
                              Icons.location_city,
                              color: Color(0xFF1A5490),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                          items: _filialesDisponibles.map((filialId) {
                            return DropdownMenuItem(
                              value: filialId,
                              child: FutureBuilder<String>(
                                future: _rubricasService.getNombreFilial(
                                  filialId,
                                ),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data ?? filialId,
                                    style: const TextStyle(fontSize: 14.5),
                                  );
                                },
                              ),
                            );
                          }).toList(),
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
                        const SizedBox(height: 18),

                        // Facultad
                        DropdownButtonFormField<String>(
                          value: _facultadSeleccionada,
                          isExpanded: true,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey[600],
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Facultad',
                            prefixIcon: const Icon(
                              Icons.school,
                              color: Color(0xFF1A5490),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
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
                        const SizedBox(height: 18),

                        // Carrera
                        DropdownButtonFormField<String>(
                          value: _carreraSeleccionada,
                          isExpanded: true,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey[600],
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Carrera',
                            prefixIcon: const Icon(
                              Icons.book,
                              color: Color(0xFF1A5490),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
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
                        const SizedBox(height: 18),

                        // Selector de múltiples categorías
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.category,
                                      color: Color(0xFF1A5490),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Categorías / Proyectos',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_categoriasSeleccionadas.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A5490),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${_categoriasSeleccionadas.length}',
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
                              if (_categoriasDisponibles.isEmpty &&
                                  _carreraSeleccionada != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
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
                              else if (_categoriasDisponibles.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    'Seleccione una carrera primero',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _categoriasDisponibles.length,
                                    itemBuilder: (context, index) {
                                      final categoria =
                                          _categoriasDisponibles[index];
                                      final isSelected =
                                          _categoriasSeleccionadas.contains(
                                            categoria,
                                          );

                                      return CheckboxListTile(
                                        title: Text(
                                          categoria,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        value: isSelected,
                                        activeColor: const Color(0xFF1A5490),
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              _categoriasSeleccionadas.add(
                                                categoria,
                                              );
                                            } else {
                                              _categoriasSeleccionadas.remove(
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
                        ),

                        // Mostrar categorías seleccionadas
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
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: 30),

                        // Botón crear
                        ElevatedButton(
                          onPressed: _isLoading ? null : _crearJurado,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A5490),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                            shadowColor: const Color(
                              0xFF1A5490,
                            ).withOpacity(0.4),
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 20),

                        // Información adicional
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
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
          ],
        ),
      ),
    );
  }
}
