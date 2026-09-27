import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/fee_models.dart';
import '../../../students/data/models/student_models.dart';
import '../../../bulk_import/presentation/providers/web_download_helper.dart';

class FeeReceiptDialog extends StatefulWidget {
  final FeePayment payment;
  final StudentDto student;
  final String schoolName;
  final String? schoolAddress;
  final String? schoolPhone;
  final String? schoolEmail;
  final String? academicYearName;
  final String? feeTypeName;
  final double? assignedAmount;
  final double? concessionAmount;
  final double? fineAmount;
  final double? remainingBalance;
  final String? collectedByName;
  final BaseApiClient? apiClient;

  const FeeReceiptDialog({
    super.key,
    required this.payment,
    required this.student,
    required this.schoolName,
    this.schoolAddress,
    this.schoolPhone,
    this.schoolEmail,
    this.academicYearName,
    this.feeTypeName,
    this.assignedAmount,
    this.concessionAmount,
    this.fineAmount,
    this.remainingBalance,
    this.collectedByName,
    this.apiClient,
  });

  @override
  State<FeeReceiptDialog> createState() => _FeeReceiptDialogState();
}

class _FeeReceiptDialogState extends State<FeeReceiptDialog> {
  bool _isDownloading = false;

  final currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final dateFormatter = DateFormat('dd MMM yyyy');
  final dateTimeFormatter = DateFormat('dd MMM yyyy, hh:mm a');

  String _generatePrintableHtml() {
    final pay = widget.payment;
    final st = widget.student;
    final receiptNo = pay.receiptNumber ?? 'RCPT-${pay.id.substring(0, 8).toUpperCase()}';
    final payDate = dateTimeFormatter.format(pay.paymentDate);
    final isCancelled = pay.status == PaymentStatus.CANCELLED;

    final assigned = widget.assignedAmount ?? pay.amountPaid;
    final concession = widget.concessionAmount ?? 0.0;
    final fine = widget.fineAmount ?? 0.0;
    final netPayable = (assigned - concession + fine).clamp(0.0, double.infinity);
    final balance = widget.remainingBalance ?? 0.0;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Fee Receipt - $receiptNo</title>
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      color: #333;
      margin: 0;
      padding: 24px;
      background: #fff;
    }
    .receipt-box {
      max-width: 680px;
      margin: auto;
      border: 1px solid #ddd;
      border-radius: 8px;
      padding: 28px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.05);
    }
    .header {
      text-align: center;
      border-bottom: 2px solid #1A237E;
      padding-bottom: 16px;
      margin-bottom: 20px;
    }
    .school-title {
      font-size: 24px;
      font-weight: bold;
      color: #1A237E;
      margin: 0 0 4px 0;
    }
    .school-meta {
      font-size: 12px;
      color: #666;
      margin: 2px 0;
    }
    .receipt-title {
      font-size: 16px;
      font-weight: bold;
      letter-spacing: 1px;
      color: #333;
      margin-top: 12px;
    }
    .status-badge {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: bold;
      margin-top: 6px;
      background-color: ${isCancelled ? '#FFEBEE' : '#E8F5E9'};
      color: ${isCancelled ? '#C62828' : '#2E7D32'};
      border: 1px solid ${isCancelled ? '#FFCDD2' : '#C8E6C9'};
    }
    .meta-grid {
      display: flex;
      justify-content: space-between;
      margin-bottom: 20px;
      font-size: 13px;
    }
    .meta-col {
      width: 48%;
    }
    .meta-row {
      display: flex;
      justify-content: space-between;
      padding: 4px 0;
      border-bottom: 1px dashed #eee;
    }
    .meta-label {
      color: #777;
    }
    .meta-value {
      font-weight: 600;
      color: #222;
    }
    .table-section {
      width: 100%;
      border-collapse: collapse;
      margin: 20px 0;
    }
    .table-section th {
      background: #F4F6F9;
      color: #1A237E;
      text-align: left;
      padding: 10px;
      font-size: 12px;
      border-top: 1px solid #ddd;
      border-bottom: 1px solid #ddd;
    }
    .table-section td {
      padding: 10px;
      font-size: 13px;
      border-bottom: 1px solid #eee;
    }
    .amount-col {
      text-align: right;
    }
    .paid-row {
      background: #F9FBF9;
      font-weight: bold;
      color: #2E7D32;
      font-size: 14px;
    }
    .balance-row {
      background: #FFFBFB;
      font-weight: bold;
      color: ${balance > 0 ? '#C62828' : '#2E7D32'};
    }
    .footer-section {
      margin-top: 36px;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      font-size: 12px;
    }
    .signature-box {
      text-align: center;
      width: 180px;
      border-top: 1px solid #333;
      padding-top: 6px;
      font-size: 11px;
      color: #555;
    }
    .watermark {
      font-size: 10px;
      color: #999;
      text-align: center;
      margin-top: 24px;
    }
    @media print {
      body { padding: 0; }
      .receipt-box { border: none; box-shadow: none; width: 100%; }
      @page { margin: 1.5cm; }
    }
  </style>
</head>
<body>
  <div class="receipt-box">
    <div class="header">
      <div class="school-title">${widget.schoolName}</div>
      ${widget.schoolAddress != null ? '<div class="school-meta">${widget.schoolAddress!}</div>' : ''}
      ${widget.schoolPhone != null ? '<div class="school-meta">Phone: ${widget.schoolPhone!}</div>' : ''}
      <div class="receipt-title">FEE PAYMENT RECEIPT</div>
      <div class="status-badge">${isCancelled ? 'CANCELLED / REVERSED' : 'PAYMENT RECEIVED'}</div>
    </div>

    <div class="meta-grid">
      <div class="meta-col">
        <div class="meta-row"><span class="meta-label">Receipt No:</span><span class="meta-value">$receiptNo</span></div>
        <div class="meta-row"><span class="meta-label">Payment Date:</span><span class="meta-value">$payDate</span></div>
        <div class="meta-row"><span class="meta-label">Payment Mode:</span><span class="meta-value">${pay.paymentMethod.name.replaceAll('_', ' ')}</span></div>
        <div class="meta-row"><span class="meta-label">Transaction Ref:</span><span class="meta-value">${pay.transactionReference ?? 'N/A'}</span></div>
      </div>
      <div class="meta-col">
        <div class="meta-row"><span class="meta-label">Student Name:</span><span class="meta-value">${st.firstName} ${st.lastName}</span></div>
        <div class="meta-row"><span class="meta-label">Admission No:</span><span class="meta-value">${st.admissionNumber}</span></div>
        <div class="meta-row"><span class="meta-label">Class & Section:</span><span class="meta-value">${st.className ?? ''} - ${st.sectionName ?? ''}</span></div>
        <div class="meta-row"><span class="meta-label">Academic Year:</span><span class="meta-value">${widget.academicYearName ?? 'Current Year'}</span></div>
      </div>
    </div>

    <table class="table-section">
      <thead>
        <tr>
          <th>Particulars / Description</th>
          <th class="amount-col">Amount (INR)</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>${widget.feeTypeName ?? 'Tuition & Academic Fees'} (Assigned)</td>
          <td class="amount-col">₹${assigned.toStringAsFixed(2)}</td>
        </tr>
        ${concession > 0 ? '<tr><td>Less: Concession / Scholarship Waiver</td><td class="amount-col" style="color: #2E7D32;">- ₹${concession.toStringAsFixed(2)}</td></tr>' : ''}
        ${fine > 0 ? '<tr><td>Add: Fine / Late Charges</td><td class="amount-col" style="color: #C62828;">+ ₹${fine.toStringAsFixed(2)}</td></tr>' : ''}
        <tr style="font-weight: 600; border-top: 1px solid #ddd;">
          <td>Net Total Payable</td>
          <td class="amount-col">₹${netPayable.toStringAsFixed(2)}</td>
        </tr>
        <tr class="paid-row">
          <td>AMOUNT PAID (This Receipt)</td>
          <td class="amount-col">₹${pay.amountPaid.toStringAsFixed(2)}</td>
        </tr>
        <tr class="balance-row">
          <td>Remaining Balance Due</td>
          <td class="amount-col">₹${balance.toStringAsFixed(2)}</td>
        </tr>
      </tbody>
    </table>

    ${pay.cancelReason != null ? '<div style="color: #C62828; font-size: 12px; margin: 8px 0;">Cancellation Reason: ${pay.cancelReason!}</div>' : ''}

    <div class="footer-section">
      <div>
        <div>Collected By: <b>${widget.collectedByName ?? 'School Cashier'}</b></div>
        <div style="color: #888; font-size: 11px; margin-top: 4px;">System ID: ${pay.id.substring(0, 8)}</div>
      </div>
      <div class="signature-box">
        Authorized Signatory
      </div>
    </div>

    <div class="watermark">
      This is an official computer-generated receipt issued by EduPulse AI ERP. Valid without physical stamp.
    </div>
  </div>
</body>
</html>
''';
  }

  Future<void> _handleDownloadPdf() async {
    final receiptNo = widget.payment.receiptNumber;
    setState(() => _isDownloading = true);

    try {
      if (receiptNo != null && widget.apiClient != null) {
        // Try backend PDF download endpoint
        final res = await widget.apiClient!.get(
          '/fees/receipts/$receiptNo/download',
          options: Options(responseType: ResponseType.bytes),
          mapper: (bytes) => bytes,
        );

        bool downloaded = false;
        res.when(
          onSuccess: (data) {
            if (data is List<int>) {
              downloadBinaryFile('EduPulse_Receipt_$receiptNo.pdf', data, mimeType: 'application/pdf');
              downloaded = true;
            }
          },
          onFailure: (_) {},
        );

        if (downloaded) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Receipt $receiptNo downloaded successfully.')),
            );
          }
          return;
        }
      }

      // Fallback to printable browser document
      printReceiptHtml(_generatePrintableHtml());
    } catch (e) {
      // Fallback
      printReceiptHtml(_generatePrintableHtml());
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _handlePrint() {
    printReceiptHtml(_generatePrintableHtml());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pay = widget.payment;
    final st = widget.student;
    final isCancelled = pay.status == PaymentStatus.CANCELLED;
    final receiptNo = pay.receiptNumber ?? 'RCPT-${pay.id.substring(0, 8).toUpperCase()}';

    final assigned = widget.assignedAmount ?? pay.amountPaid;
    final concession = widget.concessionAmount ?? 0.0;
    final fine = widget.fineAmount ?? 0.0;
    final netPayable = (assigned - concession + fine).clamp(0.0, double.infinity);
    final balance = widget.remainingBalance ?? 0.0;

    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxH = (screenH * 0.92).clamp(400.0, 780.0);
    final insetPadding = EdgeInsets.symmetric(
      horizontal: screenW < 600 ? 12 : 24,
      vertical: screenH < 600 ? 12 : 24,
    );

    return Dialog(
      insetPadding: insetPadding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : const Color(0xFFF7F9FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.schoolName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.schoolAddress != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.schoolAddress!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCancelled ? Colors.red : Colors.green,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        isCancelled ? 'CANCELLED / REVERSED' : 'OFFICIAL FEE RECEIPT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCancelled ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Metadata Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _buildMetaRow('Receipt Number', receiptNo, isCopyable: true),
                    _buildMetaRow('Payment Date', dateTimeFormatter.format(pay.paymentDate)),
                    _buildMetaRow('Student Name', '${st.firstName} ${st.lastName}'),
                    _buildMetaRow('Admission Number', st.admissionNumber, isCopyable: true),
                    _buildMetaRow('Class & Section', '${st.className ?? "-"} (${st.sectionName ?? "-"})'),
                    if (widget.academicYearName != null)
                      _buildMetaRow('Academic Year', widget.academicYearName!),
                    _buildMetaRow('Payment Method', pay.paymentMethod.name.replaceAll('_', ' ')),
                    if (pay.transactionReference != null && pay.transactionReference!.isNotEmpty)
                      _buildMetaRow('Transaction Ref', pay.transactionReference!, isCopyable: true),
                    _buildMetaRow('Collected By', widget.collectedByName ?? 'School Cashier'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Fee Breakdown Table
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(child: Text('Fee Item Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    _buildLedgerRow('${widget.feeTypeName ?? "Tuition Fee"} (Assigned)', currencyFormatter.format(assigned)),
                    if (concession > 0)
                      _buildLedgerRow('Concession / Waiver', '- ${currencyFormatter.format(concession)}', color: Colors.green),
                    if (fine > 0)
                      _buildLedgerRow('Late Fee / Fine', '+ ${currencyFormatter.format(fine)}', color: Colors.red),
                    const Divider(height: 1),
                    _buildLedgerRow('Net Total Payable', currencyFormatter.format(netPayable), isBold: true),
                    Container(
                      color: Colors.green.withValues(alpha: 0.1),
                      child: _buildLedgerRow(
                        'AMOUNT PAID (This Transaction)',
                        currencyFormatter.format(pay.amountPaid),
                        isBold: true,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Container(
                      color: balance > 0 ? Colors.red.withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.05),
                      child: _buildLedgerRow(
                        'Remaining Balance Due',
                        currencyFormatter.format(balance),
                        isBold: true,
                        color: balance > 0 ? Colors.red.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              if (pay.cancelReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cancellation Reason: ${pay.cancelReason}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons Row
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print Receipt'),
                    onPressed: _handlePrint,
                  ),
                  FilledButton.icon(
                    icon: _isDownloading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download Receipt'),
                    onPressed: _isDownloading ? null : _handleDownloadPdf,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isCopyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          if (isCopyable) ...[
            IconButton(
              icon: const Icon(Icons.copy, size: 13, color: Colors.blueGrey),
              tooltip: 'Copy',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 2)),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLedgerRow(String label, String amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
