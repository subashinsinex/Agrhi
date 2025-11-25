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
  final _durationController = TextEditingController();

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

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.crop != null;
    _loadReferenceData();

    if (_isEditing) {
      _populateFormData();
    }
  }

  void _populateFormData() {
    final crop = widget.crop!;
    _selectedFarmId = crop['farmid']?.toString();
    _selectedPlantId = crop['plantid']?.toString();
    _selectedSoilTypeId = crop['soiltypeid']?.toString();
    _fieldSizeController.text = crop['fieldsize']?.toString() ?? '';
    _durationController.text = crop['duration']?.toString() ?? '';
    _status = crop['status']?.toString() ?? 'Planted';
    _isActive = (crop['isactive'] == 1);

    if (crop['plantingdate'] != null) {
      _plantingDate = DateTime.tryParse(crop['plantingdate']);
    }
    if (crop['harvestdate'] != null) {
      _harvestDate = DateTime.tryParse(crop['harvestdate']);
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
    } catch (e) {
      debugPrint('❌ Error loading reference data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error loading data: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCrop() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFarmId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a farm')));
      return;
    }

    if (_selectedPlantId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a plant')));
      return;
    }

    if (_selectedSoilTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a soil type')),
      );
      return;
    }

    if (_plantingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a planting date')),
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
        duration: _durationController.text.isNotEmpty
            ? double.parse(_durationController.text.trim())
            : null,
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
            content: Text(_isEditing ? '✅ Crop updated' : '✅ Crop created'),
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
            content: Text('❌ Error: $e'),
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
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'usercrops',
        where: 'usercropid = ?',
        whereArgs: [widget.crop!['usercropid']],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Crop deleted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error deleting crop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
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
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Select Farm',
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
                    onChanged: (value) =>
                        setState(() => _selectedFarmId = value),
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Select Plant/Crop',
                    icon: Icons.eco,
                    value: _selectedPlantId,
                    items: _plants
                        .map(
                          (p) => {
                            'id': p['plantid']
                                ?.toString(), // ✅ Fixed: plantid not plant_id
                            'name':
                                p['plantname']
                                    ?.toString() ?? // ✅ Fixed: plantname not plant_name
                                'Plant ${p['plantid']}',
                          },
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedPlantId = value),
                    required: true,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Crop Details'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _fieldSizeController,
                    label: 'Field Size (Acres)',
                    icon: Icons.crop,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Field size is required';
                      }
                      final size = double.tryParse(value);
                      if (size == null || size <= 0) {
                        return 'Enter a valid field size';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(
                    label: 'Planting Date *',
                    icon: Icons.calendar_today,
                    date: _plantingDate,
                    onTap: () => _selectDate(context, true),
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(
                    label: 'Expected Harvest Date',
                    icon: Icons.event_available,
                    date: _harvestDate,
                    onTap: () => _selectDate(context, false),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _durationController,
                    label: 'Growth Duration (days)',
                    icon: Icons.timer,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Soil Type',
                    icon: Icons.terrain,
                    value: _selectedSoilTypeId,
                    items: _soilTypes
                        .map(
                          (s) => {
                            'id': s['soiltypeid']
                                ?.toString(), // ✅ Fixed: soiltypeid not soil_type_id
                            'name': s['name']?.toString() ?? 'Unknown',
                          },
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSoilTypeId = value),
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildStatusDropdown(),
                  const SizedBox(height: 16),
                  _buildActiveSwitch(),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveCrop,
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.add,
                      color: Colors.white,
                    ),
                    label: SmartReTranslator(
                      text: _isEditing ? 'Update Crop' : 'Create Crop',
                      style: const TextStyle(
                        fontSize: 16,
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
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
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
    required String label,
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
          errorBorder: required && date == null
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.errorColor),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null
                  ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                  : 'Select date',
              style: TextStyle(
                color: date != null ? Colors.black87 : Colors.grey,
                fontSize: 16,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
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
      items: [
        if (!required)
          const DropdownMenuItem<String>(value: null, child: Text('Select...')),
        ...items.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(item['name'] ?? 'Unknown'),
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
        labelText: 'Crop Status',
        prefixIcon: Icon(Icons.info_outline, color: AppColors.primaryGreen),
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
      items: const [
        DropdownMenuItem(value: 'Planted', child: Text('Planted')),
        DropdownMenuItem(value: 'Growing', child: Text('Growing')),
        DropdownMenuItem(value: 'Harvested', child: Text('Harvested')),
      ],
      onChanged: (value) => setState(() => _status = value!),
    );
  }

  Widget _buildActiveSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.toggle_on, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Active Crop', style: TextStyle(fontSize: 16)),
          ),
          Switch(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fieldSizeController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
