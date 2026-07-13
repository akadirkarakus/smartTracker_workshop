import 'package:flutter/material.dart';
import '../../kline/parameter_validation.dart';
import '../../models/calibration_data.dart';

class EditParameterScreen extends StatefulWidget {
  final CalParam parameter;
  final Future<bool> Function(String newValue)? onWrite;

  const EditParameterScreen({
    super.key,
    required this.parameter,
    this.onWrite,
  });

  @override
  State<EditParameterScreen> createState() => _EditParameterScreenState();
}

class _EditParameterScreenState extends State<EditParameterScreen> {
  late String _inputValue;
  late String _selectedOption;
  late bool _toggleValue;
  bool _isSaving = false;
  String? _validationError;

  // Date-specific state (only used when type == ParamType.date)
  String _dateDay = '';
  String _dateMonth = '';
  String _dateYear = '';
  int _dateFocusField = 0; // 0=day, 1=month, 2=year

  // dateTime-specific state (only used when type == ParamType.dateTime)
  DateTime? _syncedNow;

  bool get _isDate => widget.parameter.type == ParamType.date;

  @override
  void initState() {
    super.initState();
    _inputValue = widget.parameter.value ?? '';
    _selectedOption = widget.parameter.value ??
        (widget.parameter.options?.isNotEmpty == true
            ? widget.parameter.options!.first
            : '');
    _toggleValue = widget.parameter.value == 'ENABLED';

    if (_isDate) {
      final existing = widget.parameter.value;
      // Stored as YYYY-MM-DD
      if (existing != null && existing.length == 10) {
        final parts = existing.split('-');
        if (parts.length == 3) {
          _dateYear = parts[0];
          _dateMonth = parts[1];
          _dateDay = parts[2];
        } else {
          _dateDay = _dateMonth = _dateYear = '';
        }
      } else {
        _dateDay = _dateMonth = _dateYear = '';
      }
      _dateFocusField = 0;
    }
  }

  bool get _isNumericType => widget.parameter.type == ParamType.number;

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String get _currentDisplay {
    if (widget.parameter.type == ParamType.toggleBool) {
      return _toggleValue ? 'ENABLED' : 'DISABLED';
    }
    if (widget.parameter.type == ParamType.selectOption) return _selectedOption;
    if (_isDate) {
      final d = _dateDay.isEmpty ? '--' : _dateDay.padLeft(2, '0');
      final m = _dateMonth.isEmpty ? '--' : _dateMonth.padLeft(2, '0');
      final y = _dateYear.isEmpty ? '----' : _dateYear.padLeft(4, '0');
      return '$d/$m/$y';
    }
    if (widget.parameter.type == ParamType.dateTime) {
      final existing = widget.parameter.value;
      if (existing == null) return '—';
      final dt = DateTime.tryParse(existing);
      return dt != null ? _formatDateTime(dt) : existing;
    }
    return _inputValue;
  }

  String get _dateAsIso {
    final y = _dateYear.padLeft(4, '0');
    final m = _dateMonth.padLeft(2, '0');
    final d = _dateDay.padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _appendChar(String ch) {
    setState(() {
      _validationError = null;
      if (widget.parameter.maxLen != null &&
          _inputValue.length >= widget.parameter.maxLen!) {
        return;
      }
      _inputValue += ch;
    });
  }

  void _backspace() {
    if (_inputValue.isEmpty) return;
    setState(() {
      _validationError = null;
      _inputValue = _inputValue.substring(0, _inputValue.length - 1);
    });
  }

  void _onDateDigit(String digit) {
    setState(() {
      _validationError = null;
      switch (_dateFocusField) {
        case 0:
          if (_dateDay.length < 2) {
            _dateDay += digit;
            if (_dateDay.length == 2) _dateFocusField = 1;
          }
        case 1:
          if (_dateMonth.length < 2) {
            _dateMonth += digit;
            if (_dateMonth.length == 2) _dateFocusField = 2;
          }
        case 2:
          if (_dateYear.length < 4) _dateYear += digit;
      }
    });
  }

  void _onDateBackspace() {
    setState(() {
      _validationError = null;
      switch (_dateFocusField) {
        case 0:
          if (_dateDay.isNotEmpty) {
            _dateDay = _dateDay.substring(0, _dateDay.length - 1);
          }
        case 1:
          if (_dateMonth.isNotEmpty) {
            _dateMonth = _dateMonth.substring(0, _dateMonth.length - 1);
          } else {
            _dateFocusField = 0;
            if (_dateDay.isNotEmpty) {
              _dateDay = _dateDay.substring(0, _dateDay.length - 1);
            }
          }
        case 2:
          if (_dateYear.isNotEmpty) {
            _dateYear = _dateYear.substring(0, _dateYear.length - 1);
          } else {
            _dateFocusField = 1;
            if (_dateMonth.isNotEmpty) {
              _dateMonth = _dateMonth.substring(0, _dateMonth.length - 1);
            }
          }
      }
    });
  }

  void _setDateFocus(int field) => setState(() => _dateFocusField = field);

  String? _validateDate() {
    if (_dateDay.isEmpty || _dateMonth.isEmpty || _dateYear.isEmpty) {
      return 'Lütfen tüm alanları doldurun.';
    }
    final day = int.tryParse(_dateDay);
    final month = int.tryParse(_dateMonth);
    final year = int.tryParse(_dateYear);
    if (day == null || month == null || year == null) {
      return 'Geçersiz tarih formatı.';
    }
    if (day < 1 || day > 31) return 'Gün 1-31 arasında olmalıdır.';
    if (month < 1 || month > 12) return 'Ay 1-12 arasında olmalıdır.';
    if (year < 2000 || year > 2099) return 'Yıl 2000-2099 arasında olmalıdır.';
    // Calendar validity (e.g. 31/02 is invalid)
    final parsed = DateTime(year, month, day);
    if (parsed.day != day || parsed.month != month || parsed.year != year) {
      return 'Geçersiz tarih.';
    }
    return null;
  }

  Future<void> _confirmWrite() async {
    if (_isDate) {
      final error = _validateDate();
      if (error != null) {
        setState(() => _validationError = error);
        return;
      }
    }
    if (widget.parameter.type == ParamType.dateTime && _syncedNow == null) {
      setState(() => _validationError = 'Lütfen önce zamanı senkronize edin.');
      return;
    }

    setState(() => _isSaving = true);
    bool success = true;
    final valueToWrite = _isDate
        ? _dateAsIso
        : widget.parameter.type == ParamType.dateTime
            ? _syncedNow!.toIso8601String()
            : _currentDisplay;
    if (widget.onWrite != null) {
      try {
        success = await widget.onWrite!(valueToWrite);
      } on ParamValidationException catch (e) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _validationError = e.message;
        });
        return;
      } catch (_) {
        success = false;
      }
    }
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yazma işlemi başarısız. Bağlantıyı kontrol edin.'),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CalColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Parametre Düzenle',
          style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: CalColors.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ParamInfoCard(
                      parameter: widget.parameter,
                      currentDisplay: _currentDisplay,
                    ),
                    const SizedBox(height: 16),
                    if (_isDate)
                      _DateInput(
                        day: _dateDay,
                        month: _dateMonth,
                        year: _dateYear,
                        focusedField: _dateFocusField,
                        onDigit: _onDateDigit,
                        onBackspace: _onDateBackspace,
                        onFocusField: _setDateFocus,
                        validationError: _validationError,
                      )
                    else if (widget.parameter.type == ParamType.toggleBool)
                      _ToggleInput(
                        value: _toggleValue,
                        onChange: (v) => setState(() => _toggleValue = v),
                      )
                    else if (widget.parameter.type == ParamType.selectOption)
                      _SelectInput(
                        options: widget.parameter.options ?? [],
                        selected: _selectedOption,
                        onSelect: (v) => setState(() => _selectedOption = v),
                      )
                    else if (widget.parameter.type == ParamType.dateTime)
                      _SyncNowInput(
                        syncedValue: _syncedNow,
                        onSyncNow: () => setState(() {
                          _validationError = null;
                          _syncedNow = DateTime.now();
                        }),
                      )
                    else
                      _TextNumberInput(
                        value: _inputValue,
                        unit: widget.parameter.unit,
                        isNumeric: _isNumericType,
                        onAppend: _appendChar,
                        onBackspace: _backspace,
                        validationError: _validationError,
                      ),
                    const SizedBox(height: 16),
                    _TechNote(paramType: widget.parameter.type),
                  ],
                ),
              ),
            ),
            _ActionBar(
              isSaving: _isSaving,
              onConfirm: _confirmWrite,
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────

class _ParamInfoCard extends StatelessWidget {
  final CalParam parameter;
  final String currentDisplay;

  const _ParamInfoCard({required this.parameter, required this.currentDisplay});

  String get _sectionTag {
    switch (parameter.section) {
      case CalSection.vehicle: return 'AKİM-01';
      case CalSection.tyre:    return 'LAS-02';
      case CalSection.time:    return 'ZMN-03';
      case CalSection.system:  return 'SİS-04';
    }
  }

  String get _labelWithFormat {
    if (parameter.type == ParamType.date) return '${parameter.label}  g/a/y';
    return parameter.label;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Parametre',
                style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant, fontWeight: FontWeight.w500, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: CalColors.tertiaryFixed, borderRadius: BorderRadius.circular(4)),
                child: Text(_sectionTag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CalColors.tertiary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _labelWithFormat,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CalColors.primary),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CalColors.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CalColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mevcut Değer', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      currentDisplay,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: CalColors.onSurface,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (parameter.unit.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(parameter.unit, style: const TextStyle(fontSize: 14, color: CalColors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date Input ─────────────────────────────────

class _DateInput extends StatelessWidget {
  final String day;
  final String month;
  final String year;
  final int focusedField;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final void Function(int field) onFocusField;
  final String? validationError;

  const _DateInput({
    required this.day,
    required this.month,
    required this.year,
    required this.focusedField,
    required this.onDigit,
    required this.onBackspace,
    required this.onFocusField,
    this.validationError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Three-box display
        Row(
          children: [
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => onFocusField(0),
                child: _DateBox(
                  label: 'Gün',
                  value: day.isEmpty ? '--' : day.padLeft(2, '0'),
                  isFocused: focusedField == 0,
                  hasError: validationError != null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(' / ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: CalColors.outline)),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => onFocusField(1),
                child: _DateBox(
                  label: 'Ay',
                  value: month.isEmpty ? '--' : month.padLeft(2, '0'),
                  isFocused: focusedField == 1,
                  hasError: validationError != null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(' / ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: CalColors.outline)),
            ),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => onFocusField(2),
                child: _DateBox(
                  label: 'Yıl',
                  value: year.isEmpty ? '----' : year.padLeft(4, '0'),
                  isFocused: focusedField == 2,
                  hasError: validationError != null,
                ),
              ),
            ),
          ],
        ),
        if (validationError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: CalColors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  validationError!,
                  style: const TextStyle(fontSize: 12, color: CalColors.error, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _DateKeypad(onDigit: onDigit, onBackspace: onBackspace),
      ],
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isFocused;
  final bool hasError;

  const _DateBox({
    required this.label,
    required this.value,
    required this.isFocused,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? CalColors.error
        : isFocused
            ? CalColors.primary
            : CalColors.outlineVariant;
    final borderWidth = isFocused ? 2.0 : 1.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: isFocused ? CalColors.primaryContainer.withValues(alpha: 0.15) : CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isFocused ? CalColors.primary : CalColors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: value.contains('-') ? CalColors.outline : (isFocused ? CalColors.primary : CalColors.onSurface),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateKeypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _DateKeypad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: keys.map((k) {
        if (k == '⌫') {
          return _KeyBtn(label: k, onTap: onBackspace, isDestructive: true);
        }
        if (k.isEmpty) return const SizedBox.shrink();
        return _KeyBtn(label: k, onTap: () => onDigit(k));
      }).toList(),
    );
  }
}

// ── Other Inputs ────────────────────────────────

class _ToggleInput extends StatelessWidget {
  final bool value;
  final void Function(bool) onChange;

  const _ToggleInput({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Durum', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(
                value ? 'ENABLED' : 'DISABLED',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: value ? CalColors.accent : CalColors.outline),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChange,
            activeThumbColor: CalColors.accent,
            activeTrackColor: CalColors.accent.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _SyncNowInput extends StatelessWidget {
  final DateTime? syncedValue;
  final VoidCallback onSyncNow;

  const _SyncNowInput({required this.syncedValue, required this.onSyncNow});

  String _format(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onSyncNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: CalColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.sync, size: 20),
              label: const Text('Şimdi Senkronize Et', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          if (syncedValue != null) ...[
            const SizedBox(height: 12),
            Text(
              'Gönderilecek: ${_format(syncedValue!)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalColors.onSurface),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectInput extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelect;

  const _SelectInput({required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return InkWell(
            onTap: () => onSelect(opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? CalColors.surfaceLow : Colors.transparent,
                border: Border(bottom: BorderSide(color: CalColors.outlineVariant, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(opt, style: TextStyle(fontSize: 15, color: isSelected ? CalColors.primary : CalColors.onSurface, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                  if (isSelected) const Icon(Icons.check, color: CalColors.primary, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TextNumberInput extends StatelessWidget {
  final String value;
  final String unit;
  final bool isNumeric;
  final void Function(String) onAppend;
  final VoidCallback onBackspace;
  final String? validationError;

  const _TextNumberInput({
    required this.value,
    required this.unit,
    required this.isNumeric,
    required this.onAppend,
    required this.onBackspace,
    this.validationError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: CalColors.surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: validationError != null ? CalColors.error : CalColors.primary,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? '–' : value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: value.isEmpty ? CalColors.outline : CalColors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Text(unit, style: const TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant)),
            ],
          ),
        ),
        if (validationError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: CalColors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  validationError!,
                  style: const TextStyle(fontSize: 12, color: CalColors.error, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (isNumeric)
          _NumericKeypad(onAppend: onAppend, onBackspace: onBackspace)
        else
          _TextKeypad(onAppend: onAppend, onBackspace: onBackspace),
      ],
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  final void Function(String) onAppend;
  final VoidCallback onBackspace;

  const _NumericKeypad({required this.onAppend, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: keys.map((k) {
        if (k == '⌫') return _KeyBtn(label: k, onTap: onBackspace, isDestructive: true);
        return _KeyBtn(label: k, onTap: () => onAppend(k));
      }).toList(),
    );
  }
}

class _TextKeypad extends StatelessWidget {
  final void Function(String) onAppend;
  final VoidCallback onBackspace;

  const _TextKeypad({required this.onAppend, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'İ', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ];
    return Column(
      children: [
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: row.map((k) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => onAppend(k),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: CalColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CalColors.outlineVariant),
                        ),
                        alignment: Alignment.center,
                        child: Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CalColors.onSurface)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () => onAppend(' '),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: CalColors.surfaceLow, borderRadius: BorderRadius.circular(8), border: Border.all(color: CalColors.outlineVariant)),
                  alignment: Alignment.center,
                  child: const Text('Boşluk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: InkWell(
                onTap: onBackspace,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: CalColors.surfaceLow, borderRadius: BorderRadius.circular(8), border: Border.all(color: CalColors.outlineVariant)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.backspace_outlined, color: CalColors.primary, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _KeyBtn({required this.label, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDestructive ? CalColors.errorContainer : CalColors.surfaceLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDestructive ? CalColors.error.withValues(alpha: 0.4) : CalColors.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: label == '⌫' ? 18 : 22,
              fontWeight: FontWeight.w600,
              color: isDestructive ? CalColors.onErrorContainer : CalColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TechNote extends StatelessWidget {
  final ParamType paramType;

  const _TechNote({required this.paramType});

  String get _note {
    if (paramType == ParamType.dateTime) {
      return 'Zaman farkı 20 dakikadan fazlaysa tam yeniden kalibrasyon tetiklenir; aksi hâlde yalnızca saat ayarlanır.';
    }
    return 'Bu değer yazılırsa takografın dahili flash belleğine kaydedilir. Araç durmalı ve takograf atölye modunda olmalıdır.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CalColors.surfaceLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: CalColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(_note, style: const TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant, height: 1.4))),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ActionBar({required this.isSaving, required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: CalColors.surfaceLowest,
        border: Border(top: BorderSide(color: CalColors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: CalColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 20),
              label: Text(isSaving ? 'Yazılıyor...' : 'Onayla & Yaz', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: CalColors.outlineVariant, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('İptal', style: TextStyle(fontSize: 15, color: CalColors.onSurfaceVariant)),
            ),
          ),
        ],
      ),
    );
  }
}
