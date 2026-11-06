import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/terminal_model.dart';
import 'package:flutter_hbb/models/terminal_mouse_handler.dart';
import 'package:flutter_hbb/models/terminal_copy_shortcut.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/powercloud/ui/tema_terminal.dart';
import 'package:flutter_hbb/powercloud/textos.dart';
import 'terminal_connection_manager.dart';

class TerminalPage extends StatefulWidget {
  TerminalPage({
    Key? key,
    required this.id,
    required this.password,
    required this.tabController,
    required this.isSharedPassword,
    required this.terminalId,
    required this.tabKey,
    this.forceRelay,
    this.connToken,
    this.onClipboardWriteBlocked,
    this.onClipboardWriteSucceeded,
  }) : super(key: key);
  final String id;
  final String? password;
  final DesktopTabController tabController;
  final bool? forceRelay;
  final bool? isSharedPassword;
  final String? connToken;
  final ValueChanged<String>? onClipboardWriteBlocked;
  final ValueChanged<String>? onClipboardWriteSucceeded;
  final int terminalId;

  /// Tab key for focus management, passed from parent to avoid duplicate construction
  final String tabKey;
  final SimpleWrapper<State<TerminalPage>?> _lastState = SimpleWrapper(null);

  FFI get ffi => (_lastState.value! as _TerminalPageState)._ffi;

  @override
  State<TerminalPage> createState() {
    final state = _TerminalPageState();
    _lastState.value = state;
    return state;
  }
}

class _TerminalPageState extends State<TerminalPage>
    with AutomaticKeepAliveClientMixin {
  static const EdgeInsets _defaultTerminalPadding =
      EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0);

  late FFI _ffi;
  late TerminalModel _terminalModel;
  double? _cellHeight;
  final FocusNode _terminalFocusNode = FocusNode(canRequestFocus: false);
  StreamSubscription<DesktopTabState>? _tabStateSubscription;
  double _letra = double.tryParse(
          bind.mainGetLocalOption(key: 'pc-terminal-letra')) ??
      kPcTerminalLetraPorDefecto;

  void _cambiarLetra(double delta, {bool reiniciar = false}) {
    setState(() {
      _letra = reiniciar
          ? kPcTerminalLetraPorDefecto
          : (_letra + delta).clamp(kPcTerminalLetraMin, kPcTerminalLetraMax);
    });
    bind.mainSetLocalOption(key: 'pc-terminal-letra', value: '$_letra');
  }

  Future<void> _copiar() async {
    final seleccion = _terminalModel.terminalController.selection;
    if (seleccion == null) return;
    final texto = _terminalModel.terminal.buffer.getText(seleccion);
    _terminalModel.terminalController.clearSelection();
    await Clipboard.setData(ClipboardData(text: texto));
    showToast(translate('Copied'));
  }

  Future<void> _pegar() async {
    final data = await Clipboard.getData('text/plain');
    final texto = data?.text;
    if (texto != null && texto.isNotEmpty) _terminalModel.terminal.paste(texto);
    _terminalFocusNode.requestFocus();
  }

  /// Ctrl+L limpia la pantalla en PowerShell (PSReadLine) y en bash.
  void _limpiar() {
    _terminalModel.terminal.textInput('\x0c');
    _terminalFocusNode.requestFocus();
  }

  /// Ctrl + / Ctrl - / Ctrl 0 cambian el tamano de letra; lo demas sigue igual.
  KeyEventResult _teclas(FocusNode nodo, KeyEvent evento) {
    if (evento is KeyDownEvent && HardwareKeyboard.instance.isControlPressed) {
      final k = evento.logicalKey;
      if (k == LogicalKeyboardKey.equal || k == LogicalKeyboardKey.add || k == LogicalKeyboardKey.numpadAdd) {
        _cambiarLetra(1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
        _cambiarLetra(-1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
        _cambiarLetra(0, reiniciar: true);
        return KeyEventResult.handled;
      }
    }
    return terminalCopyHandler(
        _terminalModel.terminal, _terminalModel.terminalController)(nodo, evento);
  }

  Widget _barra(BuildContext context) {
    Widget boton(IconData icono, String texto, VoidCallback accion) => Tooltip(
          message: texto,
          child: TextButton.icon(
            onPressed: accion,
            icon: Icon(icono, size: 16),
            label: Text(texto, style: const TextStyle(fontSize: 12.5)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC9D3DD),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111923),
        border: Border(bottom: BorderSide(color: Color(0xFF243040))),
      ),
      child: Row(children: [
        boton(Icons.copy_rounded, pcT('Copy'), _copiar),
        boton(Icons.content_paste_rounded, pcT('Paste'), _pegar),
        boton(Icons.cleaning_services_outlined, pcT('Clear screen'), _limpiar),
        const Spacer(),
        IconButton(
          tooltip: pcT('Smaller text (Ctrl -)'),
          icon: const Icon(Icons.text_decrease_rounded, size: 18),
          color: const Color(0xFFC9D3DD),
          onPressed: () => _cambiarLetra(-1),
        ),
        SizedBox(
          width: 34,
          child: Text('${_letra.round()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9AA8B6), fontSize: 12.5)),
        ),
        IconButton(
          tooltip: pcT('Larger text (Ctrl +)'),
          icon: const Icon(Icons.text_increase_rounded, size: 18),
          color: const Color(0xFFC9D3DD),
          onPressed: () => _cambiarLetra(1),
        ),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();

    // Listen for tab selection changes to request focus
    _tabStateSubscription = widget.tabController.state.listen(_onTabStateChanged);

    // Use shared FFI instance from connection manager
    _ffi = TerminalConnectionManager.getConnection(
      peerId: widget.id,
      password: widget.password,
      isSharedPassword: widget.isSharedPassword,
      forceRelay: widget.forceRelay,
      connToken: widget.connToken,
    );

    // Create terminal model with specific terminal ID
    _terminalModel = TerminalModel(_ffi, widget.terminalId);
    _terminalModel.onClipboardWriteBlocked = widget.onClipboardWriteBlocked;
    _terminalModel.onClipboardWriteSucceeded = widget.onClipboardWriteSucceeded;
    debugPrint(
        '[TerminalPage] Terminal model created for terminal ${widget.terminalId}');

    _terminalModel.onResizeExternal = (w, h, pw, ph) {
      _cellHeight = ph * 1.0;

      // Enable focus once terminal has valid dimensions (first valid resize)
      if (!_terminalFocusNode.canRequestFocus && w > 0 && h > 0) {
        _terminalFocusNode.canRequestFocus = true;
        // Auto-focus if this tab is currently selected
        _requestFocusIfSelected();
      }

      // Schedule the setState for the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    };

    // Register this terminal model with FFI for event routing
    _ffi.registerTerminalModel(widget.terminalId, _terminalModel);

    // Auto-close tab when shell exits
    _terminalModel.onClosed = () {
      if (mounted) {
        widget.tabController.closeBy(widget.tabKey);
      }
    };

    // Initialize terminal connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.tabController.onSelected?.call(widget.id);

      // Check if this is a new connection or additional terminal
      // Note: When a connection exists, the ref count will be > 1 after this terminal is added
      final isExistingConnection =
          TerminalConnectionManager.hasConnection(widget.id) &&
              TerminalConnectionManager.getTerminalCount(widget.id) > 1;

      if (!isExistingConnection) {
        // First terminal - show loading dialog, wait for onReady
        _ffi.dialogManager
            .showLoading(translate('Connecting...'), onCancel: closeConnection);
      } else {
        // Additional terminal - connection already established
        // Open the terminal directly
        _terminalModel.openTerminal();
      }
    });
  }

  @override
  void dispose() {
    // Cancel tab state subscription to prevent memory leak
    _tabStateSubscription?.cancel();
    // Unregister terminal model from FFI
    _ffi.unregisterTerminalModel(widget.terminalId);
    _terminalModel.dispose();
    _terminalFocusNode.dispose();
    // Release connection reference instead of closing directly
    TerminalConnectionManager.releaseConnection(widget.id);
    super.dispose();
  }

  void _onTabStateChanged(DesktopTabState state) {
    // Check if this tab is now selected and request focus
    if (state.selected >= 0 && state.selected < state.tabs.length) {
      final selectedTab = state.tabs[state.selected];
      if (selectedTab.key == widget.tabKey && mounted) {
        _requestFocusIfSelected();
      }
    }
  }

  void _requestFocusIfSelected() {
    if (!mounted || !_terminalFocusNode.canRequestFocus) return;
    // Use post-frame callback to ensure widget is fully laid out in focus tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Re-check conditions after frame: mounted, focusable, still selected, not already focused
      if (!mounted || !_terminalFocusNode.canRequestFocus || _terminalFocusNode.hasFocus) return;
      final state = widget.tabController.state.value;
      if (state.selected >= 0 && state.selected < state.tabs.length) {
        if (state.tabs[state.selected].key == widget.tabKey) {
          _terminalFocusNode.requestFocus();
        }
      }
    });
  }

  // This method ensures that the number of visible rows is an integer by computing the
  // extra space left after dividing the available height by the height of a single
  // terminal row (`_cellHeight`) and distributing it evenly as top and bottom padding.
  EdgeInsets _calculatePadding(double heightPx) {
    final cellHeight = _cellHeight;
    if (!heightPx.isFinite ||
        heightPx <= 0 ||
        cellHeight == null ||
        !cellHeight.isFinite ||
        cellHeight <= 0) {
      return _defaultTerminalPadding;
    }
    final rows = (heightPx / cellHeight).floor();
    if (rows <= 0) {
      return _defaultTerminalPadding;
    }
    final extraSpace = heightPx - rows * cellHeight;
    if (!extraSpace.isFinite || extraSpace < 0) {
      return _defaultTerminalPadding;
    }
    final topBottom = extraSpace / 2.0;
    return EdgeInsets.symmetric(
      horizontal: _defaultTerminalPadding.horizontal / 2,
      vertical: topBottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: pcTemaTerminal.background,
      body: Column(children: [
        _barra(context),
        Expanded(child: LayoutBuilder(
        builder: (context, constraints) {
          final heightPx = constraints.maxHeight;
          return TerminalMouseInteraction(
            _terminalModel.terminal,
            controller: _terminalModel.terminalController,
            focusNode: _terminalFocusNode,
            // Note: autofocus is not used here because focus is managed manually
            // via _onTabStateChanged() to handle tab switching properly.
            textStyle: pcEstiloTerminal(_letra),
            theme: pcTemaTerminal,
            onKeyEvent: _teclas,
            backgroundOpacity: 1,
            padding: _calculatePadding(heightPx),
            onSecondaryTapDown: (details, offset) async {
              final selection = _terminalModel.terminalController.selection;
              if (selection != null) {
                final text = _terminalModel.terminal.buffer.getText(selection);
                _terminalModel.terminalController.clearSelection();
                await Clipboard.setData(ClipboardData(text: text));
              } else {
                final data = await Clipboard.getData('text/plain');
                final text = data?.text;
                if (text != null) {
                  _terminalModel.terminal.paste(text);
                }
              }
            },
          );
        },
      )),
      ]),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
