// lib/screens/features/add_farm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/colors.dart';
import '../../../src/database/database_helper.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';

class AddFarmScreen extends StatefulWidget {
  final Map<String, dynamic>? farm;

  const AddFarmScreen({super.key, this.farm});

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _surveyNumberController = TextEditingController();
  final _farmSizeController = TextEditingController();

  List<String> _selectedSoilTypeIds = [];
  List<String> _selectedIrrigationIds = [];
  List<String> _selectedWaterSourceIds = [];

  List<Map<String, dynamic>> _soilTypes = [];
  List<Map<String, dynamic>> _irrigationTypes = [];
  List<Map<String, dynamic>> _waterSources = [];

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.farm != null;
    _loadReferenceData();

    if (_isEditing) {
      _populateFormData();
    }
  }

  Future<void> _populateFormData() async {
    final farm = widget.farm!;
    _surveyNumberController.text = farm['surveynumber']?.toString() ?? '';
    _farmSizeController.text = farm['farmsize']?.toString() ?? '';

    final db = DatabaseHelper.instance;
    final farmWithRelations = await db.getFarmWithRelations(farm['farmid']);

    if (farmWithRelations != null && mounted) {
      setState(() {
        _selectedSoilTypeIds = List<String>.from(
          farmWithRelations['soil_type_ids'] ?? [],
        );
        _selectedIrrigationIds = List<String>.from(
          farmWithRelations['irrigation_ids'] ?? [],
        );
        _selectedWaterSourceIds = List<String>.from(
          farmWithRelations['water_source_ids'] ?? [],
        );
      });
    }
  }

  Future<void> _loadReferenceData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final soilTypes = await db.getAllSoilTypes();
      final irrigationTypes = await db.getAllIrrigationTypes();
      final waterSources = await db.getAllWaterSources();

      setState(() {
        _soilTypes = soilTypes;
        _irrigationTypes = irrigationTypes;
        _waterSources = waterSources;
      });
    } catch (e) {
      debugPrint('❌ Error loading reference data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(text: 'Error loading data: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final farmId = _isEditing ? widget.farm!['farmid'].toString() : null;

      await db.upsertFarmWithRelations(
        farmSize: double.parse(_farmSizeController.text.trim()),
        surveyNumber: _surveyNumberController.text.trim(),
        soilTypeIds: _selectedSoilTypeIds,
        irrigationIds: _selectedIrrigationIds,
        waterSrcIds: _selectedWaterSourceIds,
        farmId: farmId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(
              text: _isEditing ? 'Farm updated' : 'Farm created',
            ),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error saving farm: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(text: 'Error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFarm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const SmartReTranslator(
          text: 'Delete Farm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SmartReTranslator(
          text:
              'Are you sure you want to delete this farm? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const SmartReTranslator(text: 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorColor),
            child: const SmartReTranslator(text: 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final result = await db.markFarmAsDeleted(widget.farm!['farmid']);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SmartReTranslator(text: result['message']),
              backgroundColor: AppColors.successColor,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SmartReTranslator(text: result['message']),
              backgroundColor: AppColors.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting farm: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(text: 'Error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMultiSelectDialog({
    required String title,
    required List<Map<String, dynamic>> items,
    required List<String> selectedIds,
    required Function(List<String>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(selectedIds);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: SmartReTranslator(text: title),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id =
                        item['soiltypeid']?.toString() ??
                        item['irrigationid']?.toString() ??
                        item['watersrcid']?.toString() ??
                        '';
                    final name =
                        item['name']?.toString() ??
                        item['methodname']?.toString() ??
                        item['source']?.toString() ??
                        'Unknown';
                    final isSelected = tempSelected.contains(id);

                    return CheckboxListTile(
                      title: SmartReTranslator(text: name),
                      value: isSelected,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(id);
                          } else {
                            tempSelected.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const SmartReTranslator(text: 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSelected);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const SmartReTranslator(
                    text: 'Confirm',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getSelectedNames(
    List<String> selectedIds,
    List<Map<String, dynamic>> items,
  ) {
    if (selectedIds.isEmpty) return 'None selected';

    final names = selectedIds.map((id) {
      final item = items.firstWhere(
        (item) =>
            (item['soiltypeid']?.toString() ??
                item['irrigationid']?.toString() ??
                item['watersrcid']?.toString()) ==
            id,
        orElse: () => {},
      );
      return item['name']?.toString() ??
          item['methodname']?.toString() ??
          item['source']?.toString() ??
          'Unknown';
    }).toList();

    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showOnlineStatus: true,
        title: _isEditing ? 'Edit Farm' : 'Add Farm',
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: _isLoading ? null : _deleteFarm,
                  tooltip: 'Delete Farm',
                ),
              ]
            : null,
      ),
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Farm Details'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartReTranslator(
                        text: 'Survey Number',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _surveyNumberController,
                        label: null,
                        icon: Icons.numbers,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Survey number is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartReTranslator(
                        text: 'Farm Size (Acres)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _farmSizeController,
                        label: null,
                        icon: Icons.landscape,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Farm size is required';
                          }
                          final size = double.tryParse(value);
                          if (size == null || size <= 0) {
                            return 'Enter a valid farm size';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSectionTitle('Farm Characteristics'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartReTranslator(
                        text: 'Soil Types',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildMultiSelectField(
                        label: null,
                        icon: Icons.terrain,
                        selectedCount: _selectedSoilTypeIds.length,
                        selectedText: _getSelectedNames(
                          _selectedSoilTypeIds,
                          _soilTypes,
                        ),
                        onTap: () => _showMultiSelectDialog(
                          title: 'Select Soil Types',
                          items: _soilTypes,
                          selectedIds: _selectedSoilTypeIds,
                          onConfirm: (selected) {
                            setState(() => _selectedSoilTypeIds = selected);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartReTranslator(
                        text: 'Irrigation Methods',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildMultiSelectField(
                        label: null,
                        icon: Icons.water_drop,
                        selectedCount: _selectedIrrigationIds.length,
                        selectedText: _getSelectedNames(
                          _selectedIrrigationIds,
                          _irrigationTypes,
                        ),
                        onTap: () => _showMultiSelectDialog(
                          title: 'Select Irrigation Methods',
                          items: _irrigationTypes,
                          selectedIds: _selectedIrrigationIds,
                          onConfirm: (selected) {
                            setState(() => _selectedIrrigationIds = selected);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartReTranslator(
                        text: 'Water Sources',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildMultiSelectField(
                        label: null,
                        icon: Icons.water,
                        selectedCount: _selectedWaterSourceIds.length,
                        selectedText: _getSelectedNames(
                          _selectedWaterSourceIds,
                          _waterSources,
                        ),
                        onTap: () => _showMultiSelectDialog(
                          title: 'Select Water Sources',
                          items: _waterSources,
                          selectedIds: _selectedWaterSourceIds,
                          onConfirm: (selected) {
                            setState(() => _selectedWaterSourceIds = selected);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveFarm,
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.add,
                      color: Colors.white,
                    ),
                    label: SmartReTranslator(
                      text: _isEditing ? 'Update Farm' : 'Create Farm',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SmartReTranslator(
          text: title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String? label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.errorColor),
        ),
      ),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildMultiSelectField({
    required String? label,
    required IconData icon,
    required int selectedCount,
    required String selectedText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          prefixIcon: Icon(icon, color: AppColors.primaryGreen),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SmartReTranslator(
                text: selectedText.isEmpty ? 'None selected' : selectedText,
                style: TextStyle(
                  color: selectedText.isEmpty ? Colors.grey : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _surveyNumberController.dispose();
    _farmSizeController.dispose();
    super.dispose();
  }
}
