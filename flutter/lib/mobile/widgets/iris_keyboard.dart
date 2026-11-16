// Iris: on-screen keyboard with the Pyuron layout, for using the remote PC
// without the physical Pyuron. The layout and layers follow
// zmk-config-Pyuron/config/Pyuron.keymap (Default_Layer and the PC layers).
//
// Keys are sent the same way as a hardware keyboard on iOS
// (InputModel.newKeyboardMode with USB HID usages), so the PC's IME converts
// them and the "Swap control-command key" option applies like it does for
// Pyuron. That option swaps Ctrl and Win on the way out, so this keyboard
// pre-swaps them to make its Ctrl and Win keys arrive as labelled.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/input_model.dart';
import '../../models/platform_model.dart';

const double _ptPerMm = 132 / 25.4; // iPad Air 11: 132 pt per inch
const double _marginMm = 3; // screen edge and the gap between the halves
const double _gapMm = 1.2; // between keys
const double _landscapePitchMm = 16; // 15.5 on 2026-11-13, 16 on 2026-11-16
// Shorter than Pyuron's 200 ms so the layer shows sooner (2026-11-15).
const Duration _holdDelay = Duration(milliseconds: 150);

// Physical positions from Pyuron.json, in key units, same order as the keymap.
const List<List<int>> _pos = [
  [0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [8, 0], [9, 0], [10, 0], [11, 0], [12, 0],
  [0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [8, 1], [9, 1], [10, 1], [11, 1], [12, 1],
  [0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [7, 2], [8, 2], [9, 2], [10, 2], [11, 2], [12, 2],
  [0, 3], [1, 3], [4, 3], [5, 3], [7, 3], [8, 3], [11, 3], [12, 3],
];

// USB HID usages
const int _lctrl = 0xE0, _lshift = 0xE1, _lalt = 0xE2, _lgui = 0xE3;
const int _rctrl = 0xE4, _rgui = 0xE7;
const int _left = 0x50, _right = 0x4F, _up = 0x52, _down = 0x51;

class _A {
  final String label;
  final String? sub;
  final List<int> hids; // pressed together, released in reverse
  final int? layer; // hold-tap layer key (tap sends hids)
  final bool momentary; // layer while held, nothing on tap
  final MouseButtons? click;
  final List<_A>? macro; // tapped in order on press
  const _A(this.label,
      {this.sub,
      this.hids = const [],
      this.layer,
      this.momentary = false,
      this.click,
      this.macro});
}

_A _k(String l, int h) => _A(l, hids: [h]);
_A _s(String l, int h) => _A(l, hids: [_lshift, h]);
_A _c(String l, List<int> h) => _A(l, hids: h);
_A _m(String l, List<_A> seq) => _A(l, macro: seq);
const _A? _t = null; // transparent: falls through to the base layer

const int _sym = 2, _move = 3, _fn = 4, _setting = 5;

final List<_A?> _base = [
  _k('Q', 0x14), _k('L', 0x0F), _k('U', 0x18), _k('Z', 0x1D), _k('C', 0x06),
  _k('F', 0x09), _k('W', 0x1A), _k('R', 0x15), _k('Y', 0x1C), _k('P', 0x13),
  _k('E', 0x08), _k('I', 0x0C), _k('A', 0x04), _k('O', 0x12), _k('-', 0x2D),
  _k('K', 0x0E), _k('T', 0x17), _k('N', 0x11), _k('S', 0x16), _k('H', 0x0B),
  _k('Shift', _lshift), _k('X', 0x1B),
  const _A('RClick', click: MouseButtons.right),
  const _A('LClick', click: MouseButtons.left),
  _k('V', 0x19),
  const _A('Setting', layer: _setting, momentary: true),
  const _A('Del', hids: [0x4C], layer: _setting),
  _k('G', 0x0A), _k('D', 0x07), _k('M', 0x10),
  _k('J', 0x0D), _k('B', 0x05), _k('Win', _lgui), _k('Esc', 0x29),
  const _A('Space', sub: 'Move', hids: [0x2C], layer: _move),
  const _A('Tab', sub: 'Fn', hids: [0x2B], layer: _fn),
  _k('BS', 0x2A),
  const _A('Enter', sub: 'Sym', hids: [0x28], layer: _sym),
  _k('Alt', _lalt), _k('Ctrl', _lctrl),
];

// Symbols as Pyuron sends them for a Windows PC with a JIS layout (JP_* defines).
final List<_A?> _symL = [
  _s('#', 0x20), _k('@', 0x2F), _s('&', 0x23), _s('*', 0x34), _s('`', 0x2F),
  _m('()', [_s('(', 0x25), _s(')', 0x26), _k('', _left)]),
  _k(';', 0x33), _k(':', 0x34), _s('(', 0x25), _s(')', 0x26),
  _s('?', 0x38), _s('!', 0x1E), _k('IME ON', 0x6C), _k('IME OFF', 0x6D),
  _s('~', 0x2E),
  _m('{}', [_s('{', 0x30), _s('}', 0x31), _k('', _left)]),
  _k(',', 0x36), _k('.', 0x37), _s('{', 0x30), _s('}', 0x31),
  _t, _k('/', 0x38), _s('|', 0x89), _k('¥', 0x89), _k('^', 0x2E), _t, _t,
  _m('[]', [_k('[', 0x30), _k(']', 0x31), _k('', _left)]),
  _s("'", 0x24), _s('"', 0x1F),
  _k('[', 0x30), _k(']', 0x31), _t, _t, _s('_', 0x87), _t, _t, _t, _t, _t,
];

final List<_A?> _moveL = [
  _t, _c('Desk ←', [_lgui, _lctrl, _left]), _k('↑', _up),
  _c('Desk →', [_lgui, _lctrl, _right]), _c('Task', [_lgui, 0x2B]),
  _k('7', 0x5F), _k('8', 0x60), _k('9', 0x61), _k('-', 0x56), _k('/', 0x54),
  _k('Home', 0x4A), _k('←', _left), _k('↓', _down), _k('→', _right),
  _k('End', 0x4D), _k('4', 0x5C), _k('5', 0x5D), _k('6', 0x5E),
  _k('+', 0x57), _k('*', 0x55),
  _t, _t, _t, _t, _t, _t, _k('0', 0x62), _k('1', 0x59), _k('2', 0x5A),
  _k('3', 0x5B),
  _s('=', 0x2D), _k('.', 0x63), _t, _t, _t, _t, _t, _t, _s('%', 0x22), _t,
];

final List<_A?> _fnL = [
  _k('F11', 0x44), _k('F12', 0x45), _k('F13', 0x68), _k('F14', 0x69),
  _k('F15', 0x6A), _t, _t, _t, _t, _t,
  _k('F6', 0x3F), _k('F7', 0x40), _k('F8', 0x41), _k('F9', 0x42),
  _k('F10', 0x43), _t, _t, _t, _t, _t,
  _k('F1', 0x3A), _k('F2', 0x3B), _k('F3', 0x3C), _k('F4', 0x3D),
  _k('F5', 0x3E), _t, _t, _t, _t, _t, _t, _t,
  _t, _t, _t, _t, _t, _t, _t, _t,
];

// Only the screenshot key of Pyuron's Setting layer matters here; the rest of
// that layer switches Bluetooth profiles or resets the keyboard itself.
final List<_A?> _settingL = List<_A?>.generate(
    40, (i) => i == 24 ? _c('Shot', [_lgui, _lshift, 0x16]) : null);

final Map<int, List<_A?>> _layers = {
  _sym: _symL,
  _move: _moveL,
  _fn: _fnL,
  _setting: _settingL,
};

class _Colors {
  final Color pad, key, mod, shadow, press, fg, accent;
  const _Colors(this.pad, this.key, this.mod, this.shadow, this.press, this.fg,
      this.accent);
}

// iPad soft keyboard look (approximate values, chosen by eye on 2026-11-14).
const _light = _Colors(Color(0xFFD1D3D9), Color(0xFFFFFFFF), Color(0xFFADB1B8),
    Color(0xFF898A8D), Color(0xFFC7C9CE), Color(0xFF000000), Color(0xFF007AFF));
const _dark = _Colors(Color(0xFF2C2C2E), Color(0xFF6B6B6E), Color(0xFF464648),
    Color(0xFF000000), Color(0xFF8E8E93), Color(0xFFFFFFFF), Color(0xFF0A84FF));

enum IrisLayout { pyuron, qwerty }

/// Height of the keyboard panel for a screen of [size], including [bottomPad].
/// The remote canvas is shrunk by this much.
double irisKeyboardHeight(Size size, double bottomPad, IrisLayout layout,
    {bool numpad = false}) {
  final gap = _gapMm * _ptPerMm, m2 = 2 * _marginMm * _ptPerMm;
  if (layout == IrisLayout.qwerty) {
    return _qRows * _qPitch(size, numpad) - gap + m2 + bottomPad;
  }
  return 4 * _pitch(size) - gap + m2 + bottomPad;
}

// Portrait: the widest keys that leave the same margin at both screen edges
// and between the halves' thumb keys (2026-11-14). Landscape: fixed.
double _pitch(Size size) {
  if (size.width >= size.height) return _landscapePitchMm * _ptPerMm;
  final wmm = size.width / _ptPerMm;
  return (wmm - 3 * _marginMm + 2 * _gapMm) / 12 * _ptPerMm;
}

// Ctrl and Win are pre-swapped while "Swap control-command key" is on, because
// that option swaps them again on the way to the PC.
void _sendHid(InputModel input, int code, bool down) {
  var c = code;
  if (bind.sessionGetToggleOptionSync(
      sessionId: input.sessionId, arg: 'allow_swap_key')) {
    if (c == _lctrl) {
      c = _lgui;
    } else if (c == _lgui) {
      c = _lctrl;
    } else if (c == _rctrl) {
      c = _rgui;
    } else if (c == _rgui) {
      c = _rctrl;
    }
  }
  input.newKeyboardMode('', c, down, false);
}

String _caseLabel(String label, bool shifted) =>
    RegExp(r'^[A-Z]$').hasMatch(label) && !shifted
        ? label.toLowerCase()
        : label;

class IrisKeyboard extends StatelessWidget {
  final InputModel inputModel;
  final IrisLayout layout;
  // Bottom safe area to leave under the keys (0 while the bottom bar is shown).
  // Passed in so the page and the keyboard use the same panel height.
  final double bottomPad;
  final bool numpad; // QWERTY only
  final VoidCallback onToggleNumpad;
  const IrisKeyboard(
      {Key? key,
      required this.inputModel,
      required this.layout,
      required this.bottomPad,
      required this.numpad,
      required this.onToggleNumpad})
      : super(key: key);

  @override
  Widget build(BuildContext context) => layout == IrisLayout.qwerty
      ? _QwertyKeyboard(
          inputModel: inputModel,
          bottomPad: bottomPad,
          numpad: numpad,
          onToggleNumpad: onToggleNumpad)
      : _PyuronKeyboard(inputModel: inputModel, bottomPad: bottomPad);
}

class _PyuronKeyboard extends StatefulWidget {
  final InputModel inputModel;
  final double bottomPad;
  const _PyuronKeyboard(
      {Key? key, required this.inputModel, required this.bottomPad})
      : super(key: key);

  @override
  State<_PyuronKeyboard> createState() => _IrisKeyboardState();
}

class _IrisKeyboardState extends State<_PyuronKeyboard> {
  int _layer = 0;
  int? _held; // index of the layer key being held
  bool _usedWhileHeld = false;
  Timer? _holdTimer;
  final Set<int> _down = {};
  final Map<int, List<int>> _sent = {}; // key index -> HIDs to release
  final Map<int, MouseButtons> _clicks = {};

  InputModel get _input => widget.inputModel;

  @override
  void dispose() {
    _holdTimer?.cancel();
    for (final i in _sent.keys.toList()) {
      _release(i);
    }
    super.dispose();
  }

  void _hid(int code, bool down) => _sendHid(_input, code, down);

  void _tapHids(List<int> hids) {
    for (final h in hids) {
      _hid(h, true);
    }
    for (final h in hids.reversed) {
      _hid(h, false);
    }
  }

  _A? _actionAt(int i, int layer) {
    if (layer != 0) {
      final a = _layers[layer]?[i];
      if (a != null) return a;
    }
    return _base[i];
  }

  void _onDown(int i) {
    var a = _actionAt(i, _layer);
    if (a == null) return;
    setState(() => _down.add(i));
    if (a.layer != null && _held == null && _layer == 0) {
      _held = i;
      _usedWhileHeld = false;
      _holdTimer?.cancel();
      final lay = a.layer!;
      if (a.momentary) {
        setState(() => _layer = lay);
        return;
      }
      _holdTimer = Timer(_holdDelay, () {
        if (_held == i && mounted) setState(() => _layer = lay);
      });
      return;
    }
    if (_held != null && _layer == 0) {
      // Another key while a layer key is held: switch now, like ZMK's lt.
      _holdTimer?.cancel();
      final lay = _base[_held!]!.layer!;
      setState(() => _layer = lay);
      a = _actionAt(i, _layer);
      if (a == null) return;
    }
    if (_held != null) _usedWhileHeld = true;
    if (a.click != null) {
      _input.tapDown(a.click!);
      _clicks[i] = a.click!;
      return;
    }
    if (a.macro != null) {
      for (final step in a.macro!) {
        _tapHids(step.hids);
      }
      return;
    }
    if (a.hids.isNotEmpty) {
      for (final h in a.hids) {
        _hid(h, true);
      }
      _sent[i] = a.hids;
    }
  }

  void _release(int i) {
    final hids = _sent.remove(i);
    if (hids != null) {
      for (final h in hids.reversed) {
        _hid(h, false);
      }
    }
    final b = _clicks.remove(i);
    if (b != null) _input.tapUp(b);
  }

  void _onUp(int i) {
    if (!mounted) return;
    setState(() => _down.remove(i));
    if (_held == i) {
      _holdTimer?.cancel();
      final a = _base[i]!;
      final wasLayer = _layer;
      _held = null;
      setState(() => _layer = 0);
      if (!a.momentary && !_usedWhileHeld && wasLayer == 0) {
        _tapHids(a.hids);
      }
      return;
    }
    _release(i);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final col = mq.platformBrightness == Brightness.dark ? _dark : _light;
    final pitch = _pitch(size);
    final gap = _gapMm * _ptPerMm;
    final margin = _marginMm * _ptPerMm;
    final keySize = pitch - gap;
    final halfW = 6 * pitch - gap;
    final height =
        irisKeyboardHeight(size, widget.bottomPad, IrisLayout.pyuron);
    final fontSize = (keySize * 0.34).clamp(10.0, 17.0).toDouble();

    final keys = <Widget>[];
    for (var i = 0; i < _pos.length; i++) {
      final x = _pos[i][0], y = _pos[i][1];
      final left = x <= 5 ? margin + x * pitch : size.width - margin - halfW + (x - 7) * pitch;
      keys.add(Positioned(
        left: left,
        top: margin + y * pitch,
        width: keySize,
        height: keySize,
        child: _key(i, col, fontSize),
      ));
    }
    // Pyuron's trackballs sit between the 2nd and 3rd thumb keys of each half
    // (prototype, 2026-11-13): left scrolls, right moves the cursor.
    final ball = keySize * 0.78;
    final ballTop = margin + 3 * pitch + keySize / 2 - ball / 2;
    final inHalf = 2.5 * pitch + keySize / 2 - ball / 2;
    for (final right in [false, true]) {
      final halfLeft = right ? size.width - margin - halfW : margin;
      keys.add(Positioned(
        left: halfLeft + inHalf,
        top: ballTop,
        width: ball,
        height: ball,
        child: _IrisBall(
            input: _input, cursor: right, colors: col, fontSize: fontSize),
      ));
    }
    // Opaque so touches between the keys do not reach the remote screen below.
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        color: col.pad,
        child: Stack(children: keys),
      ),
    );
  }

  Widget _key(int i, _Colors col, double fontSize) {
    final layerList = _layers[_layer]; // null for the base layer
    final layerAction = layerList == null ? null : layerList[i];
    final a = layerAction ?? _base[i]!;
    final dimmed = _layer != 0 && layerAction == null && _held != i;
    // Letters are shown in lower case and in upper case while Shift is held,
    // like the iPad keyboard (2026-11-16).
    final shifted = _sent.values.any((h) => h.contains(_lshift));
    final label = _caseLabel(a.label, shifted);
    final isMod = label != 'Space' &&
        (label.runes.length > 1 || '←↑↓→'.contains(label));
    final down = _down.contains(i);
    final bg = down
        ? (isMod ? col.key : col.press)
        : (isMod ? col.mod : col.key);
    final sub = layerAction == null ? _base[i]!.sub : null;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _onDown(i),
      onPointerUp: (_) => _onUp(i),
      onPointerCancel: (_) => _onUp(i),
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: _held == i && _layer != 0
                ? Border.all(color: col.accent, width: 2)
                : null,
            boxShadow: [BoxShadow(color: col.shadow, offset: const Offset(0, 1))],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: col.fg,
                      fontSize: label.runes.length > 2 ? fontSize * 0.78 : fontSize,
                      height: 1.05)),
              if (sub != null)
                Text(sub,
                    style: TextStyle(
                        color: col.fg.withOpacity(0.55),
                        fontSize: fontSize * 0.62,
                        height: 1.05)),
            ],
          ),
        ),
      ),
    );
  }
}

// A trackball drawn as a round pad: dragging a finger on it moves the cursor
// (with the same acceleration as the screen) or scrolls the PC.
class _IrisBall extends StatefulWidget {
  final InputModel input;
  final bool cursor; // false: scroll
  final _Colors colors;
  final double fontSize;
  const _IrisBall(
      {Key? key,
      required this.input,
      required this.cursor,
      required this.colors,
      required this.fontSize})
      : super(key: key);

  @override
  State<_IrisBall> createState() => _IrisBallState();
}

class _IrisBallState extends State<_IrisBall> {
  // The prototype scrolled 1.5 px per pt on the ball and 1.2 with two fingers.
  static const _scrollRatio = 1.25;
  int? _pointer;
  Offset _last = Offset.zero;
  Duration _lastTime = Duration.zero;

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final d = e.position - _last;
    final dtMs = (e.timeStamp - _lastTime).inMicroseconds / 1000.0;
    _last = e.position;
    _lastTime = e.timeStamp;
    if (widget.cursor) {
      widget.input.irisMoveCursor(InputModel.irisAccelerate(d, dtMs));
    } else {
      widget.input.touchScroll(d * _scrollRatio);
    }
  }

  void _end(PointerEvent e) {
    if (e.pointer != _pointer) return;
    setState(() => _pointer = null);
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.colors;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        setState(() => _pointer = e.pointer);
        _last = e.position;
        _lastTime = e.timeStamp;
      },
      onPointerMove: _move,
      onPointerUp: _end,
      onPointerCancel: _end,
      child: Container(
        decoration: BoxDecoration(
          color: _pointer != null ? col.press : col.mod,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: col.shadow, offset: const Offset(0, 1))],
        ),
        alignment: Alignment.center,
        child: Text(widget.cursor ? 'Cursor' : 'Scroll',
            style: TextStyle(color: col.fg, fontSize: widget.fontSize * 0.7)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QWERTY: an ordinary JIS keyboard for the lab PC, compacted to 13.5 keys wide
// (no [ ] ろ かな; decided on the prototype 2026-11-13). The number row is
// drawn as outlines; Fn turns it into F1-F12, the arrows into Home/PgUp/
// PgDn/End and BS into Del. The narrow key left of 1 shows or hides a numpad.

const double _qLandscapePitchMm = 10.5; // decided 2026-11-13
const int _qRows = 5;
const double _qWidth = 13.5;
const double _qNumpadWidth = 4.5; // half a key of space and 4 keys
const int _rshift = 0xE5;
const int _fnKey = -1, _numKey = -2;

// Portrait: as wide as the screen allows (with the numpad, all of it fits).
double _qPitch(Size size, bool numpad) {
  if (size.width >= size.height) return _qLandscapePitchMm * _ptPerMm;
  final wmm = size.width / _ptPerMm;
  return (wmm - 2 * _marginMm) /
      (_qWidth + (numpad ? _qNumpadWidth : 0)) *
      _ptPerMm;
}

class _Q {
  final String label;
  final double w; // in keys
  final int hid;
  final String? shiftLabel;
  final String? fnLabel;
  final int? fnHid;
  final double h; // numpad only, in rows
  const _Q(this.label, this.w, this.hid,
      {this.shiftLabel, this.fnLabel, this.fnHid, this.h = 1});
}

const String _digitsShift = '!"#\$%&\'()';
final List<List<_Q>> _qRowsDef = [
  [
    const _Q('Num', 0.5, _numKey),
    for (var i = 0; i < 10; i++)
      _Q(i == 9 ? '0' : '${i + 1}', 1, i == 9 ? 0x27 : 0x1E + i,
          shiftLabel: i < 9 ? _digitsShift[i] : null,
          fnLabel: 'F${i + 1}',
          fnHid: 0x3A + i),
    const _Q('-', 1, 0x2D, shiftLabel: '=', fnLabel: 'F11', fnHid: 0x44),
    const _Q('^', 1, 0x2E, shiftLabel: '~', fnLabel: 'F12', fnHid: 0x45),
    const _Q('¥', 1, 0x89, shiftLabel: '|'),
  ],
  const [
    _Q('Esc', 1, 0x29),
    _Q('Q', 1, 0x14), _Q('W', 1, 0x1A), _Q('E', 1, 0x08), _Q('R', 1, 0x15),
    _Q('T', 1, 0x17), _Q('Y', 1, 0x1C), _Q('U', 1, 0x18), _Q('I', 1, 0x0C),
    _Q('O', 1, 0x12), _Q('P', 1, 0x13),
    _Q('@', 1, 0x2F, shiftLabel: '`'),
    _Q('BS', 1.5, 0x2A, fnLabel: 'Del', fnHid: 0x4C),
  ],
  const [
    _Q('Tab', 1.5, 0x2B),
    _Q('A', 1, 0x04), _Q('S', 1, 0x16), _Q('D', 1, 0x07), _Q('F', 1, 0x09),
    _Q('G', 1, 0x0A), _Q('H', 1, 0x0B), _Q('J', 1, 0x0D), _Q('K', 1, 0x0E),
    _Q('L', 1, 0x0F),
    _Q(';', 1, 0x33, shiftLabel: '+'),
    _Q(':', 1, 0x34, shiftLabel: '*'),
    _Q('Enter', 1, 0x28),
  ],
  const [
    _Q('Shift', 2, _lshift),
    _Q('Z', 1, 0x1D), _Q('X', 1, 0x1B), _Q('C', 1, 0x06), _Q('V', 1, 0x19),
    _Q('B', 1, 0x05), _Q('N', 1, 0x11), _Q('M', 1, 0x10),
    _Q(',', 1, 0x36, shiftLabel: '<'),
    _Q('.', 1, 0x37, shiftLabel: '>'),
    _Q('/', 1, 0x38, shiftLabel: '?'),
    _Q('Shift', 1.5, _rshift),
  ],
  const [
    _Q('Fn', 1, _fnKey),
    _Q('Ctrl', 1, _lctrl), _Q('Win', 1, _lgui), _Q('Alt', 1, _lalt),
    _Q('半/全', 1, 0x35), _Q('無変換', 1, 0x8B),
    _Q('Space', 2.5, 0x2C),
    _Q('変換', 1, 0x8A),
    _Q('←', 1, _left, fnLabel: 'Home', fnHid: 0x4A),
    _Q('↑', 1, _up, fnLabel: 'PgUp', fnHid: 0x4B),
    _Q('↓', 1, _down, fnLabel: 'PgDn', fnHid: 0x4E),
    _Q('→', 1, _right, fnLabel: 'End', fnHid: 0x4D),
  ],
];

// [key, column, row]; w and h are in keys and rows.
const List<List<Object>> _numpadDef = [
  [_Q('Num', 1, 0x53), 0, 0], [_Q('/', 1, 0x54), 1, 0],
  [_Q('*', 1, 0x55), 2, 0], [_Q('-', 1, 0x56), 3, 0],
  [_Q('7', 1, 0x5F), 0, 1], [_Q('8', 1, 0x60), 1, 1], [_Q('9', 1, 0x61), 2, 1],
  [_Q('+', 1, 0x57, h: 2), 3, 1],
  [_Q('4', 1, 0x5C), 0, 2], [_Q('5', 1, 0x5D), 1, 2], [_Q('6', 1, 0x5E), 2, 2],
  [_Q('1', 1, 0x59), 0, 3], [_Q('2', 1, 0x5A), 1, 3], [_Q('3', 1, 0x5B), 2, 3],
  [_Q('Enter', 1, 0x58, h: 2), 3, 3],
  [_Q('0', 2, 0x62), 0, 4], [_Q('.', 1, 0x63), 2, 4],
];

class _QwertyKeyboard extends StatefulWidget {
  final InputModel inputModel;
  final double bottomPad;
  final bool numpad;
  final VoidCallback onToggleNumpad;
  const _QwertyKeyboard(
      {Key? key,
      required this.inputModel,
      required this.bottomPad,
      required this.numpad,
      required this.onToggleNumpad})
      : super(key: key);

  @override
  State<_QwertyKeyboard> createState() => _QwertyKeyboardState();
}

class _QwertyKeyboardState extends State<_QwertyKeyboard> {
  bool _fn = false;
  String? _fnId;
  final Set<String> _down = {};
  final Map<String, int> _sent = {}; // key id -> HID to release

  @override
  void dispose() {
    for (final h in _sent.values) {
      _sendHid(widget.inputModel, h, false);
    }
    super.dispose();
  }

  void _onDown(String id, _Q q) {
    if (q.hid == _numKey) {
      widget.onToggleNumpad();
      return;
    }
    if (q.hid == _fnKey) {
      setState(() {
        _fn = true;
        _fnId = id;
        _down.add(id);
      });
      return;
    }
    final hid = _fn && q.fnHid != null ? q.fnHid! : q.hid;
    _sendHid(widget.inputModel, hid, true);
    setState(() {
      _sent[id] = hid;
      _down.add(id);
    });
  }

  void _onUp(String id) {
    if (!mounted) return;
    final hid = _sent.remove(id);
    if (hid != null) _sendHid(widget.inputModel, hid, false);
    setState(() {
      _down.remove(id);
      if (_fnId == id) {
        _fn = false;
        _fnId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final col = mq.platformBrightness == Brightness.dark ? _dark : _light;
    final p = _qPitch(size, widget.numpad);
    final gap = _gapMm * _ptPerMm;
    final margin = _marginMm * _ptPerMm;
    final height = irisKeyboardHeight(size, widget.bottomPad, IrisLayout.qwerty,
        numpad: widget.numpad);
    final total = (_qWidth + (widget.numpad ? _qNumpadWidth : 0)) * p - gap;
    final x0 = (size.width - total) / 2;
    final fontSize = ((p - gap) * 0.34).clamp(10.0, 17.0).toDouble();
    final shifted = _sent.values.any((h) => h == _lshift || h == _rshift);

    final keys = <Widget>[];
    for (var r = 0; r < _qRowsDef.length; r++) {
      var x = 0.0;
      for (var c = 0; c < _qRowsDef[r].length; c++) {
        final q = _qRowsDef[r][c];
        keys.add(_place('r${r}c$c', q, x0 + x * p, margin + r * p, q.w * p - gap,
            p - gap, col, fontSize, shifted, topRow: r == 0));
        x += q.w;
      }
    }
    if (widget.numpad) {
      final nx = x0 + (_qWidth + 0.5) * p;
      for (var i = 0; i < _numpadDef.length; i++) {
        final q = _numpadDef[i][0] as _Q;
        final c = _numpadDef[i][1] as int, r = _numpadDef[i][2] as int;
        keys.add(_place('n$i', q, nx + c * p, margin + r * p, q.w * p - gap,
            q.h * p - gap, col, fontSize, shifted));
      }
    }
    // Opaque so touches between the keys do not reach the remote screen below.
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        color: col.pad,
        child: Stack(children: keys),
      ),
    );
  }

  Widget _place(String id, _Q q, double left, double top, double w, double h,
      _Colors col, double fontSize, bool shifted,
      {bool topRow = false}) {
    final String label;
    if (q.hid == _numKey) {
      label = 'Num';
    } else if (_fn && q.fnLabel != null) {
      label = q.fnLabel!;
    } else if (shifted && q.shiftLabel != null) {
      label = q.shiftLabel!;
    } else {
      label = _caseLabel(q.label, shifted);
    }
    final down = _down.contains(id);
    final isMod = label != 'Space' &&
        (label.runes.length > 1 || '←↑↓→'.contains(label) || q.hid == _numKey);
    Color bg;
    Border? border;
    if (topRow) {
      // Number row: outline only (decided 2026-11-13), filled while pressed or
      // for the numpad key while the numpad is shown.
      final on = q.hid == _numKey && widget.numpad;
      bg = down ? col.press : (on ? col.mod : Colors.transparent);
      border = Border.all(color: col.mod, width: 1);
    } else {
      bg = down
          ? (isMod ? col.key : col.press)
          : (isMod ? col.mod : col.key);
    }
    final small = label.runes.length > 2;
    Widget text = Text(label,
        style: TextStyle(
            color: col.fg,
            fontSize: small ? fontSize * 0.74 : fontSize,
            height: 1.05));
    // The numpad key is only half a key wide, so its label runs vertically
    // (chosen on the prototype 2026-11-16).
    if (q.hid == _numKey) text = RotatedBox(quarterTurns: 1, child: text);
    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _onDown(id, q),
        onPointerUp: (_) => _onUp(id),
        onPointerCancel: (_) => _onUp(id),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: border,
            boxShadow: topRow
                ? null
                : [BoxShadow(color: col.shadow, offset: const Offset(0, 1))],
          ),
          alignment: Alignment.center,
          child: text,
        ),
      ),
    );
  }
}
