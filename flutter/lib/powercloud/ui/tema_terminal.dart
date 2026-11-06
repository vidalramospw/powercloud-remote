import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Apariencia de la terminal de PowerCloud: fondo azul marino de la marca, paleta ANSI legible y
/// cursor celeste; letra de consola de Windows con alternativas.

const kPcTerminalLetraMin = 9.0;
const kPcTerminalLetraMax = 28.0;
const kPcTerminalLetraPorDefecto = 14.0;

TerminalStyle pcEstiloTerminal(double tamano) => TerminalStyle(
      fontSize: tamano,
      height: 1.25,
      fontFamily: 'Cascadia Mono',
      fontFamilyFallback: const [
        'Consolas',
        'Menlo',
        'DejaVu Sans Mono',
        'Ubuntu Mono',
        'Courier New',
        'monospace',
        'Segoe UI Emoji',
        'Noto Color Emoji',
      ],
    );

const pcTemaTerminal = TerminalTheme(
  cursor: Color(0xFF38B6E8),
  selection: Color(0x5538B6E8),
  foreground: Color(0xFFE6ECF2),
  background: Color(0xFF0B1118),
  black: Color(0xFF1C2631),
  red: Color(0xFFFF6B6B),
  green: Color(0xFF2FBF71),
  yellow: Color(0xFFF0C674),
  blue: Color(0xFF38B6E8),
  magenta: Color(0xFFC792EA),
  cyan: Color(0xFF5FD4D4),
  white: Color(0xFFC9D3DD),
  brightBlack: Color(0xFF5B7286),
  brightRed: Color(0xFFFF8A8A),
  brightGreen: Color(0xFF5BE39A),
  brightYellow: Color(0xFFFFDC8A),
  brightBlue: Color(0xFF7ACDF2),
  brightMagenta: Color(0xFFDDB6F2),
  brightCyan: Color(0xFF8AE8E8),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF6B5320),
  searchHitBackgroundCurrent: Color(0xFF0E8AC8),
  searchHitForeground: Color(0xFFFFFFFF),
);
