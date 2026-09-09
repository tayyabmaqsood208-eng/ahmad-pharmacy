import 'package:flutter/material.dart';
import '../../data/models/sale.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

class ReceiptModal extends StatelessWidget {
  final Sale sale;
  final String currencySymbol;

  const ReceiptModal({
    super.key,
    required this.sale,
    this.currencySymbol = 'Rs',
  });

  static void show(BuildContext context, Sale sale, {String currencySymbol = 'Rs'}) {
    showDialog(
      context: context,
      builder: (context) => ReceiptModal(sale: sale, currencySymbol: currencySymbol),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header & Success Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sale Completed Successfully!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ahmad Pharmacy • POS Invoice',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Invoice Details
              _buildReceiptRow('Invoice Number:', sale.invoiceNo, isBold: true),
              _buildReceiptRow('Date & Time:', Formatters.dateTime(sale.createdAt)),
              _buildReceiptRow('Customer:', sale.customerName),
              _buildReceiptRow('Payment Method:', sale.paymentMethod),
              _buildReceiptRow('Status:', sale.status, textColor: AppColors.success),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Itemized Table
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ITEMS PURCHASED',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),

              ...sale.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.medicineName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (item.batchNumber != null)
                            Text(
                              'Batch: ${item.batchNumber}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'x${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        Formatters.currency(item.total, symbol: currencySymbol),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Financial Totals
              _buildReceiptRow('Subtotal:', Formatters.currency(sale.subtotal, symbol: currencySymbol)),
              if (sale.discount > 0)
                _buildReceiptRow('Discount:', '- ${Formatters.currency(sale.discount, symbol: currencySymbol)}', textColor: AppColors.danger),
              _buildReceiptRow('Tax:', Formatters.currency(sale.taxAmount, symbol: currencySymbol)),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildReceiptRow(
                  'Total Paid:',
                  Formatters.currency(sale.totalAmount, symbol: currencySymbol),
                  isBold: true,
                  fontSize: 16,
                  textColor: AppColors.primary,
                ),
              ),

              if (sale.paymentMethod == 'Cash') ...[
                const SizedBox(height: 8),
                _buildReceiptRow('Amount Tendered:', Formatters.currency(sale.paidAmount, symbol: currencySymbol)),
                _buildReceiptRow('Change Due:', Formatters.currency(sale.changeAmount, symbol: currencySymbol), isBold: true),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print Receipt'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
