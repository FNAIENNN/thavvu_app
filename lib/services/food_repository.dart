import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food_models.dart';

/// Supabase-backed repository for the food module.
///
/// Attendance writes `food_requests` (who needs food); this repository
/// lets the food screen read them, submit daily counts to
/// `food_submissions`, and lets HODs read/approve submissions.
class FoodRepository {
  FoodRepository({SupabaseClient? client}) : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first query.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const _requestsTable = 'food_requests';
  static const _submissionsTable = 'food_submissions';

  // ==========================================================
  // FOOD REQUESTS (written by attendance, consumed by food screen)
  // ==========================================================

  /// Replace today's pending requests with the fresh set derived from
  /// attendance. Deletes pending rows for the day, then inserts the new
  /// set — keeping the food list perfectly in sync with attendance.
  Future<bool> syncFoodRequests(
    DateTime day, {
    required String siteId,
    required List<FoodRequest> requests,
  }) async {
    try {
      final date = _dateOnly(day);
      await _client
          .from(_requestsTable)
          .delete()
          .eq('attendance_date', date)
          .eq('status', 'pending');

      if (requests.isNotEmpty) {
        final rows = requests
            .map((r) => r.toJson()
              ..['site_id'] = siteId
              ..['attendance_date'] = date)
            .toList();
        await _client.from(_requestsTable).insert(rows);
      }
      return true;
    } catch (e) {
      debugPrint('Error syncing food requests: $e');
      return false;
    }
  }

  /// Fetch pending (not yet submitted) food requests for a day.
  Future<List<FoodRequest>> fetchPendingRequests(
    DateTime day, {
    String? siteId,
  }) async {
    try {
      var query = _client
          .from(_requestsTable)
          .select()
          .eq('attendance_date', _dateOnly(day))
          .eq('status', 'pending');
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response = await query.order('category', ascending: true);
      return (response as List)
          .map((json) => FoodRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending food requests: $e');
      return [];
    }
  }

  /// Mark a request as submitted (after the daily food submission).
  Future<bool> markRequestSubmitted(String requestId) async {
    try {
      await _client
          .from(_requestsTable)
          .update({'status': 'submitted'}).eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('Error marking food request submitted: $e');
      return false;
    }
  }

  // ==========================================================
  // FOOD SUBMISSIONS (supervisor → HOD)
  // ==========================================================

  /// Insert (or update) the daily food submission. The DB enforces one
  /// submission per site/date/submitted_by via a unique constraint, so
  /// re-submitting replaces the supervisor's earlier submission.
  Future<FoodSubmission?> submitFood(FoodSubmission submission) async {
    try {
      final json = submission.toJson();
      final response = await _client
          .from(_submissionsTable)
          .upsert(json, onConflict: 'site_id,attendance_date,submitted_by')
          .select()
          .single();
      return FoodSubmission.fromJson(response);
    } catch (e) {
      debugPrint('Error submitting food: $e');
      return null;
    }
  }

  /// Fetch submissions for a day/site (HOD view).
  Future<List<FoodSubmission>> fetchSubmissions(
    DateTime day, {
    String? siteId,
  }) async {
    try {
      var query = _client
          .from(_submissionsTable)
          .select()
          .eq('attendance_date', _dateOnly(day));
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response = await query.order('submitted_at', ascending: false);
      return (response as List)
          .map((json) =>
              FoodSubmission.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching food submissions: $e');
      return [];
    }
  }

  /// HOD approve/reject a submission.
  Future<bool> updateSubmissionStatus(
    String submissionId, {
    required String status, // approved / rejected
  }) async {
    try {
      await _client
          .from(_submissionsTable)
          .update({'status': status}).eq('id', submissionId);
      return true;
    } catch (e) {
      debugPrint('Error updating food submission status: $e');
      return false;
    }
  }

  /// Resolve profile display names for submission authors (HOD view).
  Future<Map<String, String>> fetchProfileNames(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final response = await _client
          .from('profiles')
          .select('id,full_name')
          .inFilter('id', userIds);
      final names = <String, String>{};
      for (final row in response as List) {
        final map = row as Map<String, dynamic>;
        names[map['id'] as String] = map['full_name'] as String? ?? 'Supervisor';
      }
      return names;
    } catch (e) {
      debugPrint('Error fetching profile names: $e');
      return {};
    }
  }

  String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);
}
