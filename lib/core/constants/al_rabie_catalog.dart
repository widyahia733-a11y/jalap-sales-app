import 'package:flutter/material.dart';

import 'app_constants.dart';

/// نموذج الصنف المعتمد من كتالوج شركة الربيع الرسمي (ملف: اصناف الربيع.xlsx - ورقة ORDER)
class AlRabieProduct {
  final String id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final int packPerCarton;
  final double cartonPrice;
  final String imageAsset;

  const AlRabieProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.packPerCarton,
    required this.cartonPrice,
    required this.imageAsset,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'sku': code,
      'name': name,
      'category': category,
      'unit': unit,
      'pack_per_carton': packPerCarton,
      'carton_price': cartonPrice,
      'image_asset': imageAsset,
    };
  }
}

/// الكتالوج المركزي الكامل لأصناف الربيع المستخرجة بنسبة 100% من ملف (اصناف الربيع.xlsx - ورقة ORDER)
class AlRabieCatalog {
  AlRabieCatalog._();

  static const List<String> categories = [
    'الكل',
    'عصير الربيع 185 مل',
    'عصير الربيع 330 مل',
    'عصير الربيع 1 لتر',
    'عصير برازما 250 مل',
    'شراب الربيع',
    'حليب الربيع سادة',
    'حليب الربيع منكهات',
    'مشروبات خاصة وقهوة',
  ];

  /// المرجع المباشر لجميع الأصناف الـ 62 المعتمدة (Local-First Guaranteed Rendering)
  static const List<AlRabieProduct> items = allProducts;

  /// جميع الأصناف الرسمية (62 صنفاً) بأرقام الأصناف الرسمية والأكواد التسلسلية (JLP-3001..JLP-3012) والصور المرفقة
  static const List<AlRabieProduct> allProducts = [
    // =========================================================================
    // 1. عصير الربيع 185 مل (9 أصناف)
    // =========================================================================
    AlRabieProduct(
      id: 'rabie-43002001',
      code: '43002001',
      name: 'عصير الربيع مانجو 18 × 185 ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image1.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002003',
      code: '43002003',
      name: 'عصير الربيع تفاح 18 × 185 ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image23.jpeg',
    ),
    AlRabieProduct(
      id: 'rabie-43002002',
      code: '43002002',
      name: 'عصير الربيع فواكة مشكلة 18 × 185 ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image23.jpeg',
    ),
    AlRabieProduct(
      id: 'rabie-43002006',
      code: '43002006',
      name: 'عصير الربيع مشكل برتقال 18 × 185 ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image23.jpeg',
    ),
    AlRabieProduct(
      id: 'rabie-43002004',
      code: '43002004',
      name: 'عصير الربيع توت 18 × 185 ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image23.jpeg',
    ),
    AlRabieProduct(
      id: 'rabie-43002005',
      code: '43002005',
      name: 'عصير الربيع كيوي وليمون 18 × 185 ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image23.jpeg',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3001',
      code: 'JLP-3001',
      name: 'عصير الربيع أناناس وفواكه مشكلة 18×185ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image23.jpeg',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3002',
      code: 'JLP-3002',
      name: 'عصير الربيع عنب 18 × 185 ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image23.jpeg',
    ),
    AlRabieProduct(
      id: 'rabie-43002057',
      code: '43002057',
      name: 'عصير الربيع اناناس 18 × 185 ملي',
      category: 'عصير الربيع 185 مل',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4500,
      imageAsset: 'assets/images/products/image1.png',
    ),

    // =========================================================================
    // 2. عصير الربيع 330 مل (9 أصناف)
    // =========================================================================
    AlRabieProduct(
      id: 'rabie-43002031',
      code: '43002031',
      name: 'عصير الربيع مانجو 18 × 330 ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002032',
      code: '43002032',
      name: 'عصير الربيع تفاح 18 × 330 ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002038',
      code: '43002038',
      name: 'عصير الربيع فواكة مشكلة 18 × 330 ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002037',
      code: '43002037',
      name: 'عصير الربيع فواكة + فيتامينات 18 × 330 ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002033',
      code: '43002033',
      name: 'عصير الربيع برتقال 18 × 330 ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002036',
      code: '43002036',
      name: 'عصير الربيع توت 18 × 330 ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002035',
      code: '43002035',
      name: 'عصير الربيع كيوي وليمون 18 × 330 ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002039',
      code: '43002039',
      name: 'مشروب الليمون والنعناع 330x18ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002034',
      code: '43002034',
      name: 'عصير الربيع اناناس 18 × 330 ملي',
      category: 'عصير الربيع 330 مل',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 6800,
      imageAsset: 'assets/images/products/image2.png',
    ),

    // =========================================================================
    // 3. عصير الربيع 1 لتر (10 أصناف)
    // =========================================================================
    AlRabieProduct(
      id: 'rabie-43002051',
      code: '43002051',
      name: 'عصير الربيع مانجو 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002052',
      code: '43002052',
      name: 'عصير الربيع فواكة مشكلة 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002055',
      code: '43002055',
      name: 'عصير الربيع توت مشكل 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002056',
      code: '43002056',
      name: 'عصير الربيع كيوي وليمون 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3003',
      code: 'JLP-3003',
      name: 'عصير الربيع ليمون ونعناع 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002054',
      code: '43002054',
      name: 'عصير الربيع تفاح 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002053',
      code: '43002053',
      name: 'عصير الربيع برتقال مشكل 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3004',
      code: 'JLP-3004',
      name: 'عصير الربيع اناناس 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3005',
      code: 'JLP-3005',
      name: 'عصير الربيع اناناس وفواكة مشكلة 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3006',
      code: 'JLP-3006',
      name: 'عصير الربيع عنب 8 × 1 لتر',
      category: 'عصير الربيع 1 لتر',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 7600,
      imageAsset: 'assets/images/products/image3.png',
    ),

    // =========================================================================
    // 4. عصير برازما 250 مل (10 أصناف)
    // =========================================================================
    AlRabieProduct(
      id: 'rabie-43002013',
      code: '43002013',
      name: 'عصير الربيع برازما مانجو 18 × 250 ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image9.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002014',
      code: '43002014',
      name: 'عصير الربيع برازما برتقال 18 × 250 ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image5.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002016',
      code: '43002016',
      name: 'عصير الربيع برازما تفاح نكتار 18 × 250 ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image6.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002017',
      code: '43002017',
      name: 'عصير الربيع برازما فواكة مشكلة 18 × 250 ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image7.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002018',
      code: '43002018',
      name: 'عصير الربيع برازما مشكل برتقال 18 × 250 ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image8.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002019',
      code: '43002019',
      name: 'عصير الربيع برازما فواكه فيتامينات متعددة 18×250ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image9.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002015',
      code: '43002015',
      name: 'عصير الربيع برازما توت 18 × 250 ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image7.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002021',
      code: '43002021',
      name: 'عصير الربيع برازما اناناس وفواكة مشكلة 18 × 250ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image8.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3008',
      code: 'JLP-3008',
      name: 'عصير الربيع ليمون ونعناع 18 × 250 ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image6.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002020',
      code: '43002020',
      name: 'عصير الربيع برازما كيوي ليمون 18 × 250 ملي',
      category: 'عصير برازما 250 مل',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 5400,
      imageAsset: 'assets/images/products/image5.png',
    ),

    // =========================================================================
    // 5. شراب الربيع (9 أصناف)
    // =========================================================================
    AlRabieProduct(
      id: 'rabie-43002152',
      code: '43002152',
      name: 'شراب الربيع برتقال 18 × 125 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 3200,
      imageAsset: 'assets/images/products/image24.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002154',
      code: '43002154',
      name: 'شراب الربيع التوت المشكل 18 × 125 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 3200,
      imageAsset: 'assets/images/products/image24.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002151',
      code: '43002151',
      name: 'شراب الربيع مانجو 18 × 125 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 3200,
      imageAsset: 'assets/images/products/image24.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002153',
      code: '43002153',
      name: 'شراب الربيع تفاح 18 × 125 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 3200,
      imageAsset: 'assets/images/products/image24.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002101',
      code: '43002101',
      name: 'شراب الربيع برتقال 27 × 250 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (27 × 250 مل)',
      packPerCarton: 27,
      cartonPrice: 6200,
      imageAsset: 'assets/images/products/image22.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002121',
      code: '43002121',
      name: 'شراب الربيع تفاح 18 × 250 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 4400,
      imageAsset: 'assets/images/products/image22.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002122',
      code: '43002122',
      name: 'شراب الربيع مانجو 18 × 250 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 4400,
      imageAsset: 'assets/images/products/image22.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002123',
      code: '43002123',
      name: 'شراب الربيع كوكتيل فواكة 18 × 250 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 4400,
      imageAsset: 'assets/images/products/image22.png',
    ),
    AlRabieProduct(
      id: 'rabie-43002124',
      code: '43002124',
      name: 'شراب الربيع توت مشكل 18 × 250 ملي',
      category: 'شراب الربيع',
      unit: 'كرتون (18 × 250 مل)',
      packPerCarton: 18,
      cartonPrice: 4400,
      imageAsset: 'assets/images/products/image22.png',
    ),

    // =========================================================================
    // 6. حليب الربيع سادة (4 أصناف)
    // =========================================================================
    AlRabieProduct(
      id: 'rabie-43001021',
      code: '43001021',
      name: 'حليب الربيع وسط 27 × 250 ملي',
      category: 'حليب الربيع سادة',
      unit: 'كرتون (27 × 250 مل)',
      packPerCarton: 27,
      cartonPrice: 7800,
      imageAsset: 'assets/images/products/image4.png',
    ),
    AlRabieProduct(
      id: 'rabie-43001001',
      code: '43001001',
      name: 'حليب الربيع 18 × 185 ملي',
      category: 'حليب الربيع سادة',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 4900,
      imageAsset: 'assets/images/products/image14.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3007',
      code: 'JLP-3007',
      name: 'حليب الربيع 18 × 125ملي',
      category: 'حليب الربيع سادة',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 3800,
      imageAsset: 'assets/images/products/image14.png',
    ),
    AlRabieProduct(
      id: 'rabie-43001061',
      code: '43001061',
      name: 'حليب الربيع كبير 8 × 1 لتر',
      category: 'حليب الربيع سادة',
      unit: 'كرتون (8 × 1 لتر)',
      packPerCarton: 8,
      cartonPrice: 8200,
      imageAsset: 'assets/images/products/image4.png',
    ),

    // =========================================================================
    // 7. حليب الربيع منكهات (8 أصناف)
    // =========================================================================
    AlRabieProduct(
      id: 'rabie-43001004',
      code: '43001004',
      name: 'حليب الربيع منكهات بسكويت 18 × 185 ملي',
      category: 'حليب الربيع منكهات',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 5200,
      imageAsset: 'assets/images/products/image10.png',
    ),
    AlRabieProduct(
      id: 'rabie-43001003',
      code: '43001003',
      name: 'حليب الربيع بالشوكولاتة 18 × 185 ملي',
      category: 'حليب الربيع منكهات',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 5200,
      imageAsset: 'assets/images/products/image11.png',
    ),
    AlRabieProduct(
      id: 'rabie-43001002',
      code: '43001002',
      name: 'حليب الربيع بالفراولة 18 × 185 ملي',
      category: 'حليب الربيع منكهات',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 5200,
      imageAsset: 'assets/images/products/image12.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3009',
      code: 'JLP-3009',
      name: 'حليب الربيع بالموز 18 × 185ملي',
      category: 'حليب الربيع منكهات',
      unit: 'كرتون (18 × 185 مل)',
      packPerCarton: 18,
      cartonPrice: 5200,
      imageAsset: 'assets/images/products/image13.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3010',
      code: 'JLP-3010',
      name: 'حليب الربيع بالبسكويت 18 × 125ملي',
      category: 'حليب الربيع منكهات',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 4000,
      imageAsset: 'assets/images/products/image18.png',
    ),
    AlRabieProduct(
      id: 'rabie-43001015',
      code: '43001015',
      name: 'حليب الربيع بالشوكولاتة 18 × 125ملي',
      category: 'حليب الربيع منكهات',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 4000,
      imageAsset: 'assets/images/products/image15.png',
    ),
    AlRabieProduct(
      id: 'rabie-43001016',
      code: '43001016',
      name: 'حليب الربيع بالفرولة 18 × 125ملي',
      category: 'حليب الربيع منكهات',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 4000,
      imageAsset: 'assets/images/products/image16.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3011',
      code: 'JLP-3011',
      name: 'حليب الربيع بالموز 18 × 125ملي',
      category: 'حليب الربيع منكهات',
      unit: 'كرتون (18 × 125 مل)',
      packPerCarton: 18,
      cartonPrice: 4000,
      imageAsset: 'assets/images/products/image17.png',
    ),

    // =========================================================================
    // 8. مشروبات خاصة وقهوة (3 أصناف)
    // =========================================================================
    AlRabieProduct(
      id: 'rabie-43003001',
      code: '43003001',
      name: 'كابتشينو قهوة 330x18ملي',
      category: 'مشروبات خاصة وقهوة',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 7400,
      imageAsset: 'assets/images/products/image19.png',
    ),
    AlRabieProduct(
      id: 'rabie-43003002',
      code: '43003002',
      name: 'شوكولاتة بالبندق 330x18ملي',
      category: 'مشروبات خاصة وقهوة',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 7400,
      imageAsset: 'assets/images/products/image20.png',
    ),
    AlRabieProduct(
      id: 'rabie-JLP-3012',
      code: 'JLP-3012',
      name: 'شوكولاتة بالكراميل 330x18ملي',
      category: 'مشروبات خاصة وقهوة',
      unit: 'كرتون (18 × 330 مل)',
      packPerCarton: 18,
      cartonPrice: 7400,
      imageAsset: 'assets/images/products/image21.png',
    ),
  ];

  /// تطبيع النصوص العربية لتسهيل البحث الفوري بالاسم أو الكود (توحيد الهمزات والتاء المربوطة والياء)
  static String normalizeArabicSearch(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('×', 'x');
  }

  /// البحث عن صنف من الكتالوج بواسطة رقم الصنف (SKU) أو المعرف المحلي أو الرقم التسلسلي في قاعدة البيانات
  static AlRabieProduct? findBySkuOrId(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    final trimmed = key.trim();
    for (int i = 0; i < allProducts.length; i++) {
      final p = allProducts[i];
      if (p.code == trimmed ||
          p.id == trimmed ||
          'rabie-${p.code}' == trimmed ||
          '${i + 1}' == trimmed) {
        return p;
      }
    }
    return null;
  }

  static String resolveImageByCodeOrName(String code, String name) {
    for (final p in allProducts) {
      if (p.code == code || p.id == code || p.name == name) {
        return p.imageAsset;
      }
    }
    if (name.contains('حليب') && name.contains('شوكولاتة')) {
      return 'assets/images/products/image11.png';
    }
    if (name.contains('حليب') && name.contains('فراولة')) {
      return 'assets/images/products/image12.png';
    }
    if (name.contains('حليب') && name.contains('موز')) {
      return 'assets/images/products/image13.png';
    }
    if (name.contains('حليب') && name.contains('بسكويت')) {
      return 'assets/images/products/image10.png';
    }
    if (name.contains('حليب')) {
      return 'assets/images/products/image4.png';
    }
    if (name.contains('برازما')) {
      return 'assets/images/products/image5.png';
    }
    if (name.contains('شراب')) {
      return 'assets/images/products/image22.png';
    }
    if (name.contains('1 لتر')) {
      return 'assets/images/products/image3.png';
    }
    if (name.contains('330')) {
      return 'assets/images/products/image2.png';
    }
    return 'assets/images/products/image1.png';
  }
}

/// صورة مصغرة احترافية للصنف مع معالجة تلقائية للصور البديلة (Fallback Thumbnail)
class AlRabieProductThumbnail extends StatelessWidget {
  final String imageAsset;
  final String category;
  final double size;

  const AlRabieProductThumbnail({
    super.key,
    required this.imageAsset,
    required this.category,
    this.size = 54,
  });

  IconData _fallbackIcon() {
    if (category.contains('حليب')) return Icons.local_drink_rounded;
    if (category.contains('قهوة')) return Icons.coffee_rounded;
    return Icons.emoji_food_beverage_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.royalGold.withOpacity(0.45),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.deepNavyBlue.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imageAsset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppConstants.softRoyalGold,
              alignment: Alignment.center,
              child: Icon(
                _fallbackIcon(),
                color: AppConstants.deepNavyBlue,
                size: size * 0.48,
              ),
            );
          },
        ),
      ),
    );
  }
}
