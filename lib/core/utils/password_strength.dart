/// Port of src/utils/passwordStrength.js. Keep in sync with the server rules.
class PasswordRule {
  const PasswordRule(this.id, this.label, this.met);
  final String id;
  final String label;
  final bool met;
}

class PasswordEvaluation {
  const PasswordEvaluation(this.rules, this.isValid, this.score, this.bars, this.label);
  final List<PasswordRule> rules;
  final bool isValid;
  final int score;
  final int bars;
  final String label;
}

final _upper = RegExp(r'\p{Lu}', unicode: true);
final _lower = RegExp(r'\p{Ll}', unicode: true);
final _digit = RegExp(r'\d');
final _special = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

const _barsByScore = [0, 1, 1, 2, 3, 4];
const _labelByScore = ['', 'Weak', 'Weak', 'Fair', 'Good', 'Strong'];

PasswordEvaluation evaluatePassword([String password = '']) {
  final rules = [
    PasswordRule('length', 'At least 8 characters', password.length >= 8),
    PasswordRule('upper', 'Contains uppercase letter', _upper.hasMatch(password)),
    PasswordRule('lower', 'Contains lowercase letter', _lower.hasMatch(password)),
    PasswordRule('number', 'Contains a number', _digit.hasMatch(password)),
    PasswordRule('special', 'Contains special character', _special.hasMatch(password)),
  ];
  final metCount = rules.where((r) => r.met).length;

  // Under 8 characters can never rate better than "Weak".
  var score = metCount;
  if (!rules[0].met && score > 2) score = 2;
  if (password.isEmpty) score = 0;

  return PasswordEvaluation(
    rules,
    metCount == rules.length,
    score,
    _barsByScore[score],
    _labelByScore[score],
  );
}
