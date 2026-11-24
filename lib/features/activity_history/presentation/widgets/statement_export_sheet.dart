import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shiftex/core/constants/app_colors.dart';
import 'package:shiftex/features/activity_history/data/datasources/statement_exporter_service.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_bloc.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_event.dart';
import 'package:shiftex/features/activity_history/presentation/bloc/activity_history_state.dart';

/// Modal bottom sheet allowing customers to select a calendar month
/// and export format (PDF or CSV) for their verified rewards statement.
class StatementExportSheet extends StatefulWidget {
  final VoidCallback onClose;

  const StatementExportSheet({super.key, required this.onClose});

  static Future<void> show(
    BuildContext context, {
    required ActivityHistoryBloc bloc,
  }) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      constraints: BoxConstraints(maxHeight: maxHeight),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return BlocProvider<ActivityHistoryBloc>.value(
          value: bloc,
          child: StatementExportSheet(
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        );
      },
    );
  }

  @override
  State<StatementExportSheet> createState() => _StatementExportSheetState();
}

class _StatementExportSheetState extends State<StatementExportSheet> {
  late final List<({int year, int month})> _months;
  late ({int year, int month}) _selectedMonth;
  StatementExportFormat _selectedFormat = StatementExportFormat.pdf;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = List.generate(12, (idx) {
      final dt = DateTime(now.year, now.month - idx, 1);
      return (year: dt.year, month: dt.month);
    });
    _selectedMonth = _months.first;
  }

  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 22.0;

    return BlocConsumer<ActivityHistoryBloc, ActivityHistoryState>(
      listenWhen:
          (previous, current) =>
              previous.status != current.status &&
              current.status == ActivityHistoryStatus.exportSuccess,
      listener: (context, state) {
        if (mounted && state.status == ActivityHistoryStatus.exportSuccess) {
          widget.onClose();
        }
      },
      builder: (context, state) {
        final isExporting = state.status == ActivityHistoryStatus.exporting;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Monthly Statement',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Export verified ledger activity and historical cash values',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: AppColors.inputBackground,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onClose,
                        child: const SizedBox(
                          width: 38,
                          height: 38,
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Select Statement Month',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _months.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final entry = _months[index];
                      final isSelected =
                          entry.year == _selectedMonth.year &&
                          entry.month == _selectedMonth.month;
                      final label = StatementExporterService.formatMonthYear(
                        entry.year,
                        entry.month,
                      );

                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected:
                            isExporting
                                ? null
                                : (_) =>
                                    setState(() => _selectedMonth = entry),
                        selectedColor: AppColors.primaryButtonDark,
                        backgroundColor: AppColors.inputBackground,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color:
                              isSelected
                                  ? AppColors.white
                                  : AppColors.textPrimary,
                        ),
                        shape: const StadiumBorder(
                          side: BorderSide(color: Colors.transparent),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Export Format',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormatOption(
                        format: StatementExportFormat.pdf,
                        title: 'PDF Statement',
                        subtitle: 'Formatted audit report',
                        icon: Icons.picture_as_pdf_rounded,
                        isExporting: isExporting,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildFormatOption(
                        format: StatementExportFormat.csv,
                        title: 'CSV Ledger',
                        subtitle: 'Spreadsheet data',
                        icon: Icons.table_chart_rounded,
                        isExporting: isExporting,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Includes Customer Name, Membership ID, Opening Balance, Total Earned, Total Redeemed, Locked Allocations & Releases, Closing Balance, and Itemized Points Ledger.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                if (state.errorMessage != null &&
                    state.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.errorRed,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        isExporting
                            ? null
                            : () => context.read<ActivityHistoryBloc>().add(
                              ActivityMonthlyStatementExportRequested(
                                year: _selectedMonth.year,
                                month: _selectedMonth.month,
                                format: _selectedFormat,
                              ),
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.primaryBlue.withValues(
                        alpha: 0.5,
                      ),
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child:
                        isExporting
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: AppColors.white,
                              ),
                            )
                            : Text(
                              _selectedFormat == StatementExportFormat.pdf
                                  ? 'Generate & Share PDF'
                                  : 'Generate & Share CSV',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormatOption({
    required StatementExportFormat format,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isExporting,
  }) {
    final isSelected = _selectedFormat == format;
    return Material(
      color:
          isSelected
              ? AppColors.gradientTopLight
              : AppColors.inputBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap:
            isExporting
                ? null
                : () => setState(() => _selectedFormat = format),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isSelected ? AppColors.primaryBlue : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color:
                    isSelected
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
