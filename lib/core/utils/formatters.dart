import 'package:intl/intl.dart';

class Fmt {
  const Fmt._();

  static final NumberFormat _moneyFormat = NumberFormat.decimalPattern('fr_FR');

  static const List<String> _months = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static String money(num? value) {
    final double amount = (value ?? 0).toDouble();
    return '${_moneyFormat.format(amount.round())} XAF';
  }

  static String number(num? value) => _moneyFormat.format(value ?? 0);

  static DateTime? parseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.trim())?.toLocal();
  }

  static String date(String? value, {String fallback = '—'}) {
    final DateTime? parsed = parseDate(value);
    if (parsed == null) {
      return fallback;
    }
    return '${_two(parsed.day)}/${_two(parsed.month)}/${parsed.year}';
  }

  static String dateTime(String? value, {String fallback = '—'}) {
    final DateTime? parsed = parseDate(value);
    if (parsed == null) {
      return fallback;
    }
    return '${_two(parsed.day)}/${_two(parsed.month)}/${parsed.year} '
        'à ${_two(parsed.hour)}:${_two(parsed.minute)}';
  }

  static String longDate(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  static String relative(String? value) {
    final DateTime? parsed = parseDate(value);
    if (parsed == null) {
      return '—';
    }
    final Duration diff = DateTime.now().difference(parsed);
    if (diff.inSeconds < 60) {
      return "à l'instant";
    }
    if (diff.inMinutes < 60) {
      return 'il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'il y a ${diff.inHours} h';
    }
    if (diff.inDays < 30) {
      return 'il y a ${diff.inDays} j';
    }
    return date(value);
  }

  static String initials(String value) {
    final List<String> parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static String profileLabel(String profile) {
    switch (profile) {
      case 'finder':
        return 'Trouveur';
      case 'owner':
        return 'Propriétaire';
      case 'admin':
        return 'Administrateur';
      default:
        return profile;
    }
  }

  static const Map<String, String> documentTypes = <String, String>{
    'CNI': "Carte nationale d'identité",
    'PASSEPORT': 'Passeport',
    'PERMIS': 'Permis de conduire',
    'CARTE_VITALE': 'Carte vitale',
    'CARTE_ETUDIANT': 'Carte étudiante',
    'CARTE_SEJOUR': 'Carte de séjour',
    'ACTE_NAISSANCE': 'Acte de naissance',
    'AUTRE': 'Autre document',
  };

  static String docType(String code) => documentTypes[code] ?? code;

  static String lossStatus(String status) {
    switch (status) {
      case 'inactive':
        return 'Perdu';
      case 'declared':
        return 'Déclaré';
      case 'pending':
        return 'En attente';
      case 'matched':
        return 'Correspondance';
      case 'returned':
        return 'Restitué';
      default:
        return status;
    }
  }

  static String findStatus(String status) {
    switch (status) {
      case 'found':
        return 'Retrouvé';
      case 'pending':
        return 'En attente';
      case 'matched':
        return 'Correspondance';
      case 'returned':
        return 'Restitué';
      default:
        return status;
    }
  }

  static String rewardStatus(String status) {
    switch (status) {
      case 'none':
        return 'Aucune récompense';
      case 'escrow':
        return 'Séquestrée';
      case 'released':
        return 'Libérée';
      case 'refunded':
        return 'Remboursée';
      default:
        return status;
    }
  }

  static String two(int value) => _two(value);

  static String _two(int value) => value.toString().padLeft(2, '0');
}
