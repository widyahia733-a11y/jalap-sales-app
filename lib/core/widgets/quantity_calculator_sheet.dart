import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/al_rabie_catalog.dart';
import '../constants/app_constants.dart';

/// حقل اختياري ومرن لتحديد أو كتابة اسم العميل / التاجر يدوياً أو اختياره من القائمة دون أي تقييد إجباري
class FlexibleCustomerField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestedCustomers;
  final String labelText;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const FlexibleCustomerField({
    super.key,
    required this.controller,
    required this.suggestedCustomers,
    this.labelText = 'العميل / التاجر (اختياري)',
    this.hintText = 'اكتب اسم العميل يدوياً أو اختر من القائمة (اختياري)...',
    this.onChanged,
  });

  Future<void> _openSuggestionsSheet(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.softRoyalGold,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.royalGold),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppConstants.deepNavyBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اختيار سريع من قائمة العملاء المسجلين',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppConstants.deepNavyBlue,
                            ),
                          ),
                          Text(
                            'أو يمكنك إغلاق القائمة وكتابة أي اسم عميل يدوياً أو تركه فارغاً',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(''),
                      child: const Text('بدون تحديد'),
                    ),
                  ],
                ),
                const Divider(height: 18),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: suggestedCustomers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final cust = suggestedCustomers[idx];
                      final isCurrent = controller.text.trim() == cust;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor:
                            isCurrent ? AppConstants.softRoyalGold : null,
                        leading: Icon(
                          isCurrent
                              ? Icons.check_circle_rounded
                              : Icons.handshake_outlined,
                          color: AppConstants.deepNavyBlue,
                          size: 20,
                        ),
                        title: Text(
                          cust,
                          style: TextStyle(
                            fontWeight:
                                isCurrent ? FontWeight.w900 : FontWeight.w600,
                            fontSize: 13.5,
                            color: AppConstants.deepNavyBlue,
                          ),
                        ),
                        onTap: () => Navigator.of(sheetCtx).pop(cust),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      controller.text = selected;
      onChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: AppConstants.deepNavyBlue,
          ),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: const Icon(
              Icons.person_pin_circle_rounded,
              color: AppConstants.deepNavyBlue,
              size: 20,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasText)
                  IconButton(
                    tooltip: 'مسح اسم العميل',
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                    icon: const Icon(Icons.clear_rounded, size: 18),
                  ),
                IconButton(
                  tooltip: 'اختيار من قائمة العملاء المقترحة',
                  onPressed: () => _openSuggestionsSheet(context),
                  icon: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.softRoyalGold,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.royalGold),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.list_alt_rounded,
                          size: 15,
                          color: AppConstants.deepNavyBlue,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'القائمة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppConstants.deepNavyBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            filled: true,
            fillColor: AppConstants.cleanLightGrey,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppConstants.deepNavyBlue,
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// زر كمية تفاعلي يفتح الحاسبة الرقمية الفورية عند اللمس لإدخال الكميات الكبيرة بسرعة فائقة
class InteractiveQuantityCalculatorBox extends StatelessWidget {
  final String label;
  final int value;
  final String productName;
  final String productCode;
  final String? imageAsset;
  final String? category;
  final Color primaryColor;
  final ValueChanged<int> onQuantitySaved;

  const InteractiveQuantityCalculatorBox({
    super.key,
    required this.label,
    required this.value,
    required this.productName,
    required this.productCode,
    this.imageAsset,
    this.category,
    this.primaryColor = AppConstants.deepNavyBlue,
    required this.onQuantitySaved,
  });

  Future<void> _handleTap(BuildContext context) async {
    final result = await showQuantityCalculatorSheet(
      context: context,
      initialValue: value,
      unitLabel: label,
      productName: productName,
      productCode: productCode,
      imageAsset: imageAsset,
      category: category,
    );
    if (result != null) {
      onQuantitySaved(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value > 0;

    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasValue
              ? AppConstants.softRoyalGold
              : AppConstants.cleanLightGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue ? AppConstants.royalGold : Colors.grey.shade300,
            width: hasValue ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: hasValue ? AppConstants.deepNavyBlue : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasValue
                      ? AppConstants.royalGold
                      : Colors.grey.shade300,
                ),
              ),
              child: Icon(
                Icons.dialpad_rounded,
                size: 16,
                color: hasValue ? AppConstants.royalGold : primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: hasValue
                          ? AppConstants.deepNavyBlue
                          : Colors.black54,
                    ),
                  ),
                  Text(
                    hasValue ? '$value' : 'اضغط للإدخال',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: hasValue ? 16 : 12,
                      color: hasValue ? primaryColor : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (hasValue)
              InkWell(
                onTap: () => onQuantitySaved(0),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                ),
              )
            else
              Icon(
                Icons.edit_rounded,
                size: 15,
                color: primaryColor.withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }
}

/// نافذة الحاسبة الرقمية الفورية لإدخال الكميات الكبيرة (مثل 1000 أو 2500 كرتون) بلمسة واحدة
Future<int?> showQuantityCalculatorSheet({
  required BuildContext context,
  required int initialValue,
  required String unitLabel,
  required String productName,
  required String productCode,
  String? imageAsset,
  String? category,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return _QuantityCalculatorDialogBody(
        initialValue: initialValue,
        unitLabel: unitLabel,
        productName: productName,
        productCode: productCode,
        imageAsset: imageAsset,
        category: category,
      );
    },
  );
}

class _QuantityCalculatorDialogBody extends StatefulWidget {
  final int initialValue;
  final String unitLabel;
  final String productName;
  final String productCode;
  final String? imageAsset;
  final String? category;

  const _QuantityCalculatorDialogBody({
    required this.initialValue,
    required this.unitLabel,
    required this.productName,
    required this.productCode,
    this.imageAsset,
    this.category,
  });

  @override
  State<_QuantityCalculatorDialogBody> createState() =>
      _QuantityCalculatorDialogBodyState();
}

class _QuantityCalculatorDialogBodyState
    extends State<_QuantityCalculatorDialogBody> {
  late String _inputBuffer;
  bool _replaceOnNextDigit = true;

  @override
  void initState() {
    super.initState();
    _inputBuffer = widget.initialValue > 0 ? '${widget.initialValue}' : '0';
    _replaceOnNextDigit = true;
  }

  int get _currentNumericValue =>
      (int.tryParse(_inputBuffer) ?? 0).clamp(0, 999999);

  void _appendDigits(String digits) {
    setState(() {
      if (_replaceOnNextDigit || _inputBuffer == '0') {
        if (digits == '0' || digits == '00' || digits == '000') {
          _inputBuffer = '0';
        } else {
          _inputBuffer = digits;
        }
        _replaceOnNextDigit = false;
      } else {
        final candidate = '$_inputBuffer$digits';
        if (candidate.length <= 6) {
          _inputBuffer = candidate;
        }
      }
    });
  }

  void _addPreset(int delta) {
    setState(() {
      final base = _replaceOnNextDigit ? 0 : _currentNumericValue;
      final next = (base + delta).clamp(0, 999999);
      _inputBuffer = '$next';
      _replaceOnNextDigit = false;
    });
  }

  void _backspace() {
    setState(() {
      _replaceOnNextDigit = false;
      if (_inputBuffer.length <= 1) {
        _inputBuffer = '0';
      } else {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      }
    });
  }

  void _clear() {
    setState(() {
      _inputBuffer = '0';
      _replaceOnNextDigit = false;
    });
  }

  void _submit() {
    Navigator.of(context).pop(_currentNumericValue);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          right: 18,
          left: 18,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // معلومات الصنف المختار
              Row(
                children: [
                  if (widget.imageAsset != null &&
                      widget.imageAsset!.isNotEmpty) ...[
                    AlRabieProductThumbnail(
                      imageAsset: widget.imageAsset!,
                      category: widget.category ?? '',
                      size: 48,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.deepNavyBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.productCode,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.royalGold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'إدخال ${widget.unitLabel}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: AppConstants.deepNavyBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // شاشة عرض الرقم الكبيرة والواضحة
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppConstants.deepNavyBlue,
                      AppConstants.royalNavySecondary,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppConstants.royalGold,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.unitLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'اكتب الكمية مباشرة من لوحة الأرقام',
                          style: TextStyle(
                            color: AppConstants.royalGold,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Text(
                        _inputBuffer,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // أزرار الإضافة السريعة للكميات الكبيرة (+10 / +50 / +100 / +500 / +1000)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final preset in [10, 50, 100, 500, 1000, 2500])
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ActionChip(
                          backgroundColor: AppConstants.softRoyalGold,
                          side: const BorderSide(color: AppConstants.royalGold),
                          label: Text(
                            '+$preset',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              color: AppConstants.deepNavyBlue,
                            ),
                          ),
                          onPressed: () => _addPreset(preset),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // لوحة الحاسبة الرقمية التفاعلية
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _CalcKeyButton(
                          label: '7',
                          onTap: () => _appendDigits('7'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '8',
                          onTap: () => _appendDigits('8'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '9',
                          onTap: () => _appendDigits('9'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '⌫',
                          isAction: true,
                          color: Colors.orange.shade800,
                          onTap: _backspace,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CalcKeyButton(
                          label: '4',
                          onTap: () => _appendDigits('4'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '5',
                          onTap: () => _appendDigits('5'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '6',
                          onTap: () => _appendDigits('6'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: 'C',
                          isAction: true,
                          color: Colors.red.shade700,
                          onTap: _clear,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CalcKeyButton(
                          label: '1',
                          onTap: () => _appendDigits('1'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '2',
                          onTap: () => _appendDigits('2'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '3',
                          onTap: () => _appendDigits('3'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '00',
                          isAction: true,
                          color: AppConstants.royalNavySecondary,
                          onTap: () => _appendDigits('00'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CalcKeyButton(
                          label: '0',
                          flex: 2,
                          onTap: () => _appendDigits('0'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '000',
                          isAction: true,
                          color: AppConstants.royalNavySecondary,
                          onTap: () => _appendDigits('000'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppConstants.royalGold,
                                foregroundColor: AppConstants.deepNavyBlue,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // زر الاعتماد النهائي للكمية
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppConstants.deepNavyBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    color: AppConstants.royalGold,
                  ),
                  label: Text(
                    'اعتماد الكمية ($_currentNumericValue ${widget.unitLabel})',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalcKeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAction;
  final Color? color;
  final int flex;

  const _CalcKeyButton({
    required this.label,
    required this.onTap,
    this.isAction = false,
    this.color,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Material(
        color: isAction
            ? (color ?? AppConstants.deepNavyBlue)
            : AppConstants.cleanLightGrey,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isAction ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isAction ? Colors.white : AppConstants.deepNavyBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
