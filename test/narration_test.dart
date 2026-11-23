import 'package:casegen/narration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Narration selects a high-quality installed voice in the chosen locale',
    () {
      final voices = [
        {
          'locale': 'es_ES',
          'name': 'Natural',
          'quality': 'enhanced',
          'identifier': 'es.1',
        },
        {
          'locale': 'es-ES',
          'name': 'Premium',
          'quality': 'premium',
          'identifier': 'es.2',
        },
        {'locale': 'en-US', 'name': 'Local', 'quality': 'normal'},
        {
          'locale': 'en-US',
          'name': 'Cloud',
          'quality': 'very high',
          'network_required': '1',
        },
        {
          'locale': 'en-US',
          'name': 'Download',
          'quality': 'high',
          'features': 'notInstalled',
        },
      ];
      expect(enhancedVoice(voices, 'es-ES')?['identifier'], 'es.2');
      expect(enhancedVoice(voices, 'en-US'), isNull);
    },
  );
}
