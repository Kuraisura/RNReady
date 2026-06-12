import 'package:flutter/material.dart';

/// A focus area for AI-generated clinical cases. [focus] is injected into the
/// generation prompt to steer the scenario type. Categories are grounded in the
/// NCLEX/PNLE clinical-judgment question types.
class ClinicalCategory {
  final String id;
  final String label;
  final String blurb;
  final IconData icon;
  final Color color;
  final String focus; // instruction appended to the generator prompt

  const ClinicalCategory({
    required this.id,
    required this.label,
    required this.blurb,
    required this.icon,
    required this.color,
    required this.focus,
  });
}

const List<ClinicalCategory> kClinicalCategories = [
  ClinicalCategory(
    id: 'organ_function',
    label: 'Functions of an Organ',
    blurb: 'Normal physiology & what fails',
    icon: Icons.biotech_outlined,
    color: Color(0xFF38BDF8),
    focus:
        'Center the case on the NORMAL FUNCTION of a specific organ or body '
        'structure. Test whether the student understands what the organ does '
        'and the consequence when that function is impaired.',
  ),
  ClinicalCategory(
    id: 'accidents',
    label: 'Accidents & Emergencies',
    blurb: 'Trauma, burns, poisoning, falls',
    icon: Icons.emergency_outlined,
    color: Color(0xFFF87171),
    focus:
        'Make it an emergency/accident scenario (trauma, burns, poisoning, '
        'drowning, fractures, choking). Test immediate prioritization using '
        'ABCs and life-saving first actions.',
  ),
  ClinicalCategory(
    id: 'diseases',
    label: 'Diseases & Disorders',
    blurb: 'Pathophysiology & management',
    icon: Icons.coronavirus_outlined,
    color: Color(0xFFA78BFA),
    focus:
        'Base the case on a specific disease or disorder. Test recognition of '
        'its key manifestations and the priority nursing management.',
  ),
  ClinicalCategory(
    id: 'prioritization',
    label: 'Prioritization & Delegation',
    blurb: 'Who first? What to delegate?',
    icon: Icons.low_priority,
    color: Color(0xFF34D399),
    focus:
        'Present multiple clients or tasks. Test which client to see FIRST or '
        'which task is safe to delegate to a UAP/LPN, applying scope-of-'
        'practice and safety rules.',
  ),
  ClinicalCategory(
    id: 'pharmacology',
    label: 'Pharmacology',
    blurb: 'Drugs, safety, side effects',
    icon: Icons.medication_outlined,
    color: Color(0xFFEC4899),
    focus:
        'Base the case on a medication. Test safe administration, key side '
        'effects, contraindications, or whether the nurse should hold the drug '
        'and notify the provider.',
  ),
  ClinicalCategory(
    id: 'communication',
    label: 'Therapeutic Communication',
    blurb: 'The most therapeutic response',
    icon: Icons.forum_outlined,
    color: Color(0xFF22D3EE),
    focus:
        'Present a patient or family member expressing an emotion or concern. '
        'Test the MOST therapeutic nurse response (open-ended, empathetic, '
        'non-blocking).',
  ),
  ClinicalCategory(
    id: 'maternal_child',
    label: 'Maternal & Child',
    blurb: 'OB, newborn, pediatrics',
    icon: Icons.pregnant_woman_outlined,
    color: Color(0xFFFB7185),
    focus:
        'Make it an obstetric, newborn, or pediatric scenario. Test the '
        'priority assessment or intervention specific to that population.',
  ),
  ClinicalCategory(
    id: 'ethics_legal',
    label: 'Ethics & Legal',
    blurb: 'Consent, advocacy, negligence',
    icon: Icons.balance,
    color: Color(0xFFFBBF24),
    focus:
        'Base the case on an ethical/legal issue (informed consent, '
        'confidentiality, advocacy, negligence, advance directives). Test the '
        'legally and ethically correct action.',
  ),
  ClinicalCategory(
    id: 'diagnostics',
    label: 'Diagnostics & Labs',
    blurb: 'Interpret labs, vitals, results',
    icon: Icons.science_outlined,
    color: Color(0xFF60A5FA),
    focus:
        'Give an abnormal lab value, vital sign, or diagnostic result. Test '
        'interpretation and the appropriate nursing response to that finding.',
  ),
  ClinicalCategory(
    id: 'infection_control',
    label: 'Infection Control',
    blurb: 'Isolation, PPE, asepsis',
    icon: Icons.sanitizer_outlined,
    color: Color(0xFF2DD4BF),
    focus:
        'Base the case on infection control (isolation precautions, PPE, '
        'asepsis, transmission). Test the correct precaution or technique.',
  ),
  ClinicalCategory(
    id: 'random',
    label: 'Surprise Me',
    blurb: 'Any topic, fully random',
    icon: Icons.casino_outlined,
    color: Color(0xFF94A3B8),
    focus: '',
  ),
];
