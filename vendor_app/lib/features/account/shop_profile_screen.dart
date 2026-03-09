import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';

class ShopProfileScreen extends StatefulWidget {
  final Map<String, dynamic> vendor;
  const ShopProfileScreen({super.key, required this.vendor});

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cuisineController;
  late TextEditingController _imageCtrl;
  XFile? _imageFile;
  bool _saving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vendor['name']);
    _phoneController = TextEditingController(text: widget.vendor['phone']);
    _addressController = TextEditingController(text: widget.vendor['address']);
    _cuisineController =
        TextEditingController(text: widget.vendor['cuisine_type']);
    _imageCtrl = TextEditingController(text: widget.vendor['image_url']);
  }

  Future<void> _pickImage() async {
    debugPrint(">>> BOUTIQUE: Initializing Dual-Engine Brand Capture...");
    try {
      // Primary: Image Picker
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        debugPrint(
            ">>> BOUTIQUE: System Capture Successful -> ${pickedFile.path}");
        setState(() => _imageFile = pickedFile);
        await _uploadImage();
        return;
      }
    } catch (e) {
      debugPrint(
          ">>> BOUTIQUE: System Engine Stalled, activating Secondary Vault...");
    }

    // Secondary: File Picker (Fallback)
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        debugPrint(">>> BOUTIQUE: Secondary Capture Successful -> $path");
        setState(() {
          _imageFile = XFile(path);
        });
        await _uploadImage();
      } else {
        debugPrint(">>> BOUTIQUE: Brand Capture sequence aborted.");
      }
    } catch (e) {
      debugPrint(">>> BOUTIQUE: All Optical Engines Failed -> $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ProTheme.error,
            content: const Text("Brand Visual Pipeline Blocked."),
            action: SnackBarAction(
              label: "FIX",
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Reboot Required"),
                    content: const Text(
                        "To sync the Gallery hardware, please STOP the app and run it again (NOT hot reload). This registers the internal sensors."),
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
    debugPrint(">>> BOUTIQUE: Syncing Brand Identity with Cloud...");

    try {
      final fileExt = _imageFile!.path.split('.').last;
      final fileName =
          'vendors/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      final bytes = await _imageFile!.readAsBytes();

      await SupabaseConfig.client.storage.from('images').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final publicUrl =
          SupabaseConfig.client.storage.from('images').getPublicUrl(fileName);

      debugPrint(">>> BOUTIQUE: Brand Identity Synchronized -> $publicUrl");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ProTheme.success,
            content: Text("Vendor Identity Synchronized"),
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
            content: Text("Cloud Deployment Failed: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseConfig.client.from('vendors').update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'cuisine_type': _cuisineController.text.trim(),
        'image_url': _imageCtrl.text.trim(),
      }).eq('id', widget.vendor['id']);

      if (mounted) {
        // Force re-bootstrap to refresh dashboard and stores
        await SupabaseConfig.bootstrap();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ProTheme.secondary,
            content: Text("Vendor specifications updated successfully.",
                style: TextStyle(color: Colors.white)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ProTheme.error,
            content: Text("Transmission Error: $e",
                style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(
        title: Text("VENDOR CONFIG",
            style: ProTheme.header.copyWith(fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildSection("BRAND IDENTITY", [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ProTheme.dark.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(32),
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
                              Text("NO BRAND VISUAL",
                                  style: ProTheme.label.copyWith(
                                      fontSize: 10,
                                      color: ProTheme.gray.withOpacity(0.5))),
                            ],
                          )
                        : null,
                  ),
                  if (_isUploading)
                    Container(
                      height: 200,
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
                                  content: Text("Activating Brand Capture..."),
                                  duration: Duration(milliseconds: 500),
                                ),
                              );
                              _pickImage();
                            },
                      icon: Icon(
                          _imageCtrl.text.isEmpty
                              ? LucideIcons.camera
                              : LucideIcons.refreshCcw,
                          size: 18),
                      label: Text(
                          _imageCtrl.text.isEmpty
                              ? "DEPLOY BRAND VISUAL"
                              : "REPLACE BRAND VISUAL",
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
              ],
              const SizedBox(height: 24),
              _buildField("Vendor Name", _nameController, LucideIcons.store),
              const SizedBox(height: 20),
              _buildField("Cuisine Architecture", _cuisineController,
                  LucideIcons.chefHat),
            ]),
            const SizedBox(height: 32),
            _buildSection("LOGISTICS", [
              _buildField(
                  "Secure Contact", _phoneController, LucideIcons.phone),
              const SizedBox(height: 20),
              _buildField(
                  "Deployment Address", _addressController, LucideIcons.mapPin,
                  maxLines: 3),
            ]),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ProTheme.ctaButton,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text("SYNCHRONIZE PROFILE", style: ProTheme.button),
              ),
            )
          ],
        ).animate().fadeIn().slideY(begin: 0.05, end: 0),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(title,
              style:
                  ProTheme.label.copyWith(fontSize: 10, color: ProTheme.gray)),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: ProTheme.cardDecor,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: ProTheme.label
                .copyWith(fontSize: 9, color: ProTheme.gray.withOpacity(0.7))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: ProTheme.title.copyWith(fontSize: 16),
          decoration: ProTheme.inputDecor(label, icon),
        ),
      ],
    );
  }
}
