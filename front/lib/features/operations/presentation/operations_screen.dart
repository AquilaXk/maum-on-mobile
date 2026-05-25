import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../domain/operations_models.dart';
import '../../report/domain/report_models.dart';
import '../application/operations_controller.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({
    required this.controller,
    required this.onBack,
    super.key,
  });

  final OperationsController controller;
  final VoidCallback onBack;

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  late final TextEditingController _reasonController;
  late final TextEditingController _memberReasonController;
  late final TextEditingController _letterReasonController;
  late final TextEditingController _letterNoteController;
  late final TextEditingController _letterReceiverSearchController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text: widget.controller.state.actionReason,
    );
    _memberReasonController = TextEditingController(
      text: widget.controller.state.memberActionReason,
    );
    _letterReasonController = TextEditingController(
      text: widget.controller.state.letterActionReason,
    );
    _letterNoteController = TextEditingController(
      text: widget.controller.state.letterNote,
    );
    _letterReceiverSearchController = TextEditingController(
      text: widget.controller.state.letterReceiverQuery,
    );
    widget.controller.addListener(_syncReason);
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant OperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncReason);
      widget.controller.addListener(_syncReason);
      _loadIfNeeded();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncReason);
    _reasonController.dispose();
    _memberReasonController.dispose();
    _letterReasonController.dispose();
    _letterNoteController.dispose();
    _letterReceiverSearchController.dispose();
    super.dispose();
  }

  void _loadIfNeeded() {
    if (!widget.controller.state.hasLoaded) {
      Future<void>.microtask(widget.controller.load);
    }
  }

  void _syncReason() {
    final reason = widget.controller.state.actionReason;
    if (_reasonController.text != reason) {
      _reasonController.value = TextEditingValue(
        text: reason,
        selection: TextSelection.collapsed(offset: reason.length),
      );
    }

    final memberReason = widget.controller.state.memberActionReason;
    if (_memberReasonController.text != memberReason) {
      _memberReasonController.value = TextEditingValue(
        text: memberReason,
        selection: TextSelection.collapsed(offset: memberReason.length),
      );
    }

    final letterReason = widget.controller.state.letterActionReason;
    if (_letterReasonController.text != letterReason) {
      _letterReasonController.value = TextEditingValue(
        text: letterReason,
        selection: TextSelection.collapsed(offset: letterReason.length),
      );
    }

    final letterNote = widget.controller.state.letterNote;
    if (_letterNoteController.text != letterNote) {
      _letterNoteController.value = TextEditingValue(
        text: letterNote,
        selection: TextSelection.collapsed(offset: letterNote.length),
      );
    }

    final letterReceiverQuery = widget.controller.state.letterReceiverQuery;
    if (_letterReceiverSearchController.text != letterReceiverQuery) {
      _letterReceiverSearchController.value = TextEditingValue(
        text: letterReceiverQuery,
        selection: TextSelection.collapsed(offset: letterReceiverQuery.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;

        return AppScreen(
          title: '운영 검수',
          subtitle: '서비스 지표와 회원, 편지, 신고 조치를 확인합니다.',
          onBack: widget.onBack,
          onRefresh: widget.controller.load,
          children: [
            if (state.errorMessage != null) ...[
              AppNotice(
                message: state.errorMessage!,
                tone: AppNoticeTone.error,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.noticeMessage != null) ...[
              AppNotice(message: state.noticeMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            _OperationsViewSelector(
              selected: state.view,
              onSelected: widget.controller.selectView,
            ),
            const SizedBox(height: AppSpacing.lg),
            switch (state.view) {
              OperationsView.dashboard => _DashboardView(
                  state: state,
                  onOpenMembers: () =>
                      widget.controller.selectView(OperationsView.members),
                  onOpenLetters: () =>
                      widget.controller.selectView(OperationsView.letters),
                  onOpenReports: () =>
                      widget.controller.selectView(OperationsView.reports),
                ),
              OperationsView.members => _MembersView(
                  state: state,
                  reasonController: _memberReasonController,
                  controller: widget.controller,
                ),
              OperationsView.letters => _LettersView(
                  state: state,
                  reasonController: _letterReasonController,
                  noteController: _letterNoteController,
                  receiverSearchController: _letterReceiverSearchController,
                  controller: widget.controller,
                ),
              OperationsView.reports => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReportQueue(state: state, controller: widget.controller),
                    const SizedBox(height: AppSpacing.lg),
                    _ReportDetail(
                      state: state,
                      reasonController: _reasonController,
                      onActionSelected: widget.controller.selectAction,
                      onReasonChanged: widget.controller.updateActionReason,
                      onSubmit: widget.controller.submitAction,
                    ),
                  ],
                ),
            },
          ],
        );
      },
    );
  }
}

class _OperationsViewSelector extends StatelessWidget {
  const _OperationsViewSelector({
    required this.selected,
    required this.onSelected,
  });

  final OperationsView selected;
  final ValueChanged<OperationsView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _ViewChip(
          key: const ValueKey('operations-view-dashboard'),
          label: '대시보드',
          selected: selected == OperationsView.dashboard,
          onSelected: () => onSelected(OperationsView.dashboard),
        ),
        _ViewChip(
          key: const ValueKey('operations-view-members'),
          label: '회원',
          selected: selected == OperationsView.members,
          onSelected: () => onSelected(OperationsView.members),
        ),
        _ViewChip(
          key: const ValueKey('operations-view-letters'),
          label: '편지',
          selected: selected == OperationsView.letters,
          onSelected: () => onSelected(OperationsView.letters),
        ),
        _ViewChip(
          key: const ValueKey('operations-view-reports'),
          label: '신고',
          selected: selected == OperationsView.reports,
          onSelected: () => onSelected(OperationsView.reports),
        ),
      ],
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.state,
    required this.onOpenMembers,
    required this.onOpenLetters,
    required this.onOpenReports,
  });

  final OperationsState state;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenLetters;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final dashboard = state.dashboard;
    if (state.isLoading && dashboard == null) {
      return const AppStateView.loading(
        title: '운영 대시보드를 불러오는 중입니다.',
        semanticLabel: '운영 대시보드를 불러오는 중',
      );
    }

    if (dashboard == null) {
      return const AppStateView.empty(
        title: '운영 대시보드 정보가 없습니다.',
        message: '새 지표가 수집되면 이곳에 표시됩니다.',
        semanticLabel: '운영 대시보드 비어 있음',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('운영 대시보드', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppMetricTile(
              label: '오늘 신고',
              value: dashboard.todayReportCount.toString(),
              tone: AppStatusTone.warning,
            ),
            AppMetricTile(
              label: '미처리 신고',
              value: dashboard.openReportCount.toString(),
              tone: AppStatusTone.danger,
            ),
            AppMetricTile(
              label: '처리 완료',
              value: dashboard.processedReportCount.toString(),
              tone: AppStatusTone.success,
            ),
            AppMetricTile(
              label: '오늘 편지',
              value: dashboard.todayLetterCount.toString(),
            ),
            AppMetricTile(
              label: '오늘 기록',
              value: dashboard.todayDiaryCount.toString(),
            ),
            AppMetricTile(
              label: '수신 가능 회원',
              value: dashboard.receivableMemberCount.toString(),
              tone: AppStatusTone.success,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            FilledButton.icon(
              onPressed: onOpenMembers,
              icon: const Icon(Icons.group_outlined),
              label: const Text('회원 관리'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenLetters,
              icon: const Icon(Icons.mail_outline),
              label: const Text('편지 검수'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenReports,
              icon: const Icon(Icons.report_gmailerrorred_outlined),
              label: const Text('신고 검수'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MembersView extends StatelessWidget {
  const _MembersView({
    required this.state,
    required this.reasonController,
    required this.controller,
  });

  final OperationsState state;
  final TextEditingController reasonController;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('회원 관리', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const ValueKey('operations-member-search-field'),
          decoration: const InputDecoration(
            labelText: '회원 검색',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (query) {
            controller.updateMemberQuery(query);
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        _MemberFilters(state: state, controller: controller),
        const SizedBox(height: AppSpacing.md),
        _MemberList(state: state, controller: controller),
        const SizedBox(height: AppSpacing.lg),
        _MemberDetail(
          state: state,
          reasonController: reasonController,
          controller: controller,
        ),
      ],
    );
  }
}

class _LettersView extends StatelessWidget {
  const _LettersView({
    required this.state,
    required this.reasonController,
    required this.noteController,
    required this.receiverSearchController,
    required this.controller,
  });

  final OperationsState state;
  final TextEditingController reasonController;
  final TextEditingController noteController;
  final TextEditingController receiverSearchController;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('편지 검수', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const ValueKey('operations-letter-search-field'),
          decoration: const InputDecoration(
            labelText: '편지 검색',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (query) {
            controller.updateLetterQuery(query);
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        _LetterFilters(state: state, controller: controller),
        const SizedBox(height: AppSpacing.md),
        _LetterList(state: state, controller: controller),
        const SizedBox(height: AppSpacing.lg),
        _LetterDetail(
          state: state,
          reasonController: reasonController,
          noteController: noteController,
          receiverSearchController: receiverSearchController,
          controller: controller,
        ),
      ],
    );
  }
}

class _LetterFilters extends StatelessWidget {
  const _LetterFilters({
    required this.state,
    required this.controller,
  });

  final OperationsState state;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: state.letterStatusFilter,
      hint: const Text('편지 상태'),
      items: const <DropdownMenuItem<String?>>[
        DropdownMenuItem(value: null, child: Text('전체 상태')),
        DropdownMenuItem(value: 'UNASSIGNED', child: Text('미배정')),
        DropdownMenuItem(value: 'SENT', child: Text('발송')),
        DropdownMenuItem(value: 'ACCEPTED', child: Text('수락')),
        DropdownMenuItem(value: 'WRITING', child: Text('작성 중')),
        DropdownMenuItem(value: 'REPLIED', child: Text('답장 완료')),
      ],
      onChanged: (status) {
        controller.selectLetterStatusFilter(status);
      },
    );
  }
}

class _LetterList extends StatelessWidget {
  const _LetterList({
    required this.state,
    required this.controller,
  });

  final OperationsState state;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isLetterLoading && state.letters.isEmpty) {
      return const AppStateView.loading(
        title: '편지 목록을 불러오는 중입니다.',
        semanticLabel: '운영 편지 목록을 불러오는 중',
      );
    }

    if (state.isLetterEmpty) {
      return const AppStateView.empty(
        title: '조건에 맞는 편지가 없습니다.',
        message: '검색어 또는 상태 필터를 바꿔 다시 확인해 주세요.',
        semanticLabel: '운영 편지 목록 비어 있음',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final letter in state.letters) ...[
          AppListRow(
            rowKey: ValueKey('operations-letter-${letter.id}'),
            title: letter.title.isEmpty ? '제목 없는 편지' : letter.title,
            subtitle:
                '발신 ${_adminMemberLabel(letter.sender)} · '
                '수신 ${_adminMemberLabel(letter.receiver)} · '
                '조치 ${letter.actionCount} · ${letter.createdAt}',
            statusLabel: _letterStatusLabel(letter.status),
            statusTone: _letterStatusTone(letter.status),
            leadingIcon: Icons.mail_outline,
            selected: state.selectedLetter?.id == letter.id,
            onTap: () {
              controller.openLetter(letter);
            },
            semanticLabel:
                '편지 항목: ${letter.title}, 발신 ${letter.sender.nickname}, 상태 ${_letterStatusLabel(letter.status)}',
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (state.canLoadMoreLetters)
          OutlinedButton.icon(
            onPressed: () => controller.loadLetters(),
            icon: const Icon(Icons.expand_more),
            label: const Text('더 불러오기'),
          ),
      ],
    );
  }
}

class _LetterDetail extends StatelessWidget {
  const _LetterDetail({
    required this.state,
    required this.reasonController,
    required this.noteController,
    required this.receiverSearchController,
    required this.controller,
  });

  final OperationsState state;
  final TextEditingController reasonController;
  final TextEditingController noteController;
  final TextEditingController receiverSearchController;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isLetterDetailLoading) {
      return const AppStateView.loading(
        title: '편지 상세를 불러오는 중입니다.',
        semanticLabel: '운영 편지 상세를 불러오는 중',
      );
    }

    final detail = state.selectedLetter;
    if (detail == null) {
      return const AppStateView.empty(
        title: '검수할 편지를 선택해 주세요.',
        message: '목록에서 편지를 선택하면 조치와 메모를 남길 수 있습니다.',
        semanticLabel: '운영 편지 상세 선택 필요',
      );
    }

    return AppSectionCard(
      title: '편지 상세',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusPill(
                label: _letterStatusLabel(detail.status),
                tone: _letterStatusTone(detail.status),
              ),
              AppStatusPill(label: '후보 ${detail.receivers.length}명'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppDetailRow(label: '발신자', value: _adminMemberLabel(detail.sender)),
          AppDetailRow(label: '수신자', value: _adminMemberLabel(detail.receiver)),
          AppDetailRow(label: '작성일', value: detail.createdAt),
          if (detail.replyCreatedAt != null)
            AppDetailRow(label: '답장일', value: detail.replyCreatedAt!),
          _SummaryBlock(label: '원문 요약', value: detail.originalSummary),
          _SummaryBlock(label: '답장 요약', value: detail.replySummary ?? '-'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('operations-letter-action-reason-field'),
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            onChanged: controller.updateLetterActionReason,
            decoration: const InputDecoration(
              labelText: '편지 조치 사유',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('operations-letter-note-field'),
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            onChanged: controller.updateLetterNote,
            decoration: const InputDecoration(
              labelText: '운영 메모',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('operations-letter-receiver-search-field'),
            controller: receiverSearchController,
            decoration: const InputDecoration(
              labelText: '재배정 수신자 검색',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (query) {
              controller.searchLetterReceivers(query);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          _LetterReceiverCandidates(state: state, controller: controller),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppConfirmActionButton(
                buttonKey: const ValueKey('operations-letter-note-button'),
                confirmButtonKey:
                    const ValueKey('operations-confirm-letter-note-button'),
                enabled: state.canSubmitLetterNote,
                icon: const Icon(Icons.note_add_outlined),
                label: state.isLetterActionSubmitting ? '저장 중' : '메모 저장',
                confirmTitle: '편지 메모 저장 확인',
                confirmMessage: '운영 메모와 사유가 조치 이력에 남습니다.',
                confirmButtonLabel: '저장',
                onConfirmed: controller.addSelectedLetterNote,
              ),
              AppConfirmActionButton(
                buttonKey: const ValueKey('operations-letter-reassign-button'),
                confirmButtonKey:
                    const ValueKey('operations-confirm-letter-reassign-button'),
                enabled: state.canSubmitLetterReassign,
                icon: const Icon(Icons.swap_horiz),
                label: state.isLetterActionSubmitting ? '변경 중' : '수신자 재배정',
                confirmTitle: '편지 재배정 확인',
                confirmMessage: '선택한 수신자로 편지를 재배정하고 조치 이력을 남깁니다.',
                confirmButtonLabel: '재배정',
                onConfirmed: controller.reassignSelectedLetter,
              ),
              AppConfirmActionButton(
                buttonKey:
                    const ValueKey('operations-letter-block-sender-button'),
                confirmButtonKey:
                    const ValueKey('operations-confirm-letter-block-button'),
                enabled: state.canSubmitLetterAction,
                icon: const Icon(Icons.block),
                label: state.isLetterActionSubmitting ? '차단 중' : '발신자 차단',
                confirmTitle: '발신자 차단 확인',
                confirmMessage: '발신자를 차단하고 로그인 세션과 기기 토큰을 회수합니다.',
                confirmButtonLabel: '차단',
                onConfirmed: controller.blockSelectedLetterSender,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _AuditSection(events: detail.auditEvents),
        ],
      ),
    );
  }
}

class _LetterReceiverCandidates extends StatelessWidget {
  const _LetterReceiverCandidates({
    required this.state,
    required this.controller,
  });

  final OperationsState state;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isLetterReceiverLoading) {
      return const AppStateView.loading(
        title: '수신자 후보를 찾는 중입니다.',
        semanticLabel: '수신자 후보를 찾는 중',
      );
    }

    if (state.letterReceiverQuery.isEmpty) {
      return const AppStateView.empty(
        title: '검색어를 입력해 수신자를 찾습니다.',
        message: '닉네임 또는 이메일로 재배정할 수신자를 검색해 주세요.',
        semanticLabel: '수신자 검색어 입력 필요',
      );
    }

    if (state.letterReceiverCandidates.isEmpty) {
      return const AppStateView.empty(
        title: '검색된 수신자가 없습니다.',
        message: '다른 검색어로 다시 시도해 주세요.',
        semanticLabel: '수신자 후보 비어 있음',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final member in state.letterReceiverCandidates) ...[
          AppListRow(
            rowKey: ValueKey('operations-letter-receiver-${member.id}'),
            title: '${member.nickname} · ${member.email}',
            subtitle:
                '${_memberStatusLabel(member.status)} · '
                '${_memberRoleLabel(member.role)} · '
                '수신 ${member.randomReceiveAllowed ? '가능' : '불가'}',
            statusLabel: state.selectedLetterReceiverId == member.id
                ? '선택'
                : _memberStatusLabel(member.status),
            statusTone: state.selectedLetterReceiverId == member.id
                ? AppStatusTone.success
                : _memberStatusTone(member.status),
            leadingIcon: Icons.person_search_outlined,
            trailingIcon: null,
            selected: state.selectedLetterReceiverId == member.id,
            onTap: () {
              controller.selectLetterReceiver(member.id);
            },
            semanticLabel:
                '수신자 후보: ${member.nickname}, ${member.email}, 상태 ${_memberStatusLabel(member.status)}',
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        container: true,
        label: '$label, $displayValue',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                displayValue,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberFilters extends StatelessWidget {
  const _MemberFilters({
    required this.state,
    required this.controller,
  });

  final OperationsState state;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        DropdownButton<String?>(
          value: state.memberStatusFilter,
          hint: const Text('상태'),
          items: const <DropdownMenuItem<String?>>[
            DropdownMenuItem(value: null, child: Text('전체 상태')),
            DropdownMenuItem(value: 'ACTIVE', child: Text('활성')),
            DropdownMenuItem(value: 'BLOCKED', child: Text('차단')),
            DropdownMenuItem(value: 'WITHDRAWN', child: Text('탈퇴')),
          ],
          onChanged: (status) {
            controller.selectMemberStatusFilter(status);
          },
        ),
        DropdownButton<String?>(
          value: state.memberRoleFilter,
          hint: const Text('역할'),
          items: const <DropdownMenuItem<String?>>[
            DropdownMenuItem(value: null, child: Text('전체 역할')),
            DropdownMenuItem(value: 'USER', child: Text('사용자')),
            DropdownMenuItem(value: 'ADMIN', child: Text('관리자')),
          ],
          onChanged: (role) {
            controller.selectMemberRoleFilter(role);
          },
        ),
        DropdownButton<bool?>(
          value: state.memberSocialAccountFilter,
          hint: const Text('가입'),
          items: const <DropdownMenuItem<bool?>>[
            DropdownMenuItem(value: null, child: Text('전체 가입')),
            DropdownMenuItem(value: true, child: Text('소셜')),
            DropdownMenuItem(value: false, child: Text('이메일')),
          ],
          onChanged: (socialAccount) {
            controller.selectMemberSocialAccountFilter(socialAccount);
          },
        ),
      ],
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.state,
    required this.controller,
  });

  final OperationsState state;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isMemberLoading && state.members.isEmpty) {
      return const AppStateView.loading(
        title: '회원 목록을 불러오는 중입니다.',
        semanticLabel: '운영 회원 목록을 불러오는 중',
      );
    }

    if (state.isMemberEmpty) {
      return const AppStateView.empty(
        title: '조건에 맞는 회원이 없습니다.',
        message: '검색어 또는 필터를 바꿔 다시 확인해 주세요.',
        semanticLabel: '운영 회원 목록 비어 있음',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final member in state.members) ...[
          AppListRow(
            rowKey: ValueKey('operations-member-${member.id}'),
            title: '${member.nickname} · ${member.email}',
            subtitle:
                '${_memberStatusLabel(member.status)} · '
                '${_memberRoleLabel(member.role)} · '
                '${_socialAccountLabel(member.socialAccount)} · '
                '신고 ${member.reportCount}',
            statusLabel: _memberStatusLabel(member.status),
            statusTone: _memberStatusTone(member.status),
            leadingIcon: Icons.person_outline,
            onTap: () {
              controller.openMember(member);
            },
            semanticLabel:
                '회원 항목: ${member.nickname}, ${member.email}, 상태 ${_memberStatusLabel(member.status)}',
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (state.canLoadMoreMembers)
          OutlinedButton.icon(
            onPressed: () => controller.loadMembers(),
            icon: const Icon(Icons.expand_more),
            label: const Text('더 불러오기'),
          ),
      ],
    );
  }
}

class _MemberDetail extends StatelessWidget {
  const _MemberDetail({
    required this.state,
    required this.reasonController,
    required this.controller,
  });

  final OperationsState state;
  final TextEditingController reasonController;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isMemberDetailLoading) {
      return const AppStateView.loading(
        title: '회원 상세를 불러오는 중입니다.',
        semanticLabel: '운영 회원 상세를 불러오는 중',
      );
    }

    final detail = state.selectedMember;
    if (detail == null) {
      return const AppStateView.empty(
        title: '확인할 회원을 선택해 주세요.',
        message: '목록에서 회원을 선택하면 계정 상태와 조치 이력을 볼 수 있습니다.',
        semanticLabel: '운영 회원 상세 선택 필요',
      );
    }

    final member = detail.member;
    final canSubmit = state.canSubmitMemberAction;
    final blockAction = member.status == 'BLOCKED'
        ? controller.unblockSelectedMember
        : controller.blockSelectedMember;
    final blockLabel = member.status == 'BLOCKED' ? '차단 해제' : '회원 차단';
    final blockTitle =
        member.status == 'BLOCKED' ? '차단 해제 확인' : '회원 차단 확인';
    final roleAction = member.role == 'ADMIN'
        ? controller.demoteSelectedMember
        : controller.promoteSelectedMember;
    final roleLabel = member.role == 'ADMIN' ? '사용자 전환' : '관리자 전환';

    return AppSectionCard(
      title: '회원 상세',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusPill(
                label: _memberStatusLabel(member.status),
                tone: _memberStatusTone(member.status),
              ),
              AppStatusPill(label: _memberRoleLabel(member.role)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppDetailRow(label: '이메일', value: member.email),
          AppDetailRow(label: '닉네임', value: member.nickname),
          AppDetailRow(
            label: '가입',
            value: _socialAccountLabel(member.socialAccount),
          ),
          AppDetailRow(
            label: '이력',
            value:
                '신고 ${member.reportCount} · 작성글 ${member.postCount} · 편지 ${member.letterCount} · 기록 ${member.diaryCount}',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('operations-member-action-reason-field'),
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            onChanged: controller.updateMemberActionReason,
            decoration: const InputDecoration(
              labelText: '관리자 조치 사유',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppConfirmActionButton(
                buttonKey: const ValueKey('operations-member-block-button'),
                confirmButtonKey:
                    const ValueKey('operations-confirm-member-action-button'),
                enabled: canSubmit,
                icon: const Icon(Icons.block),
                label: blockLabel,
                confirmTitle: blockTitle,
                confirmMessage: '${member.nickname} 회원에게 $blockLabel 조치를 저장합니다.',
                confirmButtonLabel: '저장',
                onConfirmed: blockAction,
              ),
              AppConfirmActionButton(
                buttonKey: const ValueKey('operations-member-role-button'),
                confirmButtonKey:
                    const ValueKey('operations-confirm-member-role-button'),
                enabled: canSubmit,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: roleLabel,
                confirmTitle: '역할 변경 확인',
                confirmMessage: '${member.nickname} 회원의 역할을 변경합니다.',
                confirmButtonLabel: '변경',
                onConfirmed: roleAction,
              ),
              AppConfirmActionButton(
                buttonKey: const ValueKey('operations-member-revoke-button'),
                confirmButtonKey:
                    const ValueKey('operations-confirm-member-revoke-button'),
                enabled: canSubmit,
                icon: const Icon(Icons.logout),
                label: '세션 회수',
                confirmTitle: '세션 회수 확인',
                confirmMessage: '${member.nickname} 회원의 로그인 세션과 기기 토큰을 회수합니다.',
                confirmButtonLabel: '회수',
                onConfirmed: controller.revokeSelectedMemberSessions,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ContentSection(title: '신고 이력', reports: detail.reports),
          _ContentSection(title: '작성글', contents: detail.posts),
          _ContentSection(title: '편지 이력', contents: detail.letters),
          _ContentSection(title: '기록', contents: detail.diaries),
          _AuditSection(events: detail.auditEvents),
        ],
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.title,
    this.reports = const [],
    this.contents = const [],
  });

  final String title;
  final List<AdminReportSummary> reports;
  final List<AdminMemberContent> contents;

  @override
  Widget build(BuildContext context) {
    final empty = reports.isEmpty && contents.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          if (empty)
            const Text('-')
          else ...[
            for (final report in reports)
              AppDetailRow(
                label: report.targetTitle,
                value:
                    '${_reportStatusLabel(report.status)} · ${report.createdAt}',
              ),
            for (final content in contents)
              AppDetailRow(
                label: content.title,
                value:
                    '${content.status ?? '-'} · ${content.createdAt}',
              ),
          ],
        ],
      ),
    );
  }
}

class _AuditSection extends StatelessWidget {
  const _AuditSection({required this.events});

  final List<AdminAuditEvent> events;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('조치 이력', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          if (events.isEmpty)
            const Text('-')
          else
            for (final event in events)
              AppDetailRow(
                label: event.action,
                value:
                    '${event.previousValue} -> ${event.newValue} · ${event.reason}',
              ),
        ],
      ),
    );
  }
}

class _ReportQueue extends StatelessWidget {
  const _ReportQueue({
    required this.state,
    required this.controller,
  });

  final OperationsState state;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && !state.hasLoaded) {
      return const AppStateView.loading(
        title: '신고 목록을 불러오는 중입니다.',
        semanticLabel: '운영 신고 목록을 불러오는 중',
      );
    }

    if (state.isEmpty) {
      return const AppStateView.empty(
        title: '처리할 신고가 없습니다.',
        message: '새 신고가 접수되면 이곳에 표시됩니다.',
        semanticLabel: '운영 신고 목록 비어 있음',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('신고 대기열', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final report in state.reports) ...[
          _ReportQueueTile(
            report: report,
            selected: state.selectedReport?.id == report.id,
            onTap: () => controller.openReport(report),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _ReportQueueTile extends StatelessWidget {
  const _ReportQueueTile({
    required this.report,
    required this.selected,
    required this.onTap,
  });

  final AdminReportSummary report;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = report.targetTitle.isEmpty ? '대상 없음' : report.targetTitle;
    final statusLabel = _reportStatusLabel(report.status);

    return AppListRow(
      rowKey: ValueKey('operations-report-${report.id}'),
      title: title,
      subtitle:
          '${report.targetType.label} · 신고자 ${report.reporter.nickname} · ${report.createdAt}',
      statusLabel: statusLabel,
      statusTone: _reportStatusTone(report.status),
      leadingIcon: report.isOpen ? Icons.inbox_outlined : Icons.task_alt,
      selected: selected,
      onTap: onTap,
      semanticLabel:
          '신고 항목: ${report.targetType.label}, $title, 신고자 ${report.reporter.nickname}, 상태 $statusLabel',
    );
  }
}

class _ReportDetail extends StatelessWidget {
  const _ReportDetail({
    required this.state,
    required this.reasonController,
    required this.onActionSelected,
    required this.onReasonChanged,
    required this.onSubmit,
  });

  final OperationsState state;
  final TextEditingController reasonController;
  final ValueChanged<AdminReportAction> onActionSelected;
  final ValueChanged<String> onReasonChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final report = state.selectedReport;
    if (state.isDetailLoading) {
      return const AppStateView.loading(
        title: '신고 상세를 불러오는 중입니다.',
        semanticLabel: '운영 신고 상세를 불러오는 중',
      );
    }

    if (report == null) {
      return const AppStateView.empty(
        title: '검수할 신고를 선택해 주세요.',
        message: '신고 대기열에서 항목을 선택하면 상세 검수와 조치를 진행할 수 있습니다.',
        semanticLabel: '운영 신고 상세 선택 필요',
      );
    }

    return AppSectionCard(
      title: '신고 상세',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusPill(
                label: _reportStatusLabel(report.status),
                tone: _reportStatusTone(report.status),
              ),
              AppStatusPill(label: report.target.type.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppDetailRow(
            label: '신고자',
            value: _memberLabel(report.reporter),
          ),
          AppDetailRow(
            label: '대상 회원',
            value: report.targetOwner == null
                ? '-'
                : _memberLabel(report.targetOwner!),
          ),
          AppDetailRow(label: '대상', value: report.target.title),
          if (report.target.preview.isNotEmpty)
            AppDetailRow(label: '내용', value: report.target.preview),
          if (report.content != null)
            AppDetailRow(label: '신고 설명', value: report.content!),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: const ValueKey('operations-action-field'),
            child: DropdownButtonFormField<AdminReportAction>(
              key: ValueKey(
                'operations-action-value-${report.id}-${state.selectedAction.apiValue}',
              ),
              initialValue: state.selectedAction,
              decoration: const InputDecoration(
                labelText: '조치',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final action in AdminReportAction.values)
                  DropdownMenuItem(
                    value: action,
                    child: Text(action.label),
                  ),
              ],
              onChanged: state.isSubmitting
                  ? null
                  : (action) {
                      if (action != null) {
                        onActionSelected(action);
                      }
                    },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('operations-reason-field'),
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            onChanged: onReasonChanged,
            decoration: const InputDecoration(
              labelText: '조치 사유',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppConfirmActionButton(
            buttonKey: const ValueKey('operations-submit-button'),
            confirmButtonKey:
                const ValueKey('operations-confirm-submit-button'),
            enabled: state.canSubmitAction,
            icon: const Icon(Icons.gavel_outlined),
            label: state.isSubmitting ? '저장 중' : '조치 저장',
            confirmTitle: '조치 저장 확인',
            confirmMessage:
                '${state.selectedAction.label} 조치를 저장합니다. 사유와 상태가 운영 기록에 남습니다.',
            confirmButtonLabel: '저장',
            semanticLabel: '운영 조치 저장',
            onConfirmed: onSubmit,
          ),
          if (report.handledBy != null || report.actionReason != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppNotice(
              message:
                  '${report.handledBy?.nickname ?? '운영자'} · ${report.handledAt ?? '-'} · ${report.actionReason ?? '-'}',
              tone: AppNoticeTone.success,
            ),
          ],
        ],
      ),
    );
  }

  String _memberLabel(AdminReportMember member) {
    return '${member.nickname} · ${member.email} · ${member.status}';
  }
}

String _adminMemberLabel(AdminReportMember? member) {
  if (member == null) {
    return '미배정';
  }
  return '${member.nickname} · ${member.email} · ${member.status}';
}

String _reportStatusLabel(String status) {
  return switch (status) {
    'RECEIVED' => '접수',
    'RESOLVED' => '처리 완료',
    'REJECTED' => '반려',
    'HIDDEN' => '숨김',
    'DELETED' => '삭제',
    'RESTRICTED' => '제한',
    _ => status.isEmpty ? '-' : status,
  };
}

AppStatusTone _reportStatusTone(String status) {
  switch (status) {
    case 'RESOLVED':
      return AppStatusTone.success;
    case 'RECEIVED':
      return AppStatusTone.warning;
    case 'HIDDEN':
    case 'DELETED':
    case 'RESTRICTED':
      return AppStatusTone.danger;
    default:
      return AppStatusTone.neutral;
  }
}

String _letterStatusLabel(String status) {
  return switch (status) {
    'UNASSIGNED' => '미배정',
    'SENT' => '발송',
    'ACCEPTED' => '수락',
    'WRITING' => '작성 중',
    'REPLIED' => '답장 완료',
    _ => status.isEmpty ? '-' : status,
  };
}

AppStatusTone _letterStatusTone(String status) {
  return switch (status) {
    'REPLIED' => AppStatusTone.success,
    'UNASSIGNED' => AppStatusTone.danger,
    'SENT' || 'ACCEPTED' || 'WRITING' => AppStatusTone.warning,
    _ => AppStatusTone.neutral,
  };
}

String _memberStatusLabel(String status) {
  return switch (status) {
    'ACTIVE' => '활성',
    'BLOCKED' => '차단',
    'WITHDRAWN' => '탈퇴',
    _ => status.isEmpty ? '-' : status,
  };
}

AppStatusTone _memberStatusTone(String status) {
  return switch (status) {
    'ACTIVE' => AppStatusTone.success,
    'BLOCKED' => AppStatusTone.danger,
    'WITHDRAWN' => AppStatusTone.warning,
    _ => AppStatusTone.neutral,
  };
}

String _memberRoleLabel(String role) {
  return switch (role) {
    'ADMIN' => '관리자',
    'USER' => '사용자',
    _ => role.isEmpty ? '-' : role,
  };
}

String _socialAccountLabel(bool socialAccount) {
  return socialAccount ? '소셜 가입' : '이메일 가입';
}
