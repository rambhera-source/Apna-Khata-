import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import '../database/database_helper.dart';
import '../models/inventory_model.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _stockController = TextEditingController();
  final _unitController = TextEditingController(text: 'Pcs');

  // A to Z Price Controllers Map
  final Map<String, TextEditingController> _priceControllers = {
    for (var i = 0; i < 26; i++) String.fromCharCode(65 + i): TextEditingController()
  };

  // Image Paths
  String? _img1, _img2, _img3, _img4;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Image Pick Function (Gallery se image chunne ke liye)
  Future<void> _pickImage(int imageNumber) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        if (imageNumber == 1) _img1 = pickedFile.path;
        if (imageNumber == 2) _img2 = pickedFile.path;
        if (imageNumber == 3) _img3 = pickedFile.path;
        if (imageNumber == 4) _img4 = pickedFile.path;
      });
    }
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    double stock = double.tryParse(_stockController.text) ?? 0.0;
    final unit = _unitController.text.trim();

    if (name.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Product Name aur Category zaroor bharein!')),
      );
      return;
    }

    // Duplicate Check
    final existing = await DatabaseHelper.isar.inventoryItems
        .filter()
        .itemNameEqualTo(name, caseSensitive: false)
        .findFirst();

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: "$name" naam ka product pehle se bana hai!')),
      );
      return;
    }

    final newProduct = InventoryItem()
      ..itemName = name
      ..category = category
      ..stockQuantity = stock
      ..unit = unit.isEmpty ? 'Pcs' : unit
      ..imagePath1 = _img1
      ..imagePath2 = _img2
      ..imagePath3 = _img3
      ..imagePath4 = _img4
      ..priceA = double.tryParse(_priceControllers['A']?.text ?? '0') ?? 0.0
      ..priceB = double.tryParse(_priceControllers['B']?.text ?? '0') ?? 0.0
      ..priceC = double.tryParse(_priceControllers['C']?.text ?? '0') ?? 0.0
      ..priceD = double.tryParse(_priceControllers['D']?.text ?? '0') ?? 0.0
      ..priceE = double.tryParse(_priceControllers['E']?.text ?? '0') ?? 0.0
      ..priceF = double.tryParse(_priceControllers['F']?.text ?? '0') ?? 0.0
      ..priceG = double.tryParse(_priceControllers['G']?.text ?? '0') ?? 0.0
      ..priceH = double.tryParse(_priceControllers['H']?.text ?? '0') ?? 0.0
      ..priceI = double.tryParse(_priceControllers['I']?.text ?? '0') ?? 0.0
      ..priceJ = double.tryParse(_priceControllers['J']?.text ?? '0') ?? 0.0
      ..priceK = double.tryParse(_priceControllers['K']?.text ?? '0') ?? 0.0
      ..priceL = double.tryParse(_priceControllers['L']?.text ?? '0') ?? 0.0
      ..priceM = double.tryParse(_priceControllers['M']?.text ?? '0') ?? 0.0
      ..priceN = double.tryParse(_priceControllers['N']?.text ?? '0') ?? 0.0
      ..priceO = double.tryParse(_priceControllers['O']?.text ?? '0') ?? 0.0
      ..priceP = double.tryParse(_priceControllers['P']?.text ?? '0') ?? 0.0
      ..priceQ = double.tryParse(_priceControllers['Q']?.text ?? '0') ?? 0.0
      ..priceR = double.tryParse(_priceControllers['R']?.text ?? '0') ?? 0.0
      ..priceS = double.tryParse(_priceControllers['S']?.text ?? '0') ?? 0.0
      ..priceT = double.tryParse(_priceControllers['T']?.text ?? '0') ?? 0.0
      ..priceU = double.tryParse(_priceControllers['U']?.text ?? '0') ?? 0.0
      ..priceV = double.tryParse(_priceControllers['V']?.text ?? '0') ?? 0.0
      ..priceW = double.tryParse(_priceControllers['W']?.text ?? '0') ?? 0.0
      ..priceX = double.tryParse(_priceControllers['X']?.text ?? '0') ?? 0.0
      ..priceY = double.tryParse(_priceControllers['Y']?.text ?? '0') ?? 0.0
      ..priceZ = double.tryParse(_priceControllers['Z']?.text ?? '0') ?? 0.0;

    await DatabaseHelper.isar.writeTxn(() async {
      await DatabaseHelper.isar.inventoryItems.put(newProduct);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Product "$name" safaltapurvak save ho gaya!')),
    );

    // Reset Form
    _nameController.clear();
    _categoryController.clear();
    _stockController.clear();
    setState(() {
      _img1 = _img2 = _img3 = _img4 = null;
      for (var controller in _priceControllers.values) {
        controller.clear();
      }
    });
  }

  Widget _buildImagePickerBox(String? imgPath, int imgNumber) {
    return GestureDetector(
      onTap: () => _pickImage(imgNumber),
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.teal.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: imgPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(File(imgPath), fit: BoxFit.cover),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: Colors.teal, size: 24),
                  SizedBox(height: 2),
                  Text('Add Img', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product & A-Z Pricing'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Details
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shopping_bag)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category / Group *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category), hintText: 'e.g. Mobile Accessories'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Opening Stock Qty', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit (Pcs/Box)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 🖼️ 4 Images Section
              const Text('Product Images (Max 4):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildImagePickerBox(_img1, 1),
                  _buildImagePickerBox(_img2, 2),
                  _buildImagePickerBox(_img3, 3),
                  _buildImagePickerBox(_img4, 4),
                ],
              ),
              const SizedBox(height: 20),

              // 🏷️ A to Z Pricing Tiers Section
              const Text('A to Z Price Tiers (Category Rates):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('Scroll down to set prices for Tier A through Z.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),

              // Scrollable A-Z Pricing Grid/List
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50.withOpacity(0.5),
                  border: Border.all(color: Colors.teal.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 26,
                  itemBuilder: (context, index) {
                    String tierChar = String.fromCharCode(65 + index);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Tier $tierChar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _priceControllers[tierChar],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Price for Category $tierChar (₹)',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _saveProduct,
                  child: const Text('Save Product & A-Z Prices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
