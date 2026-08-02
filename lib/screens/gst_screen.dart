import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../history/gst_store.dart';

class GstScreen extends StatelessWidget {
  const GstScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GstStore>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('GST'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : store.folders.isEmpty
              ? const Center(child: Text('No GST bills yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: store.folders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final folder = store.folders[index];
                    final folderId = folder['folderId'] as String;
                    final label =
                        folder['label'] as String? ?? folderId;
                    final downloaded = folder['downloaded'] == true;
                    final count =
                        store.billsForFolder(folderId).length;

                    return InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/gst_month_bills',
                          arguments: {
                            'folderId': folderId,
                            'label': label,
                          },
                        );
                      },
                      child: Card(
                        elevation: 3,
                        color: downloaded
                            ? const Color(0xFFE8F5E9)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: downloaded
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: downloaded ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder,
                                size: 40,
                                color: downloaded
                                    ? Colors.green
                                    : Colors.amber.shade700,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: downloaded
                                            ? Colors.green.shade800
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$count bill${count == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (downloaded)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              else
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade500,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
