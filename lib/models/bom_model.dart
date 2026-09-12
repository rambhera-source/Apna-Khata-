Future<void> _saveBom() async {
  final product = _productController.text.trim();
  final material = _materialController.text.trim();
  final qty = double.tryParse(_qtyController.text) ?? 0.0;
  final unit = _unitController.text.trim();

  if (product.isEmpty || material.isEmpty || qty <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kripya sabhi fields sahi se bharein!')),
    );
    return;
  }

  // CHECK: Kya yeh product aur raw material ka combination pehle se hai?
  final existingBom = await DatabaseHelper.isar.billOfMaterials
      .filter()
      .finishedProductNameEqualTo(product)
      .and()
      .rawMaterialNameEqualTo(material)
      .findFirst();

  await DatabaseHelper.isar.writeTxn(() async {
    if (existingBom != null) {
      // Agar pehle se hai, toh sirf quantity update kar do (duplicate nahi banega)
      existingBom.quantityRequired += qty;
      await DatabaseHelper.isar.billOfMaterials.put(existingBom);
    } else {
      // Agar naya hai, toh nayi entry banao
      final bom = BillOfMaterials()
        ..finishedProductName = product
        ..rawMaterialName = material
        ..quantityRequired = qty
        ..unit = unit;
      await DatabaseHelper.isar.billOfMaterials.put(bom);
    }
  });

  _productController.clear();
  _materialController.clear();
  _qtyController.clear();
  
  _loadBomData();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('BOM Recipe Safaltapurvak Update / Save Ho Gayi!')),
  );
}
