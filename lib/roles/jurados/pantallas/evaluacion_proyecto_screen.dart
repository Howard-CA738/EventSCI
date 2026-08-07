import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/shared/logica/gestion_criterios.dart';
import '/roles/jurados/logica/evaluacion_service.dart';

class EvaluacionProyectoScreen extends StatefulWidget {
  final Map<String, dynamic> proyecto;
  final String juradoId;
  final String juradoNombre;

  const EvaluacionProyectoScreen({
    super.key,
    required this.proyecto,
    required this.juradoId,
    required this.juradoNombre,
  });

  @override
  State<EvaluacionProyectoScreen> createState() =>
      _EvaluacionProyectoScreenState();
}

class _EvaluacionProyectoScreenState
    extends State<EvaluacionProyectoScreen> {
  final _service = EvaluacionService();
  final Map<String, double?> _notasSeleccionadas = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isGuardando = false;
  bool _isCargando = true;
  bool _yaEvaluado = false;
  bool _estaBloqueado = false;
  bool _guardadoEnProceso = false;
  late Rubrica _rubrica;

  @override
  void initState() {
    super.initState();
    _rubrica = widget.proyecto['rubrica'] as Rubrica;
    _cargarNotas();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarNotas() async {
    setState(() => _isCargando = true);
    try {
      final result = await _service.cargarNotas(
        eventId: widget.proyecto['eventId'],
        proyectoId: widget.proyecto['proyectoId'],
        juradoId: widget.juradoId,
      );
      if (result != null && mounted) {
        _yaEvaluado = result.evaluada;
        _estaBloqueado = result.bloqueada;
        for (final e in result.notas.entries) {
          _notasSeleccionadas[e.key] = e.value;
        }
      }
    } catch (e) {
      debugPrint('Error al cargar notas: $e');
    } finally {
      if (mounted) setState(() => _isCargando = false);
    }
  }

  Future<void> _guardarEvaluacion() async {
    if (_guardadoEnProceso || _isGuardando) return;

    final yaInvalida = await _service.estaEvaluadaOBloqueada(
      eventId: widget.proyecto['eventId'],
      proyectoId: widget.proyecto['proyectoId'],
      juradoId: widget.juradoId,
    );

    if (yaInvalida) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Esta evaluación ya fue bloqueada o guardada. No se puede modificar.'),
          backgroundColor: Colors.orange,
        ));
        setState(() {
          _estaBloqueado = true;
          _yaEvaluado = true;
        });
      }
      return;
    }

    if (_rubrica.totalCriterios == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Esta rúbrica no tiene criterios configurados'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    for (final seccion in _rubrica.secciones) {
      for (final criterio in seccion.criterios) {
        if (_notasSeleccionadas[criterio.id] == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Califica todos los criterios en "${seccion.nombre}"'),
            backgroundColor: Colors.orange,
          ));
          return;
        }
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar Evaluación'),
        content: const Text(
            'Una vez guardada no podrás modificar las notas. ¿Confirmas?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F)),
            child: const Text('Guardar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    _guardadoEnProceso = true;
    setState(() => _isGuardando = true);

    try {
      await _service.guardarNotas(
        eventId: widget.proyecto['eventId'],
        proyectoId: widget.proyecto['proyectoId'],
        juradoId: widget.juradoId,
        notasSeleccionadas: _notasSeleccionadas,
        rubrica: _rubrica,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Evaluación guardada exitosamente'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGuardando = false;
          _guardadoEnProceso = false;
        });
      }
    }
  }

  int get _totalCriterios => _rubrica.totalCriterios;

  int get _criteriosEvaluados =>
      _notasSeleccionadas.values.where((v) => v != null).length;

  double get _notaActual =>
      _notasSeleccionadas.values.fold(0.0, (s, v) => s + (v ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final soloLectura = _estaBloqueado || _yaEvaluado;
    final progresoEval =
        _totalCriterios > 0 ? _criteriosEvaluados / _totalCriterios : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
                children: [
                  Semantics(
                    label: 'Regresar',
                    button: true,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluar ${widget.proyecto['codigo']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          _rubrica.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                  if (!soloLectura && !_isGuardando && !_isCargando)
                    TextButton.icon(
                      onPressed: _guardarEvaluacion,
                      icon: const Icon(Icons.save,
                          color: Colors.white, size: 18),
                      label: const Text('Guardar',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            if (!_isCargando)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progresoEval,
                          minHeight: 6,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progresoEval == 1.0
                                ? Colors.greenAccent
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '$_criteriosEvaluados/$_totalCriterios · ${_notaActual.toStringAsFixed(2)} / ${_rubrica.puntajeMaximo.toStringAsFixed(2)} pts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2F7),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: _isCargando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          if (soloLectura) _buildEstadoAlert(),
                          _buildInfoProyecto(),
                          const SizedBox(height: 16),
                          ..._rubrica.secciones
                              .map((s) => _buildSeccion(s, soloLectura)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          (_isCargando || _isGuardando || soloLectura || _guardadoEnProceso)
              ? null
              : FloatingActionButton.extended(
                  onPressed: _guardarEvaluacion,
                  backgroundColor: const Color(0xFF1E3A5F),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Guardar Evaluación',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
    );
  }

  Widget _buildEstadoAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _estaBloqueado
            ? Colors.red.withValues(alpha: 0.08)
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _estaBloqueado
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_estaBloqueado ? Icons.lock : Icons.check_circle,
              color: _estaBloqueado ? Colors.red : Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _estaBloqueado
                  ? 'Bloqueada por el administrador.'
                  : 'Evaluación completada. Modo solo lectura.',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _estaBloqueado ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoProyecto() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.proyecto['titulo'],
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F)),
          ),
          if ((widget.proyecto['integrantes'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            _eRow(Icons.people_outline, widget.proyecto['integrantes']),
          ],
          if ((widget.proyecto['sala'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            _eRow(Icons.room_outlined, widget.proyecto['sala']),
          ],
          const SizedBox(height: 4),
          _eRow(Icons.event_outlined, widget.proyecto['eventoNombre']),
        ],
      ),
    );
  }

  Widget _eRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ),
      ],
    );
  }

  Widget _buildSeccion(SeccionRubrica seccion, bool soloLectura) {
    int criteriosEv = 0;
    double puntajeSeccion = 0;
    for (final c in seccion.criterios) {
      if (_notasSeleccionadas[c.id] != null) {
        criteriosEv++;
        puntajeSeccion += _notasSeleccionadas[c.id]!;
      }
    }
    final seccionCompleta = criteriosEv == seccion.criterios.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: seccionCompleta
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !soloLectura || !seccionCompleta,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: seccionCompleta
                  ? Colors.green.withValues(alpha: 0.12)
                  : const Color(0xFF1E3A5F).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              seccionCompleta ? Icons.check_circle : Icons.folder_open,
              color:
                  seccionCompleta ? Colors.green : const Color(0xFF1E3A5F),
              size: 20,
            ),
          ),
          title: Text(seccion.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F))),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$criteriosEv/${seccion.criterios.length} evaluados · ${puntajeSeccion.toStringAsFixed(2)}/${seccion.pesoTotal.toStringAsFixed(2)} pts',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
          children: seccion.criterios
              .map((c) => _buildCriterio(c, soloLectura))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCriterio(Criterio criterio, bool soloLectura) {
    final nota = _notasSeleccionadas[criterio.id];
    final calificado = nota != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: calificado
            ? Colors.green.withValues(alpha: 0.04)
            : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: calificado
              ? Colors.green.withValues(alpha: 0.25)
              : Colors.grey.withValues(alpha: 0.2),
          width: calificado ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  criterio.descripcion,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Máx ${criterio.peso.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (calificado)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${nota.toStringAsFixed(2)} pts seleccionados',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ),
                ],
              ),
            )
          else if (!soloLectura)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Ingresa una calificación (0 – ${criterio.peso.toStringAsFixed(2)} pts)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),
          _buildNotaSelector(criterio, nota, soloLectura),
        ],
      ),
    );
  }

  Widget _buildNotaSelector(
      Criterio criterio, double? notaSeleccionada, bool soloLectura) {
    final pesoMaximo = criterio.peso;

    final controller = _controllers.putIfAbsent(
      criterio.id,
      () => TextEditingController(),
    );

    if (notaSeleccionada != null) {
      final valorActualEnCampo = double.tryParse(controller.text);
      final difiere = valorActualEnCampo == null ||
          (notaSeleccionada - valorActualEnCampo).abs() >= 0.001;
      if (difiere) {
        final texto = notaSeleccionada.toStringAsFixed(2);
        controller.value = TextEditingValue(
          text: texto,
          selection:
              TextSelection.fromPosition(TextPosition(offset: texto.length)),
        );
      }
    } else if (controller.text.isNotEmpty && soloLectura) {
      controller.clear();
    }

    final botones = [0.0, 0.25, 0.50, 0.75, 1.0].map((pct) {
      final valor = double.parse((pesoMaximo * pct).toStringAsFixed(2));
      final seleccionado = notaSeleccionada != null &&
          (notaSeleccionada - valor).abs() < 0.001;
      return _BotonNota(
        label: valor.toStringAsFixed(2),
        seleccionado: seleccionado,
        soloLectura: soloLectura,
        onTap: () {
          setState(() => _notasSeleccionadas[criterio.id] = valor);
        },
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          enabled: !soloLectura,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: 'Ej: ${(pesoMaximo * 0.75).toStringAsFixed(2)}',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            suffixText: '/ ${pesoMaximo.toStringAsFixed(2)} pts',
            suffixStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A5F)),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            filled: true,
            fillColor: soloLectura ? Colors.grey[100] : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (val) {
            final parsed = double.tryParse(val);
            if (parsed == null) {
              setState(() => _notasSeleccionadas[criterio.id] = null);
              return;
            }
            final clamped = parsed.clamp(0.0, pesoMaximo);
            setState(() => _notasSeleccionadas[criterio.id] = clamped);
            if (parsed > pesoMaximo) {
              final corregido = pesoMaximo.toStringAsFixed(2);
              controller.value = TextEditingValue(
                text: corregido,
                selection: TextSelection.fromPosition(
                    TextPosition(offset: corregido.length)),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        if (!soloLectura)
          Row(
            children: [
              const Text('Rápido:',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: botones,
                ),
              ),
            ],
          ),
        if (notaSeleccionada != null && pesoMaximo > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (notaSeleccionada / pesoMaximo).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                notaSeleccionada / pesoMaximo >= 0.8
                    ? Colors.green
                    : notaSeleccionada / pesoMaximo >= 0.5
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(notaSeleccionada / pesoMaximo * 100).toStringAsFixed(1)}% del máximo',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }
}

class _BotonNota extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final bool soloLectura;
  final VoidCallback onTap;

  const _BotonNota({
    required this.label,
    required this.seleccionado,
    required this.soloLectura,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nota rápida $label',
      child: GestureDetector(
        onTap: soloLectura ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: seleccionado
                ? const Color(0xFF1E3A5F)
                : const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: seleccionado
                  ? const Color(0xFF1E3A5F)
                  : const Color(0xFF1E3A5F).withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color:
                    seleccionado ? Colors.white : const Color(0xFF1E3A5F),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
