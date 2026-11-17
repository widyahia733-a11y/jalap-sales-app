import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/al_rabie_catalog.dart';
import '../constants/app_constants.dart';

/// حقل إدخال حر واختياري لاسم العميل / التاجر (يبدأ فارغاً تماماً بدون أي عملاء وهميين مسبقين)
class FlexibleCustomerField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestedCustomers;
  final String labelText;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const FlexibleCustomerField({
    super.key,
    required this.controller,
    this.suggestedCustomers = const <String>[],
    this.labelText = 'اسم العميل / التاجر (إدخال حر - اختياري)',
    this.hintText = 'اكتب اسم العميل أو نقطة البيع يدوياً هنا...',
    this.onChanged,
  });

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
              Icons.edit_location_alt_rounded,
              color: AppConstants.deepNavyBlue,
              size: 20,
            ),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: 'مسح اسم العميل',
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                    icon: const Icon(Icons.clear_rounded, size: 18),
                  )
                : null,
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

/// زر كمية تفاعلي يفتح الحاسبة الرقمية المتقدمة (+, -, ×) عند اللمس لإدخال الكميات الكبيرة بسرعة فائقة
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
                Icons.calculate_rounded,
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
                    hasValue ? '$value' : 'اضغط للحاسبة',
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
                Icons.dialpad_rounded,
                size: 15,
                color: primaryColor.withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }
}

/// نافذة الحاسبة الرقمية المتقدمة المزودة بالعمليات الحسابية (+, -, ×, =) وإدخال الكميات الكبيرة
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
  /// التعبير الحسابي الكامل مثل "25 × 40" أو "500 + 250" أو "1000"
  late String _expression;
  bool _replaceOnNextDigit = true;

  @override
  void initState() {
    super.initState();
    _expression = widget.initialValue > 0 ? '${widget.initialValue}' : '0';
    _replaceOnNextDigit = true;
  }

  bool _isOperator(String ch) => ch == '+' || ch == '-' || ch == '×';

  /// تقييم التعبير الحسابي (+, -, ×) مع مراعاة أولوية الضرب (×) على الجمع والطرح
  int _evaluateExpression(String expr) {
    final cleaned = expr.replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return 0;

    // استخراج الأرقام والعمليات بالترتيب
    final List<int> numbers = <int>[];
    final List<String> ops = <String>[];

    String currentNum = '';
    for (int i = 0; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (_isOperator(ch)) {
        if (currentNum.isEmpty) {
          numbers.add(0);
        } else {
          numbers.add(int.tryParse(currentNum) ?? 0);
          currentNum = '';
        }
        ops.add(ch);
      } else {
        currentNum += ch;
      }
    }

    if (currentNum.isNotEmpty) {
      numbers.add(int.tryParse(currentNum) ?? 0);
    } else if (ops.isNotEmpty) {
      // في حال انتهى التعبير بعملية غير مكتملة مثل "25 × "، نتجاهل العملية الأخيرة مؤقتاً
      ops.removeLast();
    }

    if (numbers.isEmpty) return 0;

    // 1. تنفيذ عمليات الضرب (×) أولاً
    final List<int> addSubNums = <int>[numbers.first];
    final List<String> addSubOps = <String>[];

    for (int i = 0; i < ops.length; i++) {
      final op = ops[i];
      final nextNum = (i + 1 < numbers.length) ? numbers[i + 1] : 1;
      if (op == '×') {
        final prev = addSubNums.removeLast();
        addSubNums.add((prev * nextNum).clamp(0, 9999999));
      } else {
        addSubOps.add(op);
        addSubNums.add(nextNum);
      }
    }

    // 2. تنفيذ عمليات الجمع (+) والطرح (-)
    int total = addSubNums.first;
    for (int i = 0; i < addSubOps.length; i++) {
      final op = addSubOps[i];
      final nextNum = (i + 1 < addSubNums.length) ? addSubNums[i + 1] : 0;
      if (op == '+') {
        total += nextNum;
      } else if (op == '-') {
        total -= nextNum;
      }
    }

    return total.clamp(0, 999999);
  }

  int get _evaluatedResult => _evaluateExpression(_expression);

  bool get _hasOperator =>
      _expression.contains('+') ||
      _expression.contains('-') ||
      _expression.contains('×');

  void _appendDigits(String digits) {
    setState(() {
      if (_replaceOnNextDigit && !_hasOperator) {
        if (digits == '0' || digits == '00' || digits == '000') {
          _expression = '0';
        } else {
          _expression = digits;
        }
        _replaceOnNextDigit = false;
        return;
      }

      _replaceOnNextDigit = false;
      if (_expression == '0') {
        if (digits == '0' || digits == '00' || digits == '000') {
          _expression = '0';
        } else {
          _expression = digits;
        }
        return;
      }

      if (_expression.length + digits.length <= 18) {
        _expression = '$_expression$digits';
      }
    });
  }

  void _appendOperator(String op) {
    setState(() {
      _replaceOnNextDigit = false;
      final trimmed = _expression.trim();
      if (trimmed.isEmpty) {
        _expression = '0 $op ';
        return;
      }
      final lastChar = trimmed[trimmed.length - 1];
      if (_isOperator(lastChar)) {
        // استبدال العملية الأخيرة بالعملية الجديدة
        _expression = '${trimmed.substring(0, trimmed.length - 1)}$op ';
      } else {
        _expression = '$trimmed $op ';
      }
    });
  }

  void _evaluateNow() {
    setState(() {
      final result = _evaluatedResult;
      _expression = '$result';
      _replaceOnNextDigit = true;
    });
  }

  void _addPreset(int delta) {
    setState(() {
      final base = _replaceOnNextDigit ? 0 : _evaluatedResult;
      final next = (base + delta).clamp(0, 999999);
      _expression = '$next';
      _replaceOnNextDigit = false;
    });
  }

  void _backspace() {
    setState(() {
      _replaceOnNextDigit = false;
      String trimmed = _expression.trimRight();
      if (trimmed.length <= 1) {
        _expression = '0';
      } else {
        trimmed = trimmed.substring(0, trimmed.length - 1).trimRight();
        _expression = trimmed.isEmpty ? '0' : trimmed;
      }
    });
  }

  void _clear() {
    setState(() {
      _expression = '0';
      _replaceOnNextDigit = false;
    });
  }

  void _submit() {
    Navigator.of(context).pop(_evaluatedResult);
  }

  @override
  Widget build(BuildContext context) {
    final int finalValue = _evaluatedResult;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          right: 18,
          left: 18,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
              const SizedBox(height: 10),

              // معلومات الصنف المختار
              Row(
                children: [
                  if (widget.imageAsset != null &&
                      widget.imageAsset!.isNotEmpty) ...[
                    AlRabieProductThumbnail(
                      imageAsset: widget.imageAsset!,
                      category: widget.category ?? '',
                      size: 46,
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
                              'حاسبة ${widget.unitLabel}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
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
              const SizedBox(height: 10),

              // شاشة الحاسبة الرقمية (تعرض العملية الحسابية والنتيجة النهائية الفورية)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.unitLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_hasOperator)
                          Text(
                            _expression,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              color: AppConstants.royalGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          const Text(
                            'يدعم الجمع (+) والطرح (-) والضرب (×)',
                            style: TextStyle(
                              color: AppConstants.royalGold,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _hasOperator ? 'النتيجة =' : 'الكمية:',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _hasOperator ? '$finalValue' : _expression,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // أزرار الإضافة السريعة للكميات الكبيرة (+10 / +50 / +100 / +500 / +1000 / +2500)
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final preset in [10, 50, 100, 500, 1000, 2500])
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppConstants.softRoyalGold,
                          side: const BorderSide(color: AppConstants.royalGold),
                          label: Text(
                            '+$preset',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: AppConstants.deepNavyBlue,
                            ),
                          ),
                          onPressed: () => _addPreset(preset),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // لوحة الحاسبة الرقمية المتقدمة مع العمليات الحسابية (+, -, ×, =)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    // الصف الأول: C, 00, 000, ⌫
                    Row(
                      children: [
                        _CalcKeyButton(
                          label: 'C',
                          isAction: true,
                          color: Colors.red.shade700,
                          onTap: _clear,
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '00',
                          isAction: true,
                          color: AppConstants.royalNavySecondary,
                          onTap: () => _appendDigits('00'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '000',
                          isAction: true,
                          color: AppConstants.royalNavySecondary,
                          onTap: () => _appendDigits('000'),
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
                    // الصف الثاني: 7, 8, 9, ×
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
                          label: '×',
                          isAction: true,
                          color: AppConstants.deepNavyBlue,
                          textColor: AppConstants.royalGold,
                          onTap: () => _appendOperator('×'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // الصف الثالث: 4, 5, 6, -
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
                          label: '-',
                          isAction: true,
                          color: AppConstants.deepNavyBlue,
                          textColor: AppConstants.royalGold,
                          onTap: () => _appendOperator('-'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // الصف الرابع: 1, 2, 3, +
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
                          label: '+',
                          isAction: true,
                          color: AppConstants.deepNavyBlue,
                          textColor: AppConstants.royalGold,
                          onTap: () => _appendOperator('+'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // الصف الخامس: 0 (عريض) وزر (=) لحساب النتيجة وزر الاعتماد السريع
                    Row(
                      children: [
                        _CalcKeyButton(
                          label: '0',
                          flex: 2,
                          onTap: () => _appendDigits('0'),
                        ),
                        const SizedBox(width: 8),
                        _CalcKeyButton(
                          label: '=',
                          isAction: true,
                          color: Colors.teal.shade700,
                          onTap: _evaluateNow,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 48,
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
              const SizedBox(height: 12),

              // زر الاعتماد النهائي للكمية
              SizedBox(
                height: 50,
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
                    'اعتماد الكمية ($finalValue ${widget.unitLabel})',
                    style: const TextStyle(
                      fontSize: 15,
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
  final Color? textColor;
  final int flex;

  const _CalcKeyButton({
    required this.label,
    required this.onTap,
    this.isAction = false,
    this.color,
    this.textColor,
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
            height: 48,
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
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: textColor ??
                    (isAction ? Colors.white : AppConstants.deepNavyBlue),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
