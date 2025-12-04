// lib/screens/features/add_crop_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../utils/colors.dart';
import '../../src/database/database_helper.dart';
import '../shared/widgets/custom_app_bar.dart';
import '../shared/widgets/smart_retranslator.dart';

class AddCropScreen extends StatefulWidget {
  final Map<String, dynamic>? crop;

  const AddCropScreen({super.key, this.crop});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fieldSizeController = TextEditingController();

  String? _selectedFarmId;
  String? _selectedPlantId;
  String? _selectedSoilTypeId;
  DateTime? _plantingDate;
  DateTime? _harvestDate;
  String _status = 'Planted';
  bool _isActive = true;

  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _plants = [];
  List<Map<String, dynamic>> _soilTypes = [];

  double _availableAcres = 0.0;
  double _totalFarmSize = 0.0;

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.crop != null;
    _loadReferenceData();
  }

  void _populateFormData() {
    final crop = widget.crop!;
    _selectedFarmId = crop['farmid']?.toString();
    _selectedPlantId = crop['plantid']?.toString();
    _selectedSoilTypeId = crop['soiltypeid']?.toString();
    _fieldSizeController.text = crop['fieldsize']?.toString() ?? '';
    _status = crop['status']?.toString() ?? 'Planted';
    _isActive = (crop['isactive'] == 1);

    if (crop['plantingdate'] != null) {
      _plantingDate = DateTime.tryParse(crop['plantingdate']);
    }
    if (crop['harvestdate'] != null) {
      _harvestDate = DateTime.tryParse(crop['harvestdate']);
    }

    // ✅ Load available acres after farms are loaded
    if (_selectedFarmId != null) {
      _loadAvailableAcres(_selectedFarmId!);
    }
  }

  Future<void> _loadReferenceData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final farms = await db.getAllFarms();
      final plants = await db.getAllPlants();
      final soilTypes = await db.getAllSoilTypes();

      setState(() {
        _farms = farms;
        _plants = plants;
        _soilTypes = soilTypes;
      });

      // ✅ Populate form data AFTER farms are loaded
      if (_isEditing) {
        _populateFormData();
      }
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

/// ✅ Load available acres excluding current crop in edit mode and inactive crops
  Future<void> _loadAvailableAcres(String farmId) async {
    try {
      final db = DatabaseHelper.instance;
      final farm = _farms.firstWhere((f) => f['farmid'].toString() == farmId);
      _totalFarmSize = (farm['farmsize'] ?? 0).toDouble();
      final allCrops = await db.getCropsByFarmId(farmId);
      double usedAcres = 0.0;
      for (final crop in allCrops) {
        if (_isEditing &&
            crop['usercropid'].toString() ==
                widget.crop!['usercropid'].toString()) {
          continue;
        }
        if (crop['isactive'] == 0) {
          continue;
        }
        usedAcres += (crop['fieldsize'] ?? 0).toDouble();
      }
      setState(() {
        _availableAcres = _totalFarmSize - usedAcres;
      });
    } catch (e) {
      debugPrint('❌ Error loading available acres: $e');
      setState(() {
        _availableAcres = 0.0;
      });
    }
  }

  Future<void> _saveCrop() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFarmId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: SmartReTranslator(text: 'Please select a farm'),
        ),
      );
      return;
    }

    if (_selectedPlantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: SmartReTranslator(text: 'Please select a plant'),
        ),
      );
      return;
    }

    if (_selectedSoilTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: SmartReTranslator(text: 'Please select a soil type'),
        ),
      );
      return;
    }

    if (_plantingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: SmartReTranslator(text: 'Please select a planting date'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper.instance;

      final cropId = _isEditing
          ? widget.crop!['usercropid'].toString()
          : const Uuid().v4();

      await db.upsertCrop(
        farmId: _selectedFarmId!,
        plantId: _selectedPlantId!,
        plantingDate: _plantingDate!.toIso8601String(),
        harvestDate: _harvestDate?.toIso8601String(),
        duration: null,
        fieldSize: double.parse(_fieldSizeController.text.trim()),
        soilTypeId: _selectedSoilTypeId!,
        status: _status,
        isActive: _isActive ? 1 : 0,
        cropId: cropId,
      );

      debugPrint('✅ Crop ${_isEditing ? "updated" : "created"}: $cropId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(
              text: _isEditing ? 'Crop updated' : 'Crop updated',
            ),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error saving crop: $e');
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

  Future<void> _deleteCrop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const SmartReTranslator(
          text: 'Delete Crop',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SmartReTranslator(
          text:
              'Are you sure you want to delete this crop? This action cannot be undone.',
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

      final result = await db.markCropAsDeleted(widget.crop!['usercropid']);

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
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting crop: $e');
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

  Future<void> _selectDate(BuildContext context, bool isPlanting) async {
    final initialDate = isPlanting
        ? (_plantingDate ?? DateTime.now())
        : (_harvestDate ?? DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primaryGreen),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        if (isPlanting) {
          _plantingDate = date;
        } else {
          _harvestDate = date;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _isEditing ? 'Edit Crop' : 'Add Crop',
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: _isLoading ? null : _deleteCrop,
                  tooltip: 'Delete Crop',
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
                  _buildSectionTitle('Farm & Plant Selection'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmartReTranslator(
                        text: 'Select Farm',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        label: null,
                        icon: Icons.agriculture,
                        value: _selectedFarmId,
                        items: _farms
                            .map(
                              (f) => {
                                'id': f['farmid']?.toString(),
                                'name':
                                    f['surveynumber']?.toString() ??
                                    'Farm ${f['farmid']}',
                              },
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedFarmId = value);
                          if (value != null) {
                            _loadAvailableAcres(value);
                          }
                        },
                        required: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmartReTranslator(
                        text: 'Select Plant/Crop',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        label: null,
                        icon: Icons.eco,
                        value: _selectedPlantId,
                        items: _plants
                            .map(
                              (p) => {
                                'id': p['plantid']?.toString(),
                                'name':
                                    p['plantname']?.toString() ??
                                    'Plant ${p['plantid']}',
                              },
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedPlantId = value),
                        required: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSectionTitle('Crop Details'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SmartReTranslator(
                            text: 'Field Size (Acres)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (_selectedFarmId != null)
                            SmartReTranslator(
                              text:
                                  'Available: ${_availableAcres.toStringAsFixed(2)} acres',
                              style: TextStyle(
                                fontSize: 12,
                                color: _availableAcres > 0
                                    ? AppColors.primaryGreen
                                    : AppColors.errorColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _fieldSizeController,
                        label: null,
                        icon: Icons.crop,
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
                            return 'Field size is required';
                          }
                          final size = double.tryParse(value);
                          if (size == null || size <= 0) {
                            return 'Enter a valid field size';
                          }
                          // ✅ Validate against available acres
                          if (_selectedFarmId != null &&
                              size > _availableAcres) {
                            return 'Exceeds available acres ($_availableAcres)';
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
                      const SmartReTranslator(
                        text: 'Planting Date *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildDateField(
                        label: null,
                        icon: Icons.calendar_today,
                        date: _plantingDate,
                        onTap: () => _selectDate(context, true),
                        required: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmartReTranslator(
                        text: 'Expected Harvest Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildDateField(
                        label: null,
                        icon: Icons.event_available,
                        date: _harvestDate,
                        onTap: () => _selectDate(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmartReTranslator(
                        text: 'Soil Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        label: null,
                        icon: Icons.terrain,
                        value: _selectedSoilTypeId,
                        items: _soilTypes
                            .map(
                              (s) => {
                                'id': s['soiltypeid']?.toString(),
                                'name': s['name']?.toString() ?? 'Unknown',
                              },
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedSoilTypeId = value),
                        required: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmartReTranslator(
                        text: 'Crop Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildStatusDropdown(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveCrop,
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.add,
                      color: Colors.white,
                    ),
                    label: SmartReTranslator(
                      text: _isEditing ? 'Update Crop' : 'Create Crop',
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

  Widget _buildDateField({
    required String? label,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
    bool required = false,
  }) {
    return InkWell(
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
            date != null
                ? Text(
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  )
                : const SmartReTranslator(
                    text: 'Select date',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? label,
    required IconData icon,
    required String? value,
    required List<Map<String, dynamic>> items,
    required void Function(String?) onChanged,
    bool required = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
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
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
      isExpanded: true,
      menuMaxHeight: 300,
      items: [
        if (!required)
          const DropdownMenuItem<String>(
            value: null,
            child: SmartReTranslator(
              text: 'Select...',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ...items.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: SmartReTranslator(
              text: item['name'] ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: onChanged,
      validator: required
          ? (value) => value == null ? 'This field is required' : null
          : null,
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      decoration: InputDecoration(
        alignLabelWithHint: true,
        prefixIcon: Icon(Icons.info_outline, color: AppColors.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
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
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
      isExpanded: true,
      menuMaxHeight: 200,
      items: const [
        DropdownMenuItem(
          value: 'Planted',
          child: SmartReTranslator(text: 'Planted'),
        ),
        DropdownMenuItem(
          value: 'Growing',
          child: SmartReTranslator(text: 'Growing'),
        ),
        DropdownMenuItem(
          value: 'Harvested',
          child: SmartReTranslator(text: 'Harvested'),
        ),
      ],
      onChanged: (value) => setState(() => _status = value!),
    );
  }

  @override
  void dispose() {
    _fieldSizeController.dispose();
    super.dispose();
  }
}
