import 'package:flutter/material.dart';

// Todos los colores de la app en un solo lugar.
// Si quieres cambiar el diseño, cambia los valores aquí.
class AppColors {
  static const primary = Color(0xFF4B3BEF); // azul/morado principal
  static const primarySoft = Color(0xFFEAE9FD); // fondo suave del principal
  static const background = Color(0xFFF5F6FB); // fondo de pantallas
  static const field = Color(0xFFF0F1F8); // fondo de los campos de texto
  static const text = Color(0xFF1B1B2F); // texto principal
  static const textLight = Color(0xFF8A8CA5); // texto secundario
  static const danger = Color(0xFFE5533D); // rojo (cerrar sesión)

  // Colores por materia (se usan en chips y en el calendario).
  static const calculo = Color(0xFF4B3BEF);
  static const programacion = Color(0xFF2E9E4F);
  static const fisica = Color(0xFF1E88E5);
  static const ingles = Color(0xFFE5533D);
  static const basesDatos = Color(0xFFD9366F);
  static const matematicas = Color(0xFFE0A100);

  static Color subject(String name) {
    switch (name) {
      case 'Cálculo':
        return calculo;
      case 'Programación':
        return programacion;
      case 'Física':
        return fisica;
      case 'Inglés':
        return ingles;
      case 'Bases de datos':
        return basesDatos;
      case 'Matemáticas':
        return matematicas;
      default:
        return primary;
    }
  }
}
