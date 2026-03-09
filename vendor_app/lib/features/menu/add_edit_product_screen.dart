import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';

class AddEditProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  final String vendorId;

  const AddEditProductScreen({super.key, this.product, required this.vendorId});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _imageCtrl;
  String _spiceLevel = 'Medium';
  bool _isSignature = false;
  XFile? _imageFile;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?['name'] ?? '');
    _descCtrl =
        TextEditingController(text: widget.product?['description'] ?? '');
    _priceCtrl =
        TextEditingController(text: widget.product?['price']?.toString() ?? '');
    _imageCtrl =
        TextEditingController(text: widget.product?['image_url'] ?? '');
    _spiceLevel = widget.product?['spice_level'] ?? 'Medium';
    _isSignature = widget.product?['is_signature'] ?? false;
  }

  Future<void> _pickImage() async {
    debugPrint(">>> ASSET VAULT: Initializing Multi-Engine Capture...");
    try {
      // Primary: Image Picker (Standard)
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        debugPrint(
            ">>> ASSET VAULT: System Capture Successful -> ${pickedFile.path}");
        setState(() => _imageFile = pickedFile);
        await _uploadImage();
        return;
      }
    } catch (e) {
      debugPrint(
          ">>> ASSET VAULT: System Engine Failed, activating Secondary Vault...");
    }

    // Secondary: File Picker (Fallback/More Stable for Gallery)
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        debugPrint(">>> ASSET VAULT: Secondary Capture Successful -> $path");
        setState(() {
          _imageFile = XFile(path);
        });
        await _uploadImage();
      } else {
        debugPrint(">>> ASSET VAULT: Capture sequence aborted by user.");
      }
    } catch (e) {
      debugPrint(">>> ASSET VAULT: All Engines Failed -> $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ProTheme.error,
            content: const Text(
                "Visual Pipeline Blocked. REQUIRED: SYSTEM REBOOT (Cold Start)"),
            action: SnackBarAction(
              label: "WHY?",
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("System Sync Required"),
                    content: const Text(
                        "The 'Channel Error' means the app was not restarted after adding the camera plugins. Please STOP the app and run it again (NOT hot reload)."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("OK"))
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;
    setState(() => _isUploading = true);
    debugPrint(">>> ASSET VAULT: Syncing with Cloud Repository...");

    try {
      final fileExt = _imageFile!.path.split('.').last;
      final fileName =
          'menu-items/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final bytes = await _imageFile!.readAsBytes();

      await SupabaseConfig.client.storage.from('images').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final publicUrl =
          SupabaseConfig.client.storage.from('images').getPublicUrl(fileName);

      debugPrint(">>> ASSET VAULT: Deployment Successful -> $publicUrl");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ProTheme.success,
            content: Text("Visual Asset Anchored Successfully"),
          ),
        );
      }
      setState(() {
        _imageCtrl.text = publicUrl;
      });
    } catch (e) {
      debugPrint(">>> UPLOAD ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ProTheme.error,
            content: Text("Asset Deployment Failed: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final updates = {
        'vendor_id': widget.vendorId,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text.trim()),
        'image_url':
            _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
        'is_available': widget.product?['is_available'] ?? true,
        'spice_level': _spiceLevel,
        'is_signature': _isSignature,
      };

      if (widget.product != null) {
        await SupabaseConfig.client
            .from('products')
            .update(updates)
            .eq('id', widget.product!['id']);
      } else {
        await SupabaseConfig.client.from('products').insert(updates);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ProTheme.error,
            content: Text('Operation Failed: $e',
                style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(
        title: Text(widget.product == null ? "NEW ASSET" : "EDIT ASSET",
            style: ProTheme.header.copyWith(fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("IDENTITY", LucideIcons.tag),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                style: ProTheme.title.copyWith(fontSize: 16),
                decoration: ProTheme.inputDecor(
                    "Product Designation", LucideIcons.package),
                validator: (v) => v!.isEmpty ? 'Identifier Required' : null,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader("COMMERCIALS", LucideIcons.indianRupee),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceCtrl,
                style: ProTheme.title
                    .copyWith(fontSize: 16, color: ProTheme.secondary),
                decoration:
                    ProTheme.inputDecor("Unit Price", LucideIcons.banknote),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v!.isEmpty ? 'Value Required' : null,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader("SPECIFICATIONS", LucideIcons.fileText),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                style: ProTheme.body,
                decoration: ProTheme.inputDecor(
                    "Asset Description", LucideIcons.alignLeft),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader("CRAFT CHARACTERISTICS", LucideIcons.sliders),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Spice Intensity",
                      style: ProTheme.label.copyWith(fontSize: 11)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Mild', 'Medium', 'Hot'].map((spice) {
                      final isSelected = _spiceLevel == spice;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
                          label: Text(spice),
                          selected: isSelected,
                          onSelected: (v) =>
                              setState(() => _spiceLevel = spice),
                          selectedColor: ProTheme.primary,
                          backgroundColor: Colors.white,
                          labelStyle: ProTheme.label.copyWith(
                            color: isSelected ? ProTheme.dark : ProTheme.gray,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  isSelected ? ProTheme.primary : ProTheme.bg,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ProTheme.bg),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.star,
                        color: ProTheme.primary, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Signature Dish",
                              style: ProTheme.title.copyWith(fontSize: 14)),
                          Text("Mark as a special Boutique creation",
                              style: ProTheme.label.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isSignature,
                      onChanged: (v) => setState(() => _isSignature = v),
                      activeColor: ProTheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader("VISUAL REPOSITORY", LucideIcons.image),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                          color: ProTheme.dark.withOpacity(0.05), width: 1),
                      image: _imageCtrl.text.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_imageCtrl.text),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imageCtrl.text.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.camera,
                                  color: ProTheme.gray.withOpacity(0.3),
                                  size: 48),
                              const SizedBox(height: 12),
                              Text("NO ASSET DEPLOYED",
                                  style: ProTheme.label.copyWith(
                                      fontSize: 10,
                                      color: ProTheme.gray.withOpacity(0.5))),
                            ],
                          )
                        : null,
                  ),
                  if (_isUploading)
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Activating Capture Engine..."),
                                  duration: Duration(milliseconds: 500),
                                ),
                              );
                              _pickImage();
                            },
                      icon: Icon(
                          _imageCtrl.text.isEmpty
                              ? LucideIcons.uploadCloud
                              : LucideIcons.refreshCcw,
                          size: 18),
                      label: Text(
                          _imageCtrl.text.isEmpty
                              ? "PICK VISUAL ASSET"
                              : "REPLACE ASSET",
                          style: ProTheme.button.copyWith(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ProTheme.primary,
                        foregroundColor: ProTheme.dark,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isUploading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  backgroundColor: ProTheme.bg,
                  color: ProTheme.primary,
                  minHeight: 2,
                ),
                const SizedBox(height: 4),
                Text("UPLOADING TO CLOUD...",
                    style: ProTheme.label
                        .copyWith(fontSize: 8, color: ProTheme.primary)),
              ],
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  style: ProTheme.ctaButton,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          widget.product == null
                              ? "COMMIT TO VAULT"
                              : "UPDATE SPECIFICATIONS",
                          style: ProTheme.button),
                ),
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.05, end: 0),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: ProTheme.gray),
        const SizedBox(width: 8),
        Text(label,
            style: ProTheme.label.copyWith(fontSize: 10, color: ProTheme.gray)),
      ],
    );
  }
}
