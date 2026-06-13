import 'package:flutter/material.dart';

import '../features/admin/data/admin_repository.dart';
import '../features/admin/domain/admin_models.dart';
import '../features/admin/presentation/admin_web_app.dart';
import '../theme/app_theme.dart';

void main() {
  runApp(buildAdminWebQaApp());
}

Widget buildAdminWebQaApp() {
  return MaterialApp(
    title: 'Maum On Admin QA',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    themeMode: ThemeMode.light,
    home: const AdminWebApp(repository: _QaAdminRepository()),
  );
}

class _QaAdminRepository implements AdminRepository {
  const _QaAdminRepository();

  @override
  Future<AdminDashboard> fetchDashboard() async {
    return const AdminDashboard(
      todayReportCount: 6,
      openReportCount: 3,
      processedReportCount: 18,
      todayLetterCount: 11,
      todayDiaryCount: 24,
      receivableMemberCount: 92,
      blockedMemberCount: 4,
      adminMemberCount: 2,
      unassignedLetterCount: 2,
      todayAdminActionCount: 7,
    );
  }

  @override
  Future<List<AdminReportSummary>> fetchReports({
    String? status,
    String? targetType,
    String? sort,
  }) async {
    return const [
      AdminReportSummary(
        id: 1,
        targetType: 'POST',
        targetId: 11,
        targetTitle: '관계 고민 글 신고',
        targetOwner: AdminReportMember(
          id: 2,
          email: 'owner@example.com',
          nickname: '온기',
        ),
        reporter: AdminReportMember(
          id: 3,
          email: 'reporter@example.com',
          nickname: '지킴이',
        ),
        reason: 'ABUSE',
        status: 'OPEN',
        createdAt: '2026-06-12T09:00:00Z',
        actionCount: 0,
      ),
      AdminReportSummary(
        id: 2,
        targetType: 'COMMENT',
        targetId: 12,
        targetTitle: '상처 주는 댓글 신고',
        targetOwner: AdminReportMember(
          id: 4,
          email: 'commenter@example.com',
          nickname: '나눔',
        ),
        reporter: AdminReportMember(
          id: 5,
          email: 'safe@example.com',
          nickname: '마음이',
        ),
        reason: 'HARASSMENT',
        status: 'OPEN',
        createdAt: '2026-06-12T09:20:00Z',
        actionCount: 1,
      ),
    ];
  }

  @override
  Future<AdminMemberPage> fetchMembers({
    String? query,
    String? status,
    String? role,
    bool? socialAccount,
    int page = 0,
    int size = 20,
  }) async {
    return const AdminMemberPage(
      content: [
        AdminMemberSummary(
          id: 7,
          email: 'member@example.com',
          nickname: '마음회원',
          role: 'USER',
          status: 'ACTIVE',
          socialAccount: false,
          randomReceiveAllowed: true,
          reportCount: 1,
          postCount: 5,
          letterCount: 3,
          diaryCount: 9,
        ),
      ],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  }) async {
    return const AdminLetterPage(
      content: [
        AdminLetterSummary(
          id: 9,
          title: '답장을 기다리는 편지',
          sender: AdminReportMember(
            id: 4,
            email: 'sender@example.com',
            nickname: '보낸마음',
          ),
          receiver: null,
          status: 'UNASSIGNED',
          createdAt: '2026-06-12T09:10:00Z',
          originalSummary: '혼자 견디기 어려운 마음을 적은 편지',
          replySummary: null,
          availableReceiverCount: 8,
          actionCount: 1,
        ),
      ],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<AdminModerationSummary> fetchModerationSummary() async {
    return const AdminModerationSummary(
      totalCount: 128,
      blockedCount: 14,
      modelFailureCount: 1,
      failureRate: 0.01,
      highRiskCategories: {'abuse': 8, 'self_harm': 3},
      modelStatuses: {'ALLOW': 114, 'BLOCK': 14},
      targets: {'LETTER': 54, 'STORY': 46, 'CONSULTATION': 28},
      recentFailures: [],
    );
  }
}
