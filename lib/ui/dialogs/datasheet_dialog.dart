import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/product.dart';

class DatasheetDialog extends StatelessWidget {
  final Product product;

  const DatasheetDialog({super.key, required this.product});

  Future<void> _openDatasheetUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open URL: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDatasheet = product.datasheetUrl != null && product.datasheetUrl!.isNotEmpty;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      title: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.cyanAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Datasheet: ${product.name}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasDatasheet) ...[
              const Icon(Icons.description_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'No datasheet attached for this component.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          product.datasheetType == 'file' ? Icons.file_present : Icons.link,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.datasheetName ?? 'Component Datasheet',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Datasheet Source:',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      product.datasheetUrl!,
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _openDatasheetUrl(context, product.datasheetUrl!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('OPEN DATASHEET IN BROWSER / VIEWER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
