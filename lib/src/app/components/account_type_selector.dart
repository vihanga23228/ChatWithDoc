import 'package:flutter/material.dart';

enum AccountType { patient, consultant }

class AccountTypeSelector extends StatelessWidget {
  final AccountType selectedType;
  final ValueChanged<AccountType> onChanged;

  const AccountTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  Widget _buildOption(BuildContext context, AccountType type, String label) {
    final isSelected = selectedType == type;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFE0E7FF),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                type == AccountType.patient
                    ? Icons.person_outline
                    : Icons.medical_services,
                size: 28,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildOption(context, AccountType.patient, 'Patient'),
        const SizedBox(width: 12),
        _buildOption(context, AccountType.consultant, 'Consultant'),
      ],
    );
  }
}
