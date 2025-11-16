import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AsistenciasExcel {
  /// Genera y descarga un reporte de asistencias en formato Excel
  static Future<void> generarReporteExcel({
    required List<Map<String, dynamic>> estudiantes,
    required Map<String, List<Map<String, dynamic>>> asistenciasPorEstudiante,
    required String facultad,
    required String carrera,
    String? cicloFiltro,
    String? grupoFiltro,
    String? terminoBusqueda,
  }) async {
    // Crear el libro de Excel
    final excel = Excel.createExcel();

    // Crear la única hoja con toda la información
    _crearHojaCompleta(
      excel,
      estudiantes,
      asistenciasPorEstudiante,
      facultad,
      carrera,
      cicloFiltro,
      grupoFiltro,
      terminoBusqueda,
    );

    // Eliminar la hoja por defecto si existe
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Guardar el archivo
    await _guardarArchivo(excel, facultad, carrera, cicloFiltro, grupoFiltro);
  }

  /// Crea una única hoja con todos los estudiantes y sus asistencias
  static void _crearHojaCompleta(
    Excel excel,
    List<Map<String, dynamic>> estudiantes,
    Map<String, List<Map<String, dynamic>>> asistenciasPorEstudiante,
    String facultad,
    String carrera,
    String? cicloFiltro,
    String? grupoFiltro,
    String? terminoBusqueda,
  ) {
    final sheet = excel['Reporte de Asistencias'];

    // Título principal
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('L1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
      'REPORTE DE ASISTENCIAS - $facultad - $carrera',
    );
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1976D2'),
      fontColorHex: ExcelColor.white,
    );

    // Información general y filtros aplicados
    var currentInfoRow = 2;
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentInfoRow),
        )
        .value = TextCellValue(
      'Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentInfoRow),
        )
        .cellStyle = CellStyle(
      fontSize: 11,
      italic: true,
    );
    currentInfoRow++;

    // Mostrar filtros aplicados
    if (cicloFiltro != null ||
        grupoFiltro != null ||
        (terminoBusqueda != null && terminoBusqueda.isNotEmpty)) {
      var filtrosTexto = 'FILTROS APLICADOS: ';
      List<String> filtros = [];

      if (cicloFiltro != null) filtros.add('Ciclo $cicloFiltro');
      if (grupoFiltro != null) filtros.add('Grupo $grupoFiltro');
      if (terminoBusqueda != null && terminoBusqueda.isNotEmpty)
        filtros.add('Búsqueda: "$terminoBusqueda"');

      filtrosTexto += filtros.join(' | ');

      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentInfoRow,
            ),
          )
          .value = TextCellValue(
        filtrosTexto,
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentInfoRow,
            ),
          )
          .cellStyle = CellStyle(
        fontSize: 11,
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#D32F2F'),
      );
      currentInfoRow++;
    }

    // Encabezados de la tabla
    final headers = [
      'N°',
      'Estudiante',
      'DNI',
      'Código Univ.',
      'Ciclo',
      'Grupo',
      'Evento',
      'Categoría',
      'Código Proyecto',
      'Título de Investigación',
      'Fecha Asistencia',
      'Total Asistencias',
    ];

    var headerRow = currentInfoRow + 1;
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // Datos
    var currentRow = headerRow + 1;
    var contador = 1;

    for (var estudiante in estudiantes) {
      final asistencias = asistenciasPorEstudiante[estudiante['id']] ?? [];
      final nombreEstudiante = estudiante['name'] ?? 'Sin nombre';
      final dni = estudiante['dni']?.toString() ?? '-';
      final codigoUniv = estudiante['codigoUniversitario']?.toString() ?? '-';
      final ciclo = estudiante['ciclo']?.toString() ?? '-';
      final grupo = estudiante['grupo']?.toString() ?? '-';

      if (asistencias.isEmpty) {
        // Si no tiene asistencias, mostrar una fila indicándolo
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            )
            .value = IntCellValue(
          contador,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
            )
            .value = TextCellValue(
          nombreEstudiante,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
            )
            .value = TextCellValue(
          dni,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
            )
            .value = TextCellValue(
          codigoUniv,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
            )
            .value = TextCellValue(
          ciclo,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
            )
            .value = TextCellValue(
          grupo,
        );

        var sinAsistenciaCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow),
        );
        sinAsistenciaCell.value = TextCellValue('Sin asistencias registradas');
        sinAsistenciaCell.cellStyle = CellStyle(
          italic: true,
          fontColorHex: ExcelColor.fromHexString('#757575'),
        );

        // Combinar celdas para el mensaje (hasta la columna 11)
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow),
          CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: currentRow),
        );

        // Fondo gris claro para toda la fila
        for (var col = 0; col < headers.length; col++) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: col,
                  rowIndex: currentRow,
                ),
              )
              .cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
          );
        }

        currentRow++;
        contador++;
      } else {
        // Si tiene asistencias, mostrar cada una en una fila
        var primeraFila = true;

        for (var asistencia in asistencias) {
          final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
          final categoria =
              asistencia['categoria'] ??
              asistencia['tipoInvestigacion'] ??
              'Sin categoría';
          final codigoProyecto =
              asistencia['codigoProyecto']?.toString() ?? '-';
          final tituloProyecto =
              asistencia['tituloProyecto']?.toString() ?? '-';
          final eventoNombre = asistencia['eventName'] ?? 'Sin nombre';

          // Columna N° (solo en la primera fila del estudiante)
          if (primeraFila) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: currentRow,
                  ),
                )
                .value = IntCellValue(
              contador,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          } else {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          }

          // Nombre del estudiante (solo en la primera fila)
          if (primeraFila) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 1,
                    rowIndex: currentRow,
                  ),
                )
                .value = TextCellValue(
              nombreEstudiante,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 1,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              bold: true,
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          } else {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 1,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          }

          // DNI (solo en la primera fila)
          if (primeraFila) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 2,
                    rowIndex: currentRow,
                  ),
                )
                .value = TextCellValue(
              dni,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 2,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          } else {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 2,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          }

          // Código Universitario (solo en la primera fila)
          if (primeraFila) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 3,
                    rowIndex: currentRow,
                  ),
                )
                .value = TextCellValue(
              codigoUniv,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 3,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          } else {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 3,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          }

          // Ciclo (solo en la primera fila)
          if (primeraFila) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 4,
                    rowIndex: currentRow,
                  ),
                )
                .value = TextCellValue(
              ciclo,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 4,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
              horizontalAlign: HorizontalAlign.Center,
            );
          } else {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 4,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          }

          // Grupo (solo en la primera fila)
          if (primeraFila) {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 5,
                    rowIndex: currentRow,
                  ),
                )
                .value = TextCellValue(
              grupo,
            );
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 5,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
              horizontalAlign: HorizontalAlign.Center,
            );
          } else {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 5,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          }

          // Evento
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 6,
                  rowIndex: currentRow,
                ),
              )
              .value = TextCellValue(
            eventoNombre,
          );

          // Categoría
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 7,
                  rowIndex: currentRow,
                ),
              )
              .value = TextCellValue(
            categoria,
          );

          // Código Proyecto
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 8,
                  rowIndex: currentRow,
                ),
              )
              .value = TextCellValue(
            codigoProyecto,
          );

          // Título de Investigación
          var tituloCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: currentRow),
          );
          tituloCell.value = TextCellValue(tituloProyecto);
          tituloCell.cellStyle = CellStyle(textWrapping: TextWrapping.WrapText);

          // Fecha
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 10,
                  rowIndex: currentRow,
                ),
              )
              .value = TextCellValue(
            timestamp != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
                : '-',
          );

          // Total Asistencias (solo en la primera fila del estudiante)
          if (primeraFila) {
            var totalCell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: currentRow),
            );
            totalCell.value = IntCellValue(asistencias.length);
            totalCell.cellStyle = CellStyle(
              bold: true,
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
              horizontalAlign: HorizontalAlign.Center,
            );
          } else {
            sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 11,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
            );
          }

          currentRow++;
          primeraFila = false;
        }

        contador++;
      }
    }

    // Agregar fila de resumen al final
    currentRow++;

    // Calcular totales
    var totalAsistencias = 0;
    var estudiantesConAsistencias = 0;
    for (var estudiante in estudiantes) {
      final asistencias = asistenciasPorEstudiante[estudiante['id']] ?? [];
      totalAsistencias += asistencias.length;
      if (asistencias.isNotEmpty) estudiantesConAsistencias++;
    }

    // Fusionar celdas para "RESUMEN:"
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
    );

    var resumenCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
    );
    resumenCell.value = TextCellValue('RESUMEN:');
    resumenCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFC107'),
      horizontalAlign: HorizontalAlign.Center,
      fontSize: 12,
    );

    // Total Estudiantes
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
    );
    var totalEstCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
    );
    totalEstCell.value = TextCellValue(
      'Total Estudiantes: ${estudiantes.length}',
    );
    totalEstCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
    );

    // Con asistencias
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow),
    );
    var conAsistCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
    );
    conAsistCell.value = TextCellValue(
      'Con asistencias: $estudiantesConAsistencias',
    );
    conAsistCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
    );

    // Total Asistencias
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: currentRow),
    );
    var totalAsistCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow),
    );
    totalAsistCell.value = TextCellValue(
      'Total Asistencias: $totalAsistencias',
    );
    totalAsistCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Ajustar ancho de columnas
    sheet.setColumnWidth(0, 8); // N°
    sheet.setColumnWidth(1, 30); // Estudiante
    sheet.setColumnWidth(2, 12); // DNI
    sheet.setColumnWidth(3, 15); // Código Univ.
    sheet.setColumnWidth(4, 8); // Ciclo
    sheet.setColumnWidth(5, 8); // Grupo
    sheet.setColumnWidth(6, 40); // Evento
    sheet.setColumnWidth(7, 20); // Categoría
    sheet.setColumnWidth(8, 18); // Código Proyecto
    sheet.setColumnWidth(9, 50); // Título de Investigación
    sheet.setColumnWidth(10, 18); // Fecha
    sheet.setColumnWidth(11, 18); // Total Asistencias
  }

  /// Guarda el archivo Excel en el dispositivo
  static Future<void> _guardarArchivo(
    Excel excel,
    String facultad,
    String carrera,
    String? cicloFiltro,
    String? grupoFiltro,
  ) async {
    try {
      // Solicitar permisos según la versión de Android
      if (Platform.isAndroid) {
        // Para Android 13+ (API 33+) - Solo necesitamos manageExternalStorage
        var storageStatus = await Permission.storage.status;

        if (!storageStatus.isGranted) {
          // Primero intentar con storage normal
          storageStatus = await Permission.storage.request();

          // Si no se concede, intentar con manageExternalStorage
          if (!storageStatus.isGranted) {
            var manageStatus = await Permission.manageExternalStorage.status;

            if (!manageStatus.isGranted) {
              manageStatus = await Permission.manageExternalStorage.request();

              if (!manageStatus.isGranted) {
                if (manageStatus.isPermanentlyDenied) {
                  await openAppSettings();
                }
                throw Exception(
                  'Se requieren permisos de almacenamiento para guardar el archivo Excel.',
                );
              }
            }
          }
        }
      }

      // Generar nombre de archivo
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final nombreCarrera = carrera.replaceAll(' ', '_');

      // Agregar filtros al nombre del archivo
      String sufijo = '';
      if (cicloFiltro != null || grupoFiltro != null) {
        if (cicloFiltro != null) sufijo += '_C$cicloFiltro';
        if (grupoFiltro != null) sufijo += '_G$grupoFiltro';
      }

      final fileName = 'Asistencias_${nombreCarrera}${sufijo}_$timestamp.xlsx';

      // Obtener directorio de Documentos o Descargas
      Directory? directory;
      if (Platform.isAndroid) {
        // Intentar con Downloads primero (más compatible)
        directory = Directory('/storage/emulated/0/Download');

        if (!await directory.exists()) {
          // Si no existe, intentar con Documents
          directory = Directory('/storage/emulated/0/Documents');

          if (!await directory.exists()) {
            try {
              await directory.create(recursive: true);
            } catch (e) {
              print('Error al crear directorio: $e');
              throw Exception(
                'No se pudo crear el directorio para guardar el archivo',
              );
            }
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('No se pudo acceder al directorio de descargas');
      }

      // Guardar archivo
      final filePath = '${directory.path}/$fileName';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        print('✅ Archivo guardado exitosamente en: $filePath');
        print('📁 Ubicación: ${directory.path}');
      } else {
        throw Exception('Error al generar el archivo Excel');
      }
    } catch (e) {
      print('❌ Error al guardar archivo: $e');
      rethrow;
    }
  }
}
