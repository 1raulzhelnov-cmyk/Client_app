import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/l10n.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    required this.value,
    required this.data,
    this.loading,
    this.error,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final Widget Function(Object error, StackTrace stack)? error;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading ?? const SizedBox.shrink(),
      error: (Object err, StackTrace stack) =>
          error?.call(err, stack) ??
          Center(
            child: Text(
              S.of(context).errorGeneric,
              textAlign: TextAlign.center,
            ),
          ),
    );
  }
}
