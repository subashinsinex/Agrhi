// Remove clipboard direction controls without removing meaningful name joiners.
String normalizeTextInput(String value) => value
    .replaceAll(
      RegExp(r'[\u200B\u200E\u200F\u202A-\u202E\u2060-\u206F\uFEFF\u061C]'),
      '',
    )
    .trim();
