import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class DoctryColumn {
  const DoctryColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.compactLabel,
  });

  final String label;
  final String? compactLabel;
  final int flex;
  final Widget Function(BuildContext context, int index) cell;
}

class DoctryTable extends StatelessWidget {
  const DoctryTable({
    super.key,
    required this.columns,
    required this.rowCount,
    this.emptyMessage = 'Aucune donnée disponible.',
    this.onRowTap,
  });

  final List<DoctryColumn> columns;
  final int rowCount;
  final String emptyMessage;
  final void Function(int index)? onRowTap;

  bool get _isEmpty => rowCount == 0;

  @override
  Widget build(BuildContext context) {
    if (_isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text(
            emptyMessage,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 820) {
          return _wideLayout(context);
        }
        return _compactLayout(context);
      },
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            color: AppColors.darkBlue,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: <Widget>[
                for (final DoctryColumn column in columns)
                  Expanded(
                    flex: column.flex,
                    child: Text(
                      column.label,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (int index = 0; index < rowCount; index++)
            _wideRow(context, index),
        ],
      ),
    );
  }

  Widget _wideRow(BuildContext context, int index) {
    final Color background = index.isEven ? AppColors.white : const Color(0xFFFAFBFD);
    return Material(
      color: background,
      child: InkWell(
        onTap: onRowTap == null ? null : () => onRowTap!(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (final DoctryColumn column in columns)
                Expanded(
                  flex: column.flex,
                  child: DefaultTextStyle(
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
                    child: column.cell(context, index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactLayout(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int index = 0; index < rowCount; index++) _compactRow(context, index),
      ],
    );
  }

  Widget _compactRow(BuildContext context, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onRowTap == null ? null : () => onRowTap!(index),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final DoctryColumn column in columns)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 118,
                      child: Text(
                        column.compactLabel ?? column.label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        child: column.cell(context, index),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
