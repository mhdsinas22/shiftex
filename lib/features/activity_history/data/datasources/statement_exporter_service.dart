import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shiftex/core/errors/exceptions.dart';
import 'package:shiftex/features/activity_history/domain/entities/monthly_statement_entity.dart';
import 'package:shiftex/features/home/presentation/widgets/home_formatters.dart';

typedef StatementShareCallback =
    Future<void> Function(
      String filePath,
      String mimeType,
      String subject,
    );

typedef StatementTempDirectoryProvider = Future<Directory> Function();

/// Generates audit-accurate PDF and RFC-4180 CSV monthly reward statements
/// and hands them off to the OS share/save sheet cleanly.
class StatementExporterService {
  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final StatementTempDirectoryProvider _tempDirProvider;
  final StatementShareCallback _shareFile;

  const StatementExporterService({
    StatementTempDirectoryProvider? tempDirProvider,
    StatementShareCallback? shareFile,
  }) : _tempDirProvider = tempDirProvider ?? _defaultTempDir,
       _shareFile = shareFile ?? _defaultShareFile;

  static Future<Directory> _defaultTempDir() => getTemporaryDirectory();

  static Future<void> _defaultShareFile(
    String filePath,
    String mimeType,
    String subject,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: mimeType)],
        subject: subject,
      ),
    );
  }

  static String formatMonthYear(int year, int month) {
    final idx = (month - 1).clamp(0, 11);
    return '${_monthNames[idx]} $year';
  }

  /// Validates mathematical consistency of statement balances before export.
  void validateStatement(MonthlyStatementEntity statement) {
    if (statement.openingAvailableBalance < 0 ||
        statement.closingAvailableBalance < 0) {
      throw const AppAuthException(
        'Statement balance verification failed due to negative balance.',
        code: 'validation_failure',
      );
    }
    var availableNet = 0;
    for (final item in statement.items) {
      if (!item.isLockedAllocation) {
        availableNet += item.pointsCredited - item.pointsDeducted;
      }
    }
    if (statement.openingAvailableBalance + availableNet !=
        statement.closingAvailableBalance) {
      throw const AppAuthException(
        'Statement reconciliation mismatch detected between opening and closing balance.',
        code: 'validation_failure',
      );
    }
  }

  Future<ExportedStatementResultEntity> generateAndShare({
    required MonthlyStatementEntity statement,
    required StatementExportFormat format,
  }) async {
    validateStatement(statement);

    final monthPadded = statement.month.toString().padLeft(2, '0');
    final safeCode = statement.membershipId.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '',
    );
    final ext = format == StatementExportFormat.pdf ? 'pdf' : 'csv';
    final fileName =
        'SHIIFTEX_Statement_${safeCode}_${statement.year}_$monthPadded.$ext';

    final bytes =
        format == StatementExportFormat.pdf
            ? await buildPdfBytes(statement)
            : buildCsvBytes(statement);

    final dir = await _tempDirProvider();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final mimeType =
        format == StatementExportFormat.pdf ? 'application/pdf' : 'text/csv';
    final subject =
        'SHIIFTEX Rewards Statement - ${formatMonthYear(statement.year, statement.month)}';

    await _shareFile(file.path, mimeType, subject);

    return ExportedStatementResultEntity(
      format: format,
      fileName: fileName,
      filePath: file.path,
      bytes: bytes,
      statement: statement,
    );
  }

  Uint8List buildCsvBytes(MonthlyStatementEntity statement) {
    final monthLabel = formatMonthYear(statement.year, statement.month);
    final buffer = StringBuffer();

    buffer.writeln('SHIIFTEX Monthly Rewards Statement');
    buffer.writeln('Customer Name,${_csvCell(statement.customerName)}');
    buffer.writeln('Membership ID,${_csvCell(statement.membershipId)}');
    buffer.writeln('Statement Month,${_csvCell(monthLabel)}');
    buffer.writeln('Timezone,${_csvCell(statement.timezone)}');
    buffer.writeln(
      'Opening Available Balance (pts),${statement.openingAvailableBalance}',
    );
    buffer.writeln('Total Earned (pts),${statement.totalEarnedPoints}');
    buffer.writeln('Total Redeemed (pts),${statement.totalRedeemedPoints}');
    buffer.writeln(
      'Locked Allocations (pts),${statement.lockedAllocatedPoints}',
    );
    buffer.writeln(
      'Locked Points Released (pts),${statement.lockedReleasedPoints}',
    );
    buffer.writeln(
      'Closing Available Balance (pts),${statement.closingAvailableBalance}',
    );
    buffer.writeln();
    buffer.writeln(
      'Transaction Date,Transaction ID,Title,Description,Points Credited,Points Deducted,Status',
    );

    for (final item in statement.items) {
      final localDt = item.createdAt.toLocal();
      final dateStr =
          '${localDt.year}-${localDt.month.toString().padLeft(2, '0')}-${localDt.day.toString().padLeft(2, '0')} '
          '${localDt.hour.toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(2, '0')}';

      buffer.writeln(
        [
          _csvCell(dateStr),
          _csvCell(item.transactionId),
          _csvCell(HomeFormatters.stripCurrencyCopy(item.title)),
          _csvCell(HomeFormatters.stripCurrencyCopy(item.description)),
          '${item.pointsCredited}',
          '${item.pointsDeducted}',
          _csvCell(item.status),
        ].join(','),
      );
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<Uint8List> buildPdfBytes(MonthlyStatementEntity statement) async {
    final doc = pw.Document(
      title:
          'SHIIFTEX Statement ${formatMonthYear(statement.year, statement.month)}',
      author: 'SHIIFTEX Rewards',
    );
    final monthLabel = formatMonthYear(statement.year, statement.month);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build:
            (context) => [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0E1525),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SHIIFTEX REWARDS STATEMENT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          monthLabel,
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFB3D5FF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          _pdfSafeText(statement.customerName),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'ID: ${_pdfSafeText(statement.membershipId)}',
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFD9E8FF),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF3F4F6),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Table(
                  children: [
                    pw.TableRow(
                      children: [
                        _pdfMetric(
                          'Opening Available',
                          '${statement.openingAvailableBalance} pts',
                        ),
                        _pdfMetric(
                          'Total Earned',
                          '+${statement.totalEarnedPoints} pts',
                        ),
                        _pdfMetric(
                          'Total Redeemed',
                          '-${statement.totalRedeemedPoints} pts',
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfMetric(
                          'Locked Allocated',
                          '${statement.lockedAllocatedPoints} pts',
                        ),
                        _pdfMetric(
                          'Locked Released',
                          '${statement.lockedReleasedPoints} pts',
                        ),
                        _pdfMetric(
                          'Closing Available',
                          '${statement.closingAvailableBalance} pts',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Ledger Transactions',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF101828),
                ),
              ),
              pw.SizedBox(height: 8),
              if (statement.items.isEmpty)
                pw.Text(
                  'No reward ledger transactions recorded in this statement period.',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColor.fromInt(0xFF667085),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF1D63ED),
                  ),
                  cellStyle: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromInt(0xFF101828),
                  ),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 5,
                  ),
                  headers: const [
                    'Date',
                    'Ref ID',
                    'Description',
                    'Credit',
                    'Debit',
                    'Status',
                  ],
                  data:
                      statement.items.map((item) {
                        final dt = item.createdAt.toLocal();
                        final d =
                            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                        final desc =
                            item.description.isNotEmpty
                                ? '${item.title} - ${item.description}'
                                : item.title;
                        return [
                          d,
                          item.transactionId,
                          _pdfSafeText(desc),
                          item.pointsCredited > 0
                              ? '+${item.pointsCredited}'
                              : '-',
                          item.pointsDeducted > 0
                              ? '-${item.pointsDeducted}'
                              : '-',
                          item.status,
                        ];
                      }).toList(),
                ),
            ],
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: PdfColor.fromInt(0xFF667085),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF101828),
            ),
          ),
        ],
      ),
    );
  }

  String _pdfSafeText(String raw) {
    return HomeFormatters.stripCurrencyCopy(raw)
        .replaceAll('•', '-')
        .replaceAll('×', 'x')
        .replaceAll('≈', '~');
  }

  String _csvCell(String raw) {
    final sanitized =
        raw.startsWith('=') ||
                raw.startsWith('@') ||
                raw.startsWith('+') ||
                raw.startsWith('-')
            ? "'$raw"
            : raw;
    final escaped = sanitized.replaceAll('"', '""');
    return '"$escaped"';
  }
}
