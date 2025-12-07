import 'package:flutter/material.dart';

import '../models/ban.dart';

class BanUserDialog extends StatefulWidget {
  const BanUserDialog({
    super.key,
    required this.targetUid,
    required this.reportId,
  });

  final String targetUid;
  final String reportId;

  @override
  State<BanUserDialog> createState() => _BanUserDialogState();
}

class _BanUserDialogState extends State<BanUserDialog> {
  BanLevel _selectedLevel = BanLevel.light;
  BanType _selectedType = BanType.temporary;
  int _days = 1;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime? _calculateExpiresAt() {
    if (_selectedType == BanType.permanent) return null;
    return DateTime.now().add(Duration(days: _days));
  }

  void _updateDaysFromLevel() {
    switch (_selectedLevel) {
      case BanLevel.warning:
        _days = 0; // Warning không khóa
        break;
      case BanLevel.light:
        _days = 3;
        break;
      case BanLevel.medium:
        _days = 7;
        break;
      case BanLevel.severe:
        _days = 0; // Severe = permanent
        _selectedType = BanType.permanent;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Khóa tài khoản'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mức độ vi phạm',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<BanLevel>(
              value: _selectedLevel,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: BanLevel.warning,
                  child: Text('Cảnh báo (không khóa)'),
                ),
                DropdownMenuItem(
                  value: BanLevel.light,
                  child: Text('Nhẹ (1-3 ngày)'),
                ),
                DropdownMenuItem(
                  value: BanLevel.medium,
                  child: Text('Trung bình (7-30 ngày)'),
                ),
                DropdownMenuItem(
                  value: BanLevel.severe,
                  child: Text('Nghiêm trọng (Vĩnh viễn)'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedLevel = value;
                    _updateDaysFromLevel();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_selectedLevel != BanLevel.warning &&
                _selectedLevel != BanLevel.severe) ...[
              const Text(
                'Loại ban',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<BanType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: BanType.temporary,
                    child: Text('Tạm thời'),
                  ),
                  DropdownMenuItem(
                    value: BanType.permanent,
                    child: Text('Vĩnh viễn'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_selectedType == BanType.temporary) ...[
                const Text(
                  'Số ngày khóa',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _days.toDouble(),
                        min: 1,
                        max: _selectedLevel == BanLevel.light ? 3 : 30,
                        divisions: _selectedLevel == BanLevel.light ? 2 : 29,
                        label: '$_days ngày',
                        onChanged: (value) {
                          setState(() {
                            _days = value.toInt();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(text: '$_days')
                          ..selection = TextSelection.collapsed(
                            offset: '$_days'.length,
                          ),
                        onChanged: (value) {
                          final days = int.tryParse(value);
                          if (days != null &&
                              days >= 1 &&
                              days <= (_selectedLevel == BanLevel.light ? 3 : 30)) {
                            setState(() {
                              _days = days;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            const Text(
              'Lý do khóa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Nhập lý do khóa tài khoản...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _reasonController.text.trim().isEmpty
              ? null
              : () {
                  if (_selectedLevel == BanLevel.warning) {
                    Navigator.of(context).pop();
                    return;
                  }

                  Navigator.of(context).pop({
                    'uid': widget.targetUid,
                    'banType': _selectedType,
                    'banLevel': _selectedLevel,
                    'reason': _reasonController.text.trim(),
                    'expiresAt': _calculateExpiresAt(),
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Khóa'),
        ),
      ],
    );
  }
}

