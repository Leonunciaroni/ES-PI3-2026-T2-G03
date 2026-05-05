// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Mapeia um objeto do array `socios` do Firestore (campos em português / prints) para
// [SocioDetailViewData].

import 'package:flutter/material.dart';

import '../data/startup_detail_mock.dart'
    show SocioDetailViewData, StartupTeamMember, socioDetailForTeamMember;
import 'startup_detail_document.dart';

/// Monta a ficha do sócio a partir do mapa tal como vem do Firestore (chaves da print).
SocioDetailViewData socioDetailViewDataFromFirestoreSocioMap(
  Map<String, dynamic> f,
  Color avatarColor,
) {
  String? pickSingle(List<String> keys) {
    for (final String k in keys) {
      final Object? v = f[k];
      if (v == null) {
        continue;
      }
      final String s = v.toString().trim();
      if (s.isNotEmpty) {
        return s;
      }
    }
    return null;
  }

  List<String> splitList(String? s) {
    if (s == null || s.trim().isEmpty) {
      return <String>[];
    }
    return s
        .split(RegExp(r'[,;]\s*'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  final String name = pickSingle(<String>['Nome', 'nome', 'name']) ?? '';
  final String cargo = pickSingle(<String>['Cargo', 'cargo']) ?? '';
  final String pct = socioParticipacaoParaExibicao(f);
  final String participationLabel = pct.isEmpty
      ? 'Participação societária em definição.'
      : '$pct de participação societária';

  final Object? espRaw = f['Especialidades'] ?? f['Especialidade'];
  List<String> specialties = <String>[];
  if (espRaw is List) {
    specialties = espRaw
        .map((Object? e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  } else if (espRaw is String) {
    specialties = splitList(espRaw);
  }

  final String? hab = pickSingle(<String>['Habilidades', 'habilidades']);
  final List<String> skills = hab != null ? splitList(hab) : <String>[];

  final String? expPrev = pickSingle(<String>[
    'Experiência anteriores',
    'Experiência anterior',
    'experiencia_anteriores',
  ]);
  final List<String> priorRoles =
      expPrev != null && expPrev.isNotEmpty ? <String>[expPrev] : <String>[];

  final Object? tempoRaw = f['Tempo de experiência no mercado'];
  final String? marketExperience = tempoRaw == null
      ? null
      : (tempoRaw is num
          ? '${tempoRaw.round()} anos no mercado.'
          : tempoRaw.toString().trim());

  return SocioDetailViewData(
    fullName: name.isEmpty ? '—' : name,
    listRoleLine: cargo.isNotEmpty ? cargo : 'Sócio',
    participationLabel: participationLabel,
    avatarFallbackColor: avatarColor,
    shortBio: pickSingle(<String>[
      'Mini Biografia Profissional',
      'mini_biografia',
      'bio',
    ]),
    linkedinUrl: pickSingle(<String>['LinkedIn', 'linkedin', 'linkedin_url']),
    academicBackground: pickSingle(<String>[
      'Formação Acadêmica',
      'Formacao Academica',
      'formacao',
    ]),
    specialties: specialties,
    marketExperience: marketExperience,
    priorRoles: priorRoles,
    skills: skills,
    strategicEdge: pickSingle(<String>['Diferencial', 'diferencial']),
    responsibilities: pickSingle(<String>[
      'Responsabilidades na Startup',
      'Responsabilidades na startup',
      'responsabilidades',
    ]),
    highlights: const <String>[],
    certifications: const <String>[],
    languages: splitList(pickSingle(<String>['Idiomas', 'idiomas'])),
    isMockPlaceholder: false,
  );
}

/// Ordem: mock rico ([StartupTeamMember.detailPreview]) → objeto Firestore `socios[]` → placeholder do PI.
SocioDetailViewData resolveSocioDetailForTeamMember(StartupTeamMember member) {
  if (member.detailPreview != null) {
    return member.detailPreview!;
  }
  if (member.firestoreFields != null && member.firestoreFields!.isNotEmpty) {
    return socioDetailViewDataFromFirestoreSocioMap(
      member.firestoreFields!,
      member.avatarColor,
    );
  }
  return socioDetailForTeamMember(member);
}
