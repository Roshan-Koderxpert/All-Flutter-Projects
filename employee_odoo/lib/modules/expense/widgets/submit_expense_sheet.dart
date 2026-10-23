import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/expense_controller.dart';

class SubmitExpenseSheet extends StatefulWidget {
  const SubmitExpenseSheet({super.key});

  static Future<void> show() {
    return Get.bottomSheet(
      Wrap(
        // Get.bottomSheet builds its own route and takes neither
        // bottomSheetTheme nor a constraints argument, so the tablet cap is
        // applied to the sheet content itself.
        children: const [ResponsiveBody(child: SubmitExpenseSheet())],
      ),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  @override
  State<SubmitExpenseSheet> createState() => _SubmitExpenseSheetState();
}

class _SubmitExpenseSheetState extends State<SubmitExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  int? _categoryId;
  DateTime _date = DateTime.now();
  File? _attachedFile;
  String? _attachedFileName;
  String? _attachedMimeType;
  bool _paidByCompany = false;

  final controller = Get.find<ExpenseController>();

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (!_canAttach()) return;
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _attachedFile = File(picked.path);
        _attachedFileName = picked.name;
        _attachedMimeType = _mimeTypeFor(picked.path.split('.').last);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (!_canAttach()) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _attachedFile = File(picked.path);
        _attachedFileName = picked.name;
        _attachedMimeType = _mimeTypeFor(picked.path.split('.').last);
      });
    }
  }

  Future<void> _pickAnyFile() async {
    if (!_canAttach()) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _attachedFile = File(path);
        _attachedFileName = result.files.single.name;
        _attachedMimeType = _mimeTypeFor(path.split('.').last);
      });
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachedFile = null;
      _attachedFileName = null;
      _attachedMimeType = null;
    });
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (result != null) setState(() => _date = result);
  }

  Future<void> _submit() async {
    
    if (!_formKey.currentState!.validate() || _categoryId == null) {
      if (_categoryId == null) {
        Get.snackbar('Category required', 'Please select an expense category',
            snackPosition: SnackPosition.BOTTOM);
      }
      return;
    }

    final bytes = _attachedFile != null ? await _attachedFile!.readAsBytes() : null;

    final ok = await controller.submitExpense(
      categoryId: _categoryId!,
      description: _descriptionController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      date: _date,
      paidByCompany: _paidByCompany,
      notes: _notesController.text,
      receiptBytes: bytes,
      receiptFileName: _attachedFileName,
      receiptMimeType: _attachedMimeType,
    );

    if (ok) {
      Get.back();
      final warning = controller.lastError.value;
      if (warning.isNotEmpty) {
        Get.snackbar('Saved as draft', warning,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange.shade100,
            colorText: Colors.orange.shade900);
      } else {
        Get.snackbar('Submitted', 'Your expense has been sent for approval',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.brandBlue, colorText: Colors.white);
      }
    } else {
      final raw = controller.lastError.value;
      final short = raw.length > 120 ? '${raw.substring(0, 120)}...' : raw;
      Get.snackbar('Failed', short.isNotEmpty ? short : 'Could not submit expense, please try again',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
          maxWidth: 400);
    }
  }

  bool _canAttach() {
    final categoryOk = _categoryId != null;
    final descriptionOk = _descriptionController.text.trim().isNotEmpty;
    if (!categoryOk || !descriptionOk) {
      Get.snackbar(
        'Fill required fields first',
        'Please select a Category and enter a Description before attaching a receipt.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
    return true;
  }

  String _mimeTypeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Widget _buildAttachmentPreview() {
    final isImage = _attachedMimeType?.startsWith('image/') ?? false;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_attachedFile!, width: 48, height: 48, fit: BoxFit.cover),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined, color: AppColors.brandBlue),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _attachedFileName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _removeAttachment,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 1;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: keyboardHeight + 20,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('New Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              Obx(() => DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                value: _categoryId,
                items: controller.categories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              )),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              const Text('Paid By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Employee (to reimburse)'),
                value: false,
                groupValue: _paidByCompany,
                onChanged: (v) => setState(() => _paidByCompany = v ?? false),
              ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Company'),
                value: true,
                groupValue: _paidByCompany,
                onChanged: (v) => setState(() => _paidByCompany = v ?? false),
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                  child: Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              const Text('Attach Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Category and Description must be filled before attaching a receipt.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),

              if (_attachedFile != null) _buildAttachmentPreview(),
              if (_attachedFile != null) const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickAnyFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Browse Files (PDF, DOC...)'),
                ),
              ),
              const SizedBox(height: 20),

              Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isSubmitting.value ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: controller.isSubmitting.value
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit', style: TextStyle(color: Colors.white)),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}