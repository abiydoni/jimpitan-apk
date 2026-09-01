import 'package:flutter/material.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class InventoryPage extends StatefulWidget {
  final String villageId;
  final Map<String, bool> permissions;

  const InventoryPage({super.key, required this.villageId, required this.permissions});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool get _canCreate => widget.permissions['create'] == true;
  bool get _canEdit => widget.permissions['edit'] == true;
  bool get _canDelete => widget.permissions['delete'] == true;

  Future<List<dynamic>>? _inventoryFuture;
  Future<List<dynamic>>? _loansFuture;
  Future<List<dynamic>>? _journalsFuture;
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupFCM();
  }

  void _loadData() {
    setState(() {
      _inventoryFuture = ApiService.getInventoryItems(widget.villageId);
      _loansFuture = ApiService.getInventoryLoans(widget.villageId);
      _journalsFuture = ApiService.getDuesJournals(widget.villageId);
    });
  }

  void _setupFCM() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['action'] == 'REFRESH_INVENTORY' || message.data['action'] == 'REFRESH_DUES') {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showItemForm([Map<String, dynamic>? doc]) async {
    if (doc == null && !_canCreate) return;
    if (doc != null && !_canEdit) return;
    
    final nameCtrl = TextEditingController(text: doc?['name'] ?? '');
    final stockCtrl = TextEditingController(text: (doc?['stock'] ?? 0).toString());
    final feeCtrl = TextEditingController(text: (doc?['fee'] ?? 0).toString());
    
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppModalDialog(
          title: doc == null ? 'Tambah Barang' : 'Edit Barang',
          headerIcon: doc == null ? Icons.add_box : Icons.edit,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Barang',
                  prefixIcon: const Icon(Icons.inventory_2, color: Colors.black45),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Stok',
                  prefixIcon: const Icon(Icons.format_list_numbered, color: Colors.black45),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Biaya Sewa (Opsional)',
                  prefixIcon: const Icon(Icons.monetization_on, color: Colors.black45),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, true), 
                      child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );

    if (res == true && nameCtrl.text.isNotEmpty) {
      final data = {
        'villageId': widget.villageId,
        'name': nameCtrl.text,
        'stock': int.tryParse(stockCtrl.text) ?? 0,
        'fee': int.tryParse(feeCtrl.text) ?? 0,
      };
      
      EasyLoading.show(status: 'Menyimpan...');
      try {
        data['id'] = doc == null ? 'inv_${DateTime.now().millisecondsSinceEpoch}' : doc['id'];
        bool success = false;
        if (doc == null) {
          success = await ApiService.createInventoryItem(data);
        } else {
          success = await ApiService.updateInventoryItem(doc['id'], data);
        }
        if (success) _loadData();
      } catch (e) {
        EasyLoading.showError('Gagal menyimpan');
      } finally {
        EasyLoading.dismiss();
      }
    }
  }

  Future<void> _recordLoan([Map<String, dynamic>? preselectedItem]) async {
    if (!_canCreate) return;

    final allItems = await ApiService.getInventoryItems(widget.villageId);
    final items = allItems.where((doc) => (doc['stock'] ?? 0) > 0).toList();
    if (items.isEmpty) {
      if (mounted) {
        CustomToast.show(context, 'Tidak ada barang dengan stok tersedia');
      }
      return;
    }

    final borrowerCtrl = TextEditingController();
    Map<String, bool> selectedItems = { 
        for (var doc in items) doc['id']: preselectedItem != null ? doc['id'] == preselectedItem['id'] : false 
    };
    Map<String, TextEditingController> qtyControllers = {
        for (var doc in items) doc['id']: TextEditingController(text: (doc['stock'] ?? 0).toString())
    };
    Map<String, TextEditingController> daysControllers = {
        for (var doc in items) doc['id']: TextEditingController(text: '1')
    };
    Map<String, TextEditingController> feeControllers = {
        for (var doc in items) doc['id']: TextEditingController(text: ((doc['fee'] ?? 0) * (doc['stock'] ?? 0)).toString())
    };

    if (!mounted) return;

    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateFee(String id, int baseFee) {
              final qty = int.tryParse(qtyControllers[id]!.text) ?? 0;
              final days = int.tryParse(daysControllers[id]!.text) ?? 0;
              feeControllers[id]!.text = (baseFee * qty * days).toString();
            }

            int getGrandTotal() {
              int total = 0;
              for (var doc in items) {
                if (selectedItems[doc['id']] == true) {
                  total += int.tryParse(feeControllers[doc['id']]!.text) ?? 0;
                }
              }
              return total;
            }

            return AppModalDialog(
              title: 'Catat Peminjaman',
              headerIcon: Icons.handshake,
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: borrowerCtrl,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Nama Peminjam',
                        prefixIcon: const Icon(Icons.person, color: Colors.black45),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final doc = items[index];
                          final id = doc['id'];
                          final isSelected = selectedItems[id] ?? false;
                          final maxStock = doc['stock'] ?? 0;
                          final baseFee = doc['fee'] ?? 0;
                          
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200)
                            ),
                            child: CheckboxListTile(
                              title: Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: isSelected 
                                ? Column(
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: qtyControllers[id],
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Jml (Max $maxStock)',
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onChanged: (val) {
                                                final qty = int.tryParse(val) ?? 0;
                                                if (qty > maxStock) {
                                                  qtyControllers[id]!.text = maxStock.toString();
                                                  qtyControllers[id]!.selection = TextSelection.fromPosition(TextPosition(offset: qtyControllers[id]!.text.length));
                                                }
                                                setModalState(() => updateFee(id, baseFee));
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: daysControllers[id],
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Berapa Hari',
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onChanged: (_) => setModalState(() => updateFee(id, baseFee)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: feeControllers[id],
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Total Biaya',
                                                filled: true,
                                                fillColor: Colors.grey.shade100,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              readOnly: true,
                                              onChanged: (_) => setModalState(() {}),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  )
                                : Text('Sisa Stok Tersedia: $maxStock | Sewa: ${currencyFormatter.format(baseFee)}/hari'),
                              value: isSelected,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (val) {
                                setModalState(() {
                                  selectedItems[id] = val ?? false;
                                  if (selectedItems[id] == true) {
                                    updateFee(id, baseFee);
                                  }
                                });
                              },
                            ),
                          );
                        }
                      )
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            currencyFormatter.format(getGrandTotal()),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: (borrowerCtrl.text.trim().isEmpty || !selectedItems.values.any((v) => v))
                                ? null
                                : () => Navigator.pop(context, true), 
                            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (res == true && borrowerCtrl.text.isNotEmpty) {
      bool hasSelected = selectedItems.values.any((v) => v);
      if (!hasSelected) {
        if (mounted) CustomToast.show(context, 'Pilih minimal 1 barang!');
        return;
      }

      for (var doc in items) {
        if (selectedItems[doc['id']] == true) {
          final qty = int.tryParse(qtyControllers[doc['id']]!.text) ?? 0;
          final currentStock = doc['stock'] ?? 0;
          
          if (qty > currentStock) {
            if (mounted) CustomToast.show(context, 'Jumlah ${doc['name']} melebihi stok tersedia ($currentStock)', isError: true);
            return;
          }
          if (qty <= 0) {
            if (mounted) CustomToast.show(context, 'Jumlah ${doc['name']} minimal 1!');
            return;
          }
        }
      }

      EasyLoading.show(status: 'Mencatat peminjaman...');
      try {
        for (var doc in items) {
          if (selectedItems[doc['id']] == true) {
            final qty = int.tryParse(qtyControllers[doc['id']]!.text) ?? 1;
            final currentStock = doc['stock'] ?? 0;
            
            if (qty > 0 && qty <= currentStock) {
              final feeTotal = int.tryParse(feeControllers[doc['id']]!.text) ?? 0;
              
              await ApiService.recordLoan({
                'id': 'loan_${DateTime.now().millisecondsSinceEpoch}_${doc['id']}',
                'villageId': widget.villageId,
                'itemId': doc['id'],
                'itemName': doc['name'],
                'borrowerName': borrowerCtrl.text,
                'quantity': qty,
                'days': int.tryParse(daysControllers[doc['id']]!.text) ?? 1,
                'feeTotal': feeTotal,
              });
            }
          }
        }
        _loadData();
      } catch (e) {
        EasyLoading.showError('Gagal mencatat');
      } finally {
        EasyLoading.dismiss();
      }
    }
  }
  
  Future<bool> _returnItem(Map<String, dynamic> loanDoc) async {
    final map = loanDoc;
    final defaultFee = (map['feeTotal'] as num?)?.toInt() ?? 0;
    final feeController = TextEditingController(text: defaultFee.toString());

    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AppModalDialog(
        title: 'Barang Dikembalikan?',
        headerIcon: Icons.assignment_return,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stok barang akan bertambah otomatis.', style: TextStyle(height: 1.5)),
            const SizedBox(height: 16),
            TextField(
              controller: feeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Total Uang Sewa (Bisa diubah/sukarela)',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final val = int.tryParse(feeController.text) ?? 0;
                      Navigator.pop(context, val);
                    },
                    child: const Text('Ya, Kembalikan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ),
      )
    );

    if (result != null) {
      EasyLoading.show(status: 'Memproses pengembalian...');
      try {
        final actualFee = result;
        await ApiService.returnLoan(map['id'], {'actualFee': actualFee, 'recordedBy': 'admin'});
        _loadData();
        if (mounted) CustomToast.show(context, 'Barang berhasil dikembalikan');
        return true;
      } catch (e) {
        EasyLoading.showError('Gagal memproses');
        return false;
      } finally {
        EasyLoading.dismiss();
      }
    }
    return false;
  }

  Future<bool> _cancelLoan(Map<String, dynamic> loanDoc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AppModalDialog(
        title: 'Batalkan Peminjaman?',
        headerIcon: Icons.cancel_outlined,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Peminjaman akan dibatalkan dan stok barang akan dikembalikan ke inventaris secara otomatis.', style: TextStyle(height: 1.5)),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Tidak', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ),
      )
    );

    if (confirm == true) {
      EasyLoading.show(status: 'Membatalkan...');
      try {
        await ApiService.cancelLoan(loanDoc['id']);
        _loadData();
        if (mounted) CustomToast.show(context, 'Peminjaman berhasil dibatalkan');
        return true;
      } catch (e) {
        EasyLoading.showError('Gagal membatalkan');
        return false;
      } finally {
        EasyLoading.dismiss();
      }
    }
    return false;
  }

  Future<void> _deleteItem(Map<String, dynamic> doc) async {
    if (!_canDelete) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AppModalDialog(
        title: 'Hapus Barang?',
        headerIcon: Icons.delete_outline,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Apakah Anda yakin ingin menghapus "${doc['name']}" secara permanen?', style: const TextStyle(height: 1.5)),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      )
    );

    if (confirm == true) {
      EasyLoading.show(status: 'Menghapus...');
      try {
        await ApiService.deleteInventoryItem(doc['id']);
        _loadData();
        if (mounted) CustomToast.show(context, 'Inventaris berhasil dihapus');
        if (mounted) CustomToast.show(context, 'Inventaris berhasil dihapus');
      } catch (e) {
        EasyLoading.showError('Gagal menghapus');
      } finally {
        EasyLoading.dismiss();
      }
    }
  }

  Future<void> _showManualJournalForm() async {
    if (!_canCreate) return;
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String jenisJurnal = 'Pemasukan';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AppModalDialog(
            title: 'Jurnal Manual',
            headerIcon: Icons.account_balance_wallet,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => jenisJurnal = 'Pemasukan'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: jenisJurnal == 'Pemasukan' ? Colors.green.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: jenisJurnal == 'Pemasukan' ? Colors.green : Colors.grey.shade300)
                          ),
                          alignment: Alignment.center,
                          child: Text('Pemasukan', style: TextStyle(fontWeight: FontWeight.bold, color: jenisJurnal == 'Pemasukan' ? Colors.green.shade800 : Colors.grey.shade600)),
                        )
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => jenisJurnal = 'Pengeluaran'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: jenisJurnal == 'Pengeluaran' ? Colors.red.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: jenisJurnal == 'Pengeluaran' ? Colors.red : Colors.grey.shade300)
                          ),
                          alignment: Alignment.center,
                          child: Text('Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold, color: jenisJurnal == 'Pengeluaran' ? Colors.red.shade800 : Colors.grey.shade600)),
                        )
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Keterangan',
                    hintText: jenisJurnal == 'Pemasukan' ? 'Cth: Uang tambahan sewa dari Bpk Budi' : 'Cth: Biaya perbaikan tenda rusak',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nominal (Rp)',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: jenisJurnal == 'Pemasukan' ? Colors.green : Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      int amount = int.tryParse(amountCtrl.text) ?? 0;
                      final desc = descCtrl.text.trim();
                      
                      if (amount <= 0 || desc.isEmpty) {
                        CustomToast.show(context, 'Keterangan dan Nominal tidak boleh kosong!');
                        return;
                      }
                      
                      if (jenisJurnal == 'Pengeluaran') {
                        amount = -amount;
                      }
                      
                      Navigator.pop(context);
                      
                      EasyLoading.show(status: 'Menyimpan Jurnal...');
                      try {
                        await ApiService.createDuesJournal({
                          'id': 'journal_${DateTime.now().millisecondsSinceEpoch}',
                          'villageId': widget.villageId,
                          'journalType': 'SEWA_INVENTARIS',
                          'amount': amount,
                          'type': jenisJurnal,
                          'description': desc,
                        });
                        _loadData();
                      } catch (e) {
                        EasyLoading.showError('Gagal menyimpan jurnal');
                      } finally {
                        EasyLoading.dismiss();
                      }
                    },
                    child: const Text('Simpan Jurnal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Future<void> _printPdf(String borrowerName, String dateStr, List<dynamic> docs) async {
    String villageName = 'PENGURUS RT';
    String villageAddress = 'Alamat tidak diketahui';
    try {
      final villageData = await ApiService.getVillage(widget.villageId);
      if (villageData != null) {
        villageName = villageData['name'] ?? 'PENGURUS RT';
        villageAddress = villageData['address'] ?? 'Alamat tidak diketahui';
      }
    } catch (e) {
      // ignore
    }

    final doc = pw.Document();
    
    int grandTotal = 0;
    int returnedCount = 0;
    for (var d in docs) {
      final map = d as Map<String, dynamic>;
      grandTotal += (map['feeTotal'] as num?)?.toInt() ?? 0;
      if (map['status'] == 'KEMBALI') returnedCount++;
    }

    String overallStatus = returnedCount == docs.length ? 'LUNAS & KEMBALI' : (returnedCount > 0 ? 'SEBAGIAN KEMBALI' : 'BELUM LUNAS');
    PdfColor statusColor = returnedCount == docs.length ? PdfColors.green700 : (returnedCount > 0 ? PdfColors.orange700 : PdfColors.red700);

    final tsStr = (docs.first as Map<String, dynamic>)['createdAt'];
    final ts = tsStr != null ? DateTime.tryParse(tsStr.toString()) : null;
    final noNota = 'INV-${ts?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              if (returnedCount == docs.length)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Text(
                      'LUNAS',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: const PdfColor(0.2, 0.8, 0.2, 0.15), // Light green transparent
                        fontSize: 120,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(villageName.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text(villageAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Dokumen Inventaris Resmi', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('NOTA PEMINJAMAN', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      pw.Text('No: $noNota', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Tanggal: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: statusColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(overallStatus, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      )
                    ],
                  )
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400, thickness: 1.5),
              pw.SizedBox(height: 15),

              // INFO PEMINJAM
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('Diberikan Kepada: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700, fontSize: 12)),
                    pw.Text(borrowerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                )
              ),
              pw.SizedBox(height: 20),

              // TABLE
              pw.TableHelper.fromTextArray(
                headers: ['No', 'Nama Barang', 'Jml', 'Hari', 'Status', 'Subtotal'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellHeight: 28,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                },
                data: List.generate(docs.length, (index) {
                  final map = docs[index] as Map<String, dynamic>;
                  final isReturned = map['status'] == 'KEMBALI';
                  return [
                    (index + 1).toString(),
                    (map['itemName'] ?? '').toString(),
                    (map['quantity'] ?? 0).toString(),
                    (map['days'] ?? 1).toString(),
                    isReturned ? 'KEMBALI' : 'DIPINJAM',
                    currencyFormatter.format(map['feeTotal'] ?? 0)
                  ];
                }),
              ),
              pw.SizedBox(height: 15),

              // TOTAL
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                         pw.Text('GRAND TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                         pw.Text(currencyFormatter.format(grandTotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900))
                      ]
                    )
                  )
                ]
              ),
              
              pw.Spacer(),

              // FOOTER / SIGNATURES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Peminjam', style: const pw.TextStyle(fontSize: 11)),
                      pw.SizedBox(height: 50),
                      pw.Text('( $borrowerName )', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Pengurus Inventaris', style: const pw.TextStyle(fontSize: 11)),
                      pw.SizedBox(height: 50),
                      pw.Text('( ......................................... )', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ]
                  ),
                ]
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Terima kasih telah meminjam inventaris RT. Harap dikembalikan tepat waktu sesuai durasi peminjaman.', 
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)
                )
              )
            ],
          ),
        ],
      );
    },
      ),
    );

    final cleanDate = dateStr.replaceAll(' ', '_').replaceAll(':', '-');
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Nota_Peminjaman_${borrowerName}_$cleanDate.pdf',
    );
  }

  Future<void> _showGroupDetailModal(String borrowerName, String dateStr, List<dynamic> docs) async {
    int grandTotal = 0;
    int returnedCount = 0;
    for (var d in docs) {
      final map = d as Map<String, dynamic>;
      grandTotal += (map['feeTotal'] as num?)?.toInt() ?? 0;
      if (map['status'] == 'KEMBALI') returnedCount++;
    }

    await showDialog(
      context: context,
      builder: (context) {
         return Dialog(
           backgroundColor: Colors.transparent,
           insetPadding: const EdgeInsets.all(20),
           child: Container(
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(24),
             ),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 // HEADER
                 Container(
                   padding: const EdgeInsets.all(20),
                   decoration: BoxDecoration(
                     color: AppTheme.primaryColor,
                     borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                   ),
                   child: Row(
                     children: [
                       const CircleAvatar(
                         backgroundColor: Colors.white24,
                         child: Icon(Icons.person, color: Colors.white),
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(borrowerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                             Text(dateStr, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                           ],
                         ),
                       ),
                       IconButton(
                         icon: const Icon(Icons.share, color: Colors.white),
                         onPressed: () => _printPdf(borrowerName, dateStr, docs),
                         tooltip: 'Bagikan / Cetak PDF',
                       ),
                       IconButton(
                         icon: const Icon(Icons.close, color: Colors.white),
                         onPressed: () => Navigator.pop(context),
                       ),
                     ],
                   ),
                 ),

                 // SUMMARY BANNER
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                   color: Colors.grey.shade50,
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text('Status Pengembalian', style: TextStyle(fontSize: 12, color: Colors.grey)),
                           Text('$returnedCount / ${docs.length} Barang', style: const TextStyle(fontWeight: FontWeight.bold)),
                         ],
                       ),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           const Text('Total Tagihan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                           Text(currencyFormatter.format(grandTotal), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 16)),
                         ],
                       ),
                     ],
                   ),
                 ),

                 // LIST
                 Flexible(
                   child: ListView.builder(
                     shrinkWrap: true,
                     padding: const EdgeInsets.all(20),
                     itemCount: docs.length,
                     itemBuilder: (context, index) {
                       final d = docs[index];
                       final map = d as Map<String, dynamic>;
                       final isReturned = map['status'] == 'KEMBALI';
                       return Container(
                         margin: const EdgeInsets.only(bottom: 12),
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           border: Border.all(color: isReturned ? Colors.green.shade200 : Colors.orange.shade200),
                           borderRadius: BorderRadius.circular(12),
                           color: isReturned ? Colors.green.shade50 : Colors.orange.shade50,
                         ),
                         child: Row(
                           children: [
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(map['itemName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                   const SizedBox(height: 4),
                                   Text('Jml: ${map['quantity'] ?? 0} x ${map['days'] ?? 1} Hari', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                   Text('Biaya: ${currencyFormatter.format(map['feeTotal'] ?? 0)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                 ],
                               ),
                             ),
                             if (isReturned || map['status'] == 'DIBATALKAN')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isReturned ? Colors.green.shade100 : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isReturned ? 'KEMBALI' : 'BATAL',
                                    style: TextStyle(
                                      color: isReturned ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else if (_canEdit)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      ),
                                      onPressed: () async {
                                        final success = await _cancelLoan(d);
                                        if (success && context.mounted) Navigator.pop(context);
                                      },
                                      child: const Text('Batal', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      ),
                                      onPressed: () async {
                                        final success = await _returnItem(d);
                                        if (success && context.mounted) Navigator.pop(context);
                                      },
                                      child: const Text('Kembali', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                )
                              else
                                const Text('DIPINJAM', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                           ],
                         ),
                       );
                     },
                   ),
                 ),
               ],
             ),
           ),
         );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Inventaris RT'),
          bottom: const TabBar(
            labelColor: Color(0xFF1E293B),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1E293B),
            isScrollable: true,
            tabs: [
              Tab(text: 'Daftar Barang'),
              Tab(text: 'Peminjaman'),
              Tab(text: 'Jurnal Sewa'),
            ],
          ),
          actions: [
            if (_canCreate)
              Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  return AnimatedBuilder(
                    animation: tabController,
                    builder: (context, child) {
                      if (tabController.index == 0) {
                        return IconButton(
                          icon: Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
                          onPressed: () => _showItemForm(),
                          tooltip: 'Tambah Barang',
                        );
                      } else if (tabController.index == 1) {
                        return IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                          onPressed: () => _recordLoan(),
                          tooltip: 'Tambah Peminjaman',
                        );
                      } else if (tabController.index == 2) {
                        return IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
                          onPressed: () => _showManualJournalForm(),
                          tooltip: 'Tambah Jurnal Manual',
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    },
                  );
                }
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: TabBarView(
          children: [
            // TAB 1: Daftar Barang
            FutureBuilder<List<dynamic>>(
              future: _inventoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) return const Center(child: Text('Belum ada barang di inventaris.'));
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index] as Map<String, dynamic>;
                    final name = doc['name'] ?? '';
                    final stock = doc['stock'] ?? 0;
                    final fee = doc['fee'] ?? 0;
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Icon(Icons.inventory_2, color: AppTheme.primaryColor),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('Sisa Stok: $stock\nBiaya Sewa: ${currencyFormatter.format(fee)}'),
                        trailing: (_canEdit || _canDelete) ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_canEdit)
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showItemForm(doc),
                                  ),
                                if (_canDelete)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteItem(doc),
                                  ),
                              ],
                            ) : null,
                      ),
                    );
                  },
                );
              },
            ),
            
            // TAB 2: Riwayat Peminjaman
            FutureBuilder<List<dynamic>>(
              future: _loansFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data?.toList() ?? [];
                
                // Sort locally by timestamp descending to avoid composite index requirement
                docs.sort((a, b) {
                  final mapA = a as Map<String, dynamic>;
                  final mapB = b as Map<String, dynamic>;
                  final taStr = mapA['createdAt'];
                  final tbStr = mapB['createdAt'];
                  final ta = taStr != null ? DateTime.tryParse(taStr.toString()) : null;
                  final tb = tbStr != null ? DateTime.tryParse(tbStr.toString()) : null;
                  if (ta == null && tb == null) return 0;
                  if (ta == null) return 1;
                  if (tb == null) return -1;
                  return tb.compareTo(ta);
                });

                if (docs.isEmpty) return const Center(child: Text('Belum ada riwayat peminjaman.'));
                
                Map<String, List<dynamic>> grouped = {};
                for (var doc in docs) {
                  final map = doc as Map<String, dynamic>;
                  final tsStr = map['createdAt'];
                  final ts = tsStr != null ? DateTime.tryParse(tsStr.toString()) : null;
                  final tsKey = ts != null ? '${ts.year}-${ts.month}-${ts.day} ${ts.hour}:${ts.minute}' : '0';
                  final name = map['borrowerName'] ?? 'Unknown';
                  final key = '${tsKey}_$name';
                  if (!grouped.containsKey(key)) {
                    grouped[key] = [];
                  }
                  grouped[key]!.add(doc);
                }
                
                final groupedKeys = grouped.keys.toList();
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedKeys.length,
                  itemBuilder: (context, index) {
                    final key = groupedKeys[index];
                    final groupDocs = grouped[key]!;
                    
                    final borrowerName = (groupDocs.first as Map<String, dynamic>)['borrowerName'] ?? 'Unknown';
                    final tsStr = (groupDocs.first as Map<String, dynamic>)['createdAt'];
                    final ts = tsStr != null ? DateTime.tryParse(tsStr.toString()) : null;
                    final dateStr = ts != null ? DateFormat('dd MMM yyyy HH:mm').format(ts.toLocal()) : '';
                    
                    int grandTotal = 0;
                    bool allReturned = true;
                    for (var d in groupDocs) {
                      final map = d as Map<String, dynamic>;
                      grandTotal += (map['feeTotal'] as num?)?.toInt() ?? 0;
                      if (map['status'] != 'KEMBALI') {
                         allReturned = false;
                      }
                    }
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: allReturned ? Colors.green.shade200 : Colors.orange.shade200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showGroupDetailModal(borrowerName, dateStr, groupDocs),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: allReturned ? Colors.green.shade100 : Colors.orange.shade100,
                                child: Icon(Icons.person, color: allReturned ? Colors.green.shade700 : Colors.orange.shade700),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      borrowerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${groupDocs.length} Item(s) - ${currencyFormatter.format(grandTotal)}'),
                                    Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                )
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // TAB 3: Jurnal Sewa
            FutureBuilder<List<dynamic>>(
              future: _journalsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final allDocs = snapshot.data?.toList() ?? [];
                final docs = allDocs.where((d) => (d as Map<String, dynamic>)['journalType'] == 'SEWA_INVENTARIS').toList();
                
                docs.sort((a, b) {
                  final mapA = a as Map<String, dynamic>;
                  final mapB = b as Map<String, dynamic>;
                  final taStr = mapA['createdAt'];
                  final tbStr = mapB['createdAt'];
                  final ta = taStr != null ? DateTime.tryParse(taStr.toString()) : null;
                  final tb = tbStr != null ? DateTime.tryParse(tbStr.toString()) : null;
                  if (ta == null && tb == null) return 0;
                  if (ta == null) return 1;
                  if (tb == null) return -1;
                  return tb.compareTo(ta);
                });

                if (docs.isEmpty) return const Center(child: Text('Belum ada jurnal sewa inventaris.'));
                
                int totalPemasukan = 0;
                int totalPengeluaran = 0;
                for (var doc in docs) {
                  final map = doc as Map<String, dynamic>;
                  final amount = map['amount'] ?? 0;
                  if (amount > 0) {
                    totalPemasukan += amount as int;
                  } else {
                    totalPengeluaran += (amount as int).abs();
                  }
                }
                final saldo = totalPemasukan - totalPengeluaran;
                
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pemasukan', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(currencyFormatter.format(totalPemasukan), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pengeluaran', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(currencyFormatter.format(totalPengeluaran), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Saldo Akhir', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormatter.format(saldo),
                                  style: TextStyle(color: saldo >= 0 ? AppTheme.primaryColor : Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                    final doc = docs[index];
                    final map = doc as Map<String, dynamic>;
                    final amount = map['amount'] ?? 0;
                    final desc = map['description'] ?? '';
                    final tsStr = map['createdAt'];
                    final ts = tsStr != null ? DateTime.tryParse(tsStr.toString()) : null;
                    final dateStr = ts != null ? DateFormat('dd MMM yyyy HH:mm').format(ts.toLocal()) : '';
                    
                    final isPemasukan = amount >= 0;
                    final absAmount = amount.abs();
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isPemasukan ? Colors.green.shade200 : Colors.red.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPemasukan ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(isPemasukan ? Icons.arrow_downward : Icons.arrow_upward, color: isPemasukan ? Colors.green.shade800 : Colors.red.shade800),
                        ),
                        title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: Text(
                          '${isPemasukan ? '+' : '-'} ${currencyFormatter.format(absAmount)}',
                          style: TextStyle(color: isPemasukan ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    );
                  }
                )
              )
            ],
          );
        }
      ),
          ],
        ),
      ),
    );
  }
}
