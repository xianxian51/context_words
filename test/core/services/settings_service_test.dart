import 'package:context_words/core/services/settings_service.dart';
import 'package:context_words/models/deepseek_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DeepSeek model defaults to v4 pro', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final model = await SettingsService().getDeepSeekModel();

    expect(model, DeepSeekModel.highQuality);
    expect(model.apiName, 'deepseek-v4-pro');
  });

  test('DeepSeek v4 flash can be saved and restored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = SettingsService();

    await service.saveDeepSeekModel(DeepSeekModel.fast);

    expect(await service.getDeepSeekModel(), DeepSeekModel.fast);
  });
}
