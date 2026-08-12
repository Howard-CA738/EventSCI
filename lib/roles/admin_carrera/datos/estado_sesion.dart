enum EstadoSesion { sinSesion, bloqueado, reseteado }

EstadoSesion calcularEstadoSesion(Map<String, dynamic> estudiante) {
  final bloqueadoPermanente = estudiante['bloqueadoPermanente'] == true;
  final active = estudiante['sessionActive'] == true;
  final primeraVez = estudiante['primeraVez'] != false;

  if (bloqueadoPermanente) return EstadoSesion.bloqueado;
  if (active) return EstadoSesion.bloqueado;
  if (primeraVez) return EstadoSesion.sinSesion;
  return EstadoSesion.reseteado;
}
