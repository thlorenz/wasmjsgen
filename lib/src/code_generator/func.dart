// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

import 'binding.dart';
import 'binding_string.dart';
import 'type.dart';
import 'writer.dart';

/// A binding for C function.
///
/// For a C function -
/// ```c
/// int sum(int a, int b);
/// ```
/// The Generated dart code is -
/// ```dart
/// int sum(int a, int b) {
///   return _sum(a, b);
/// }
///
/// final _dart_sum _sum = _dylib.lookupFunction<_c_sum, _dart_sum>('sum');
///
/// typedef _c_sum = ffi.Int32 Function(ffi.Int32 a, ffi.Int32 b);
///
/// typedef _dart_sum = int Function(int a, int b);
/// ```
class Func extends Binding {
  final String lookupSymbolName;
  final Type returnType;
  final List<Parameter> parameters;

  /// [lookupSymbolName], if not provided, takes the value of [name].
  Func({
    @required String name,
    String lookupSymbolName,
    String dartDoc,
    @required this.returnType,
    List<Parameter> parameters,
  })  : parameters = parameters ?? [],
        lookupSymbolName = lookupSymbolName ?? name,
        super(name: name, dartDoc: dartDoc) {
    for (var i = 0; i < this.parameters.length; i++) {
      if (this.parameters[i].name == null ||
          this.parameters[i].name.trim() == '') {
        this.parameters[i].name = 'arg$i';
      }
    }
  }

  @override
  BindingString toBindingString(Writer w) {
    final s = StringBuffer();
    final enclosingFuncName = name;

    // Ensure name conflicts are resolved for typedefs generated.
    final funcVarName = w.uniqueNamer.makeUnique('_$name');
    final typedefC = w.uniqueNamer.makeUnique('_c_$name');
    final typedefDart = w.uniqueNamer.makeUnique('_dart_$name');

    // Write typedef's required by parameters and resolve name conflicts.
    for (final p in parameters) {
      final base = p.type.getBaseType();
      if (base.broadType == BroadType.NativeFunction) {
        base.nativeFunc.name =
            w.uniqueNamer.makeUnique(base.nativeFunc.name);
        s.write(base.nativeFunc.toTypedefString(w));
      }
    }

    if (dartDoc != null) {
      s.write('/// ');
      s.writeAll(dartDoc.split('\n'), '\n/// ');
      s.write('\n');
    }

    // Write enclosing function.
    s.write('${returnType.getDartType(w)} $enclosingFuncName(\n');
    for (final p in parameters) {
      s.write('  ${p.type.getDartType(w)} ${p.name},\n');
    }
    s.write(') {\n');
    s.write('  return $funcVarName(\n');
    for (final p in parameters) {
      s.write('    ${p.name},\n');
    }
    s.write('  );\n');
    s.write('}\n\n');

    // Write function with dylib lookup.
    s.write(
        "final $typedefDart $funcVarName = ${w.dylibIdentifier}.lookupFunction<$typedefC,$typedefDart>('$lookupSymbolName');\n\n");

    // Write typdef for C.
    s.write('typedef $typedefC = ${returnType.getCType(w)} Function(\n');
    for (final p in parameters) {
      s.write('  ${p.type.getCType(w)} ${p.name},\n');
    }
    s.write(');\n\n');

    // Write typdef for dart.
    s.write('typedef $typedefDart = ${returnType.getDartType(w)} Function(\n');
    for (final p in parameters) {
      s.write('  ${p.type.getDartType(w)} ${p.name},\n');
    }
    s.write(');\n\n');

    return BindingString(type: BindingStringType.func, string: s.toString());
  }
}

/// Represents a Function's parameter.
class Parameter {
  String name;
  final Type type;

  Parameter({this.name, @required this.type});
}