import 'package:flutter/material.dart';
import 'package:chat_with_doc/src/app/models/users.dart';
import 'package:chat_with_doc/src/app/pages/doctor_dashboard_page.dart';
import 'package:chat_with_doc/src/app/services/app_storage.dart';

class ConsultantRegistrationPage extends StatefulWidget {
  const ConsultantRegistrationPage({super.key});

  @override
  State<ConsultantRegistrationPage> createState() =>
      _ConsultantRegistrationPageState();
}

class _ConsultantRegistrationPageState
    extends State<ConsultantRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _slmcController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _experienceController = TextEditingController();
  final _degreeController = TextEditingController();
  final _universityController = TextEditingController();
  final _graduationYearController = TextEditingController();
  final _feeController = TextEditingController(text: '45');
  final _aboutController = TextEditingController();
  final List<String> _selectedLanguages = ['English'];
  String? _selectedSpecialization;
  bool _agreedToTerms = false;

  static const specializations = [
    'General Practice',
    'Cardiology',
    'Dermatology',
    'Endocrinology',
    'Gastroenterology',
    'Neurology',
    'Obstetrics & Gynecology',
    'Ophthalmology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Pulmonology',
    'Radiology',
    'Surgery',
    'Urology',
  ];
  static const languages = ['Sinhala', 'Tamil', 'English'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _slmcController.dispose();
    _hospitalController.dispose();
    _experienceController.dispose();
    _degreeController.dispose();
    _universityController.dispose();
    _graduationYearController.dispose();
    _feeController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _toggleLanguage(String language) {
    setState(() {
      if (_selectedLanguages.contains(language)) {
        _selectedLanguages.remove(language);
      } else {
        _selectedLanguages.add(language);
      }
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpecialization == null || _selectedSpecialization!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your specialization')),
      );
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and conditions'),
        ),
      );
      return;
    }
    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one language')),
      );
      return;
    }
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    final fee = double.tryParse(_feeController.text.trim()) ?? 45.0;
    final experience = int.tryParse(_experienceController.text.trim()) ?? 0;
    final gradYear = int.tryParse(_graduationYearController.text.trim()) ?? 0;

    final consultant = ConsultantUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: password,
      phone: _phoneController.text.trim(),
      slmcNumber: _slmcController.text.trim(),
      specialization: _selectedSpecialization!,
      hospital: _hospitalController.text.trim(),
      experienceYears: experience,
      degree: _degreeController.text.trim(),
      university: _universityController.text.trim(),
      graduationYear: gradYear,
      consultationFee: fee,
      about: _aboutController.text.trim(),
      languages: List.from(_selectedLanguages),
      status: 'pending',
      walletBalance: 125,
    );
    AppStorage.registerConsultant(consultant);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DoctorDashboardPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Consultant Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register as a Consultant',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submit your details to join the consultation platform and access your dashboard.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTwoColumn(
                          left: _buildTextField(
                            _nameController,
                            'Full Name',
                            true,
                          ),
                          right: _buildTextField(
                            _phoneController,
                            'Phone Number',
                            true,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _emailController,
                          'Email',
                          true,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _buildTwoColumn(
                          left: _buildTextField(
                            _passwordController,
                            'Password',
                            true,
                            obscureText: true,
                          ),
                          right: _buildTextField(
                            _confirmPasswordController,
                            'Confirm Password',
                            true,
                            obscureText: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Professional Details'),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _slmcController,
                          'SLMC Registration Number',
                          true,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: _buildInputDecoration('Specialization'),
                          value: _selectedSpecialization,
                          items: specializations
                              .map(
                                (specialization) => DropdownMenuItem(
                                  value: specialization,
                                  child: Text(specialization),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedSpecialization = value),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Select your specialization'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTwoColumn(
                          left: _buildTextField(
                            _hospitalController,
                            'Hospital / Clinic',
                            false,
                          ),
                          right: _buildTextField(
                            _experienceController,
                            'Experience (years)',
                            false,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _feeController,
                          'Consultation Fee',
                          false,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Academic Qualifications'),
                        const SizedBox(height: 12),
                        _buildTwoColumn(
                          left: _buildTextField(
                            _degreeController,
                            'Degree',
                            true,
                          ),
                          right: _buildTextField(
                            _universityController,
                            'University',
                            false,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _graduationYearController,
                          'Graduation Year',
                          false,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('About Yourself'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _aboutController,
                          maxLines: 4,
                          decoration: _buildInputDecoration(
                            'Professional Summary',
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Tell us about your experience'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Languages Spoken'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: languages.map((language) {
                            final selected = _selectedLanguages.contains(
                              language,
                            );
                            return FilterChip(
                              label: Text(language),
                              selected: selected,
                              onSelected: (_) => _toggleLanguage(language),
                              selectedColor: Colors.blue.shade100,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        CheckboxListTile(
                          title: const Text(
                            'I agree to the terms and conditions',
                          ),
                          value: _agreedToTerms,
                          onChanged: (value) =>
                              setState(() => _agreedToTerms = value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue.shade700,
                            ),
                            child: const Text('Submit Registration Request'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTwoColumn({required Widget left, required Widget right}) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    bool required, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: _buildInputDecoration(label),
      validator: required
          ? (value) => value == null || value.isEmpty ? 'Enter $label' : null
          : null,
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFEFF6FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}
