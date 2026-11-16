import 'package:supabase_flutter/supabase_flutter.dart';

class ContributionCounts {
  const ContributionCounts({
    required this.vacancyCount,
    required this.leavingCount,
  });

  final int vacancyCount;
  final int leavingCount;

  factory ContributionCounts.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid contribution counts response.');
    }
    final json = Map<String, dynamic>.from(value);
    final vacancy = json['vacancy_count'];
    final leaving = json['leaving_count'];
    if (vacancy is! num ||
        leaving is! num ||
        vacancy < 0 ||
        leaving < 0 ||
        vacancy.toInt() != vacancy ||
        leaving.toInt() != leaving) {
      throw const FormatException('Invalid contribution counts.');
    }
    return ContributionCounts(
      vacancyCount: vacancy.toInt(),
      leavingCount: leaving.toInt(),
    );
  }
}

class ContributionSummaryRepository {
  ContributionSummaryRepository(this._client);

  final SupabaseClient _client;

  Future<ContributionCounts> fetch() async {
    final response = await _client.rpc('get_my_parking_report_counts');
    return ContributionCounts.fromJson(response);
  }
}
