import 'package:hive_flutter/hive_flutter.dart';

class SaveSessionService {
	static const String boxName = 'savedSessionsBox';

	String defaultSessionName() {
		final now = DateTime.now();
		final mm = now.month.toString().padLeft(2, '0');
		final dd = now.day.toString().padLeft(2, '0');
		final yy = (now.year % 100).toString().padLeft(2, '0');
		return '${mm}_${dd}_$yy';
	}

	Future<void> saveSessionShell({required String name}) async {
		final String trimmedName = name.trim().isEmpty ? defaultSessionName() : name.trim();

		final box = Hive.isBoxOpen(boxName)
				? Hive.box(boxName)
				: await Hive.openBox(boxName);

		final Map<String, dynamic> row = {
			'name': trimmedName,
			'start_time': null,
			'end_time': null,
			'max_bite_force': null,
			'max_mouth_opening': null,
			'strain_gauge_01_max': null,
			'strain_gauge_02_max': null,
			'strain_gauge_03_max': null,
			'strain_gauge_04_max': null,
			'strain_gauge_05_max': null,
			'strain_gauge_06_max': null,
			'strain_gauge_07_max': null,
			'strain_gauge_08_max': null,
			'strain_gauge_09_max': null,
			'strain_gauge_10_max': null,
			'strain_gauge_11_max': null,
			'strain_gauge_12_max': null,
			'strain_gauge_13_max': null,
			'strain_gauge_14_max': null,
			'strain_gauge_15_max': null,
			'strain_gauge_16_max': null,
			'strain_gauge_17_max': null,
			'strain_gauge_18_max': null,
			'strain_gauge_19_max': null,
			'strain_gauge_20_max': null,
		};

		await box.add(row);
	}
}
