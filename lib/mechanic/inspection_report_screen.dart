import 'package:flutter/material.dart';
import '../services/mechanic_service.dart';

class InspectionReportScreen extends StatefulWidget {
  final String jobId;

  const InspectionReportScreen({super.key, required this.jobId});

  @override
  State<InspectionReportScreen> createState() => _InspectionReportScreenState();
}

class _InspectionReportScreenState extends State<InspectionReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemDescriptionController = TextEditingController();
  final _recommendedSolutionController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedProblemType = 'engine';
  String _selectedUrgency = 'medium';
  bool _requiresReplacement = false;
  
  final List<String> _problemTypes = [
    'engine',
    'transmission',
    'brakes',
    'tires',
    'electrical',
    'cooling',
    'fuel',
    'exhaust',
    'suspension',
    'other'
  ];

  final List<String> _urgencyLevels = [
    'low',
    'medium',
    'high',
    'critical'
  ];

  @override
  void dispose() {
    _problemDescriptionController.dispose();
    _recommendedSolutionController.dispose();
    _estimatedCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final report = {
        'problem_type': _selectedProblemType,
        'problem_description': _problemDescriptionController.text.trim(),
        'recommended_solution': _recommendedSolutionController.text.trim(),
        'estimated_price': double.tryParse(_estimatedCostController.text.trim()) ?? 0.0,
        'urgency': _selectedUrgency,
        'requires_replacement': _requiresReplacement,
        'notes': _notesController.text.trim(),
        'inspection_date': DateTime.now().toUtc().toIso8601String(),
      };

      await MechanicService.instance.submitInspectionReport(widget.jobId, report);
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection report submitted successfully'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 176, 12, 1),
        title: const Text(
          'Inspection Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 176, 12, 1).withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color.fromARGB(255, 176, 12, 1).withAlpha(51)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Inspection Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please provide a detailed inspection report for Job #${widget.jobId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Problem Type
              const Text(
                'Problem Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedProblemType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _problemTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProblemType = value!;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Problem Description
              const Text(
                'Problem Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _problemDescriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe the problem in detail...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe the problem';
                  }
                  if (value.length < 10) {
                    return 'Please provide a more detailed description';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Recommended Solution
              const Text(
                'Recommended Solution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _recommendedSolutionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Recommended repair or solution...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide a recommended solution';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Estimated Cost
              const Text(
                'Estimated Cost (\$)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _estimatedCostController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter estimated cost',
                  prefixText: '\$',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter estimated cost';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) < 0) {
                    return 'Cost cannot be negative';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Urgency Level
              const Text(
                'Urgency Level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedUrgency,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _urgencyLevels.map((urgency) {
                  Color urgencyColor;
                  switch (urgency) {
                    case 'critical':
                      urgencyColor = Colors.red;
                      break;
                    case 'high':
                      urgencyColor = Colors.orange;
                      break;
                    case 'medium':
                      urgencyColor = Colors.yellow[700]!;
                      break;
                    default:
                      urgencyColor = Colors.red;
                  }
                  
                  return DropdownMenuItem(
                    value: urgency,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: urgencyColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(urgency.toUpperCase()),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUrgency = value!;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Requires Replacement Checkbox
              CheckboxListTile(
                title: const Text('Requires Part Replacement'),
                value: _requiresReplacement,
                onChanged: (value) {
                  setState(() {
                    _requiresReplacement = value ?? false;
                  });
                },
                activeColor: Colors.orange,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 16),
              
              // Additional Notes
              const Text(
                'Additional Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any additional notes or observations...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Inspection Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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










