import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';

/// صفحه‌ی مدیریت سابسکریپشن‌ها: افزودن لینک سابسکریپشن جدید، آپدیت دستی
/// هرکدوم (که سرورهای اون گروه رو جایگزین می‌کنه)، و حذف.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({
    super.key,
    required this.onServersUpdated,
  });

  /// وقتی سابسکریپشنی آپدیت میشه، لیست جدید سرورهای اون گروه به این
  /// callback داده میشه تا صفحه‌ی اصلی merge‌شون کنه و ذخیره کنه.
  final Future<void> Function(String groupTag, List<String> rawLinks) onServersUpdated;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _storage = StorageService();
  final _service = SubscriptionService();
  final _uuid = const Uuid();

  List<Subscription> _subs = [];
  bool _loading = true;
  final Set<String> _updatingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs = await _storage.loadSubscriptions();
    setState(() {
      _subs = subs;
      _loading = false;
    });
  }

  Future<void> _addSubscription() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افزودن سابسکریپشن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم دلخواه (مثلاً: پلن اصلی)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'آدرس لینک سابسکریپشن'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('افزودن')),
        ],
      ),
    );

    if (result != true || urlController.text.trim().isEmpty) return;

    final sub = Subscription(
      id: _uuid.v4(),
      remark: nameController.text.trim().isEmpty ? 'سابسکریپشن بدون‌نام' : nameController.text.trim(),
      url: urlController.text.trim(),
    );
    setState(() => _subs.add(sub));
    await _storage.saveSubscriptions(_subs);
    await _refresh(sub);
  }

  Future<void> _refresh(Subscription sub) async {
    setState(() => _updatingIds.add(sub.id));
    try {
      final links = await _service.fetchConfigs(sub.url);
      if (links.isEmpty) {
        throw Exception('هیچ کانفیگی توی این سابسکریپشن پیدا نشد.');
      }
      await widget.onServersUpdated(sub.remark, links);
      sub.lastUpdated = DateTime.now();
      await _storage.saveSubscriptions(_subs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${links.length} سرور از «${sub.remark}» به‌روزرسانی شد.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('به‌روزرسانی «${sub.remark}» ناموفق بود.\n$e')),
      );
    } finally {
      if (mounted) setState(() => _updatingIds.remove(sub.id));
    }
  }

  Future<void> _delete(Subscription sub) async {
    setState(() => _subs.removeWhere((s) => s.id == sub.id));
    await _storage.saveSubscriptions(_subs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سابسکریپشن‌ها')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subs.isEmpty
              ? const Center(child: Text('هنوز سابسکریپشنی اضافه نکردی'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _subs.length,
                  itemBuilder: (ctx, i) {
                    final sub = _subs[i];
                    final isUpdating = _updatingIds.contains(sub.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: ListTile(
                        title: Text(sub.remark, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          sub.lastUpdated != null
                              ? 'آخرین به‌روزرسانی: ${sub.lastUpdated}'
                              : 'هنوز به‌روزرسانی نشده',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isUpdating
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'به‌روزرسانی',
                                    onPressed: () => _refresh(sub),
                                  ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'حذف',
                              onPressed: () => _delete(sub),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubscription,
        icon: const Icon(Icons.add_link),
        label: const Text('افزودن سابسکریپشن'),
      ),
    );
  }
}