package com.maumonmobile.performance

import com.maumonmobile.application.port.`in`.AdminOperationsUseCase
import com.maumonmobile.application.port.`in`.DiarySaveCommand
import com.maumonmobile.application.port.`in`.DiaryUseCase
import com.maumonmobile.application.port.`in`.LetterUseCase
import com.maumonmobile.application.port.`in`.MemberSettingsUseCase
import com.maumonmobile.application.port.`in`.NotificationUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.application.port.out.ContentModerationAuditRepository
import com.maumonmobile.application.port.out.DiaryRepository
import com.maumonmobile.application.port.out.LetterRepository
import com.maumonmobile.application.port.out.MemberDataExportRepository
import com.maumonmobile.application.port.out.NotificationRepository
import com.maumonmobile.application.port.out.ReportRepository
import com.maumonmobile.application.port.out.StoryRepository
import com.maumonmobile.application.service.ContentModerationService
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import com.maumonmobile.domain.common.toUtcIso6
import com.maumonmobile.domain.diary.DiaryDraft
import com.maumonmobile.domain.letter.LetterDraft
import com.maumonmobile.domain.member.MemberDataExportJob
import com.maumonmobile.domain.member.MemberDataExportStatus
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.domain.notification.NotificationTargetMetadata
import com.maumonmobile.domain.report.ReportDraft
import com.maumonmobile.domain.report.ReportReason
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.domain.story.StoryPostDraft
import com.maumonmobile.global.security.AuthenticatedUser
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.config.BeanPostProcessor
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.jdbc.datasource.DelegatingDataSource
import org.springframework.test.context.ActiveProfiles
import org.springframework.transaction.support.TransactionTemplate
import java.lang.reflect.Proxy
import java.sql.CallableStatement
import java.sql.Connection
import java.sql.PreparedStatement
import java.sql.Statement
import java.time.Instant
import java.util.UUID
import javax.sql.DataSource

@SpringBootTest
@ActiveProfiles("test")
@Import(QueryEfficiencyIntegrationTest.SqlStatementCounterConfig::class)
class QueryEfficiencyIntegrationTest @Autowired constructor(
    private val sqlStatementTracker: SqlStatementTracker,
    private val authMemberRepository: AuthMemberRepository,
    private val storyRepository: StoryRepository,
    private val diaryRepository: DiaryRepository,
    private val letterRepository: LetterRepository,
    private val reportRepository: ReportRepository,
    private val notificationRepository: NotificationRepository,
    private val memberDataExportRepository: MemberDataExportRepository,
    private val contentModerationAuditRepository: ContentModerationAuditRepository,
    private val contentModerationService: ContentModerationService,
    private val adminOperationsUseCase: AdminOperationsUseCase,
    private val letterUseCase: LetterUseCase,
    private val notificationUseCase: NotificationUseCase,
    private val memberSettingsUseCase: MemberSettingsUseCase,
    private val diaryUseCase: DiaryUseCase,
    private val transactionTemplate: TransactionTemplate,
) {

    @Test
    fun adminOperationsUseBoundedQueriesRegardlessOfMemberCount() {
        val tag = uniqueTag()
        val admin = saveMember("admin-$tag@example.com", "관리자-$tag", AuthMemberRole.ADMIN)
        val members = (1..15).map { index ->
            saveMember("member-$tag-$index@example.com", "회원-$tag-$index")
        }
        val firstPost = storyRepository.savePost(
            authorId = members[0].id,
            authorNickname = members[0].nickname,
            draft = StoryPostDraft("이야기 제목", "이야기 본문", "WORRY", null),
        )
        members.forEachIndexed { index, member ->
            diaryRepository.save(
                memberId = member.id,
                nickname = member.nickname,
                draft = DiaryDraft("일기-$index", "내용-$index", "일상", null, true, null),
            )
            letterRepository.save(
                senderId = member.id,
                senderNickname = member.nickname,
                draft = LetterDraft("편지-$index", "편지 본문-$index"),
                receiverId = members[(index + 1) % members.size].id,
            )
            if (index > 0) {
                reportRepository.save(
                    ReportDraft(
                        reporterId = member.id,
                        targetId = firstPost.id,
                        targetType = ReportTargetType.POST,
                        reason = ReportReason.OTHER,
                        content = "신고-$index",
                    ),
                )
            }
        }

        val adminUser = AuthenticatedUser(admin.id.toString(), admin.email, setOf("USER", "ADMIN"))

        val (page, listSqls) = sqlStatementTracker.capture {
            adminOperationsUseCase.listMembers(
                user = adminUser,
                query = "member-$tag-",
                status = null,
                role = null,
                socialAccount = null,
                page = 0,
                size = 10,
            )
        }
        assertThat(page.content).hasSize(10)
        assertThat(page.totalElements).isEqualTo(15)
        assertThat(listSqls).hasSizeLessThanOrEqualTo(7)

        val (dashboard, dashboardSqls) = sqlStatementTracker.capture {
            adminOperationsUseCase.dashboard(adminUser)
        }
        assertThat(dashboard.todayDiaryCount).isGreaterThanOrEqualTo(15)
        assertThat(dashboard.todayLetterCount).isGreaterThanOrEqualTo(15)
        assertThat(dashboardSqls).hasSizeLessThanOrEqualTo(6)
    }

    @Test
    fun letterStatsAndReceivedExecuteConstantNumberOfSqlQueries() {
        val tag = uniqueTag()
        val receiver = saveMember("receiver-$tag@example.com", "수신자-$tag")
        val senders = (1..12).map { index ->
            saveMember("sender-$tag-$index@example.com", "발신자-$tag-$index")
        }
        val receiverUser = AuthenticatedUser(receiver.id.toString(), receiver.email, setOf("USER"))
        val baselineReceivedCount = letterUseCase.stats(receiverUser).receivedCount
        senders.forEachIndexed { index, sender ->
            letterRepository.save(
                senderId = sender.id,
                senderNickname = sender.nickname,
                draft = LetterDraft("편지 제목 $index", "편지 본문 $index"),
                receiverId = receiver.id,
            )
        }
        letterRepository.save(
            senderId = receiver.id,
            senderNickname = receiver.nickname,
            draft = LetterDraft("보낸 편지", "보낸 본문"),
            receiverId = senders.first().id,
        )

        val (stats, statsSqls) = sqlStatementTracker.capture {
            letterUseCase.stats(receiverUser)
        }
        assertThat(stats.receivedCount).isEqualTo(baselineReceivedCount + 12)
        assertThat(stats.latestReceivedLetter).isNotNull
        assertThat(stats.latestSentLetter).isNotNull
        assertThat(statsSqls).hasSizeLessThanOrEqualTo(7)

        val (receivedPage, receivedSqls) = sqlStatementTracker.capture {
            letterUseCase.received(receiverUser, page = 0, size = 10)
        }
        assertThat(receivedPage.letters).hasSize(10)
        assertThat(receivedPage.totalElements).isEqualTo(baselineReceivedCount + 12)
        assertThat(receivedSqls).hasSizeLessThanOrEqualTo(5)
    }

    @Test
    fun notificationListBatchesTargetExistenceQueriesAcrossTargetTypes() {
        val tag = uniqueTag()
        val member = saveMember("notif-$tag@example.com", "알림회원-$tag")
        val post = storyRepository.savePost(
            authorId = member.id,
            authorNickname = member.nickname,
            draft = StoryPostDraft("알림 게시글", "게시글 본문", "DAILY", null),
        )
        val comment = storyRepository.saveComment(
            postId = post.id,
            authorId = member.id,
            authorNickname = member.nickname,
            authorEmail = member.email,
            parentCommentId = null,
            content = "알림 댓글",
        )
        val diary = diaryRepository.save(
            memberId = member.id,
            nickname = member.nickname,
            draft = DiaryDraft("알림 일기", "일기 본문", "일상", null, true, null),
        )
        val letter = letterRepository.save(
            senderId = member.id,
            senderNickname = member.nickname,
            draft = LetterDraft("알림 편지", "편지 본문"),
            receiverId = member.id,
        )
        val report = reportRepository.save(
            ReportDraft(
                reporterId = member.id,
                targetId = post.id,
                targetType = ReportTargetType.POST,
                reason = ReportReason.OTHER,
                content = "알림 신고",
            ),
        )

        repeat(3) {
            notificationRepository.save(
                receiverId = member.id,
                content = "게시글 알림",
                metadata = NotificationTargetMetadata("story_comment", "POST", post.id, "story"),
            )
            notificationRepository.save(
                receiverId = member.id,
                content = "댓글 알림",
                metadata = NotificationTargetMetadata("story_reply", "COMMENT", comment.id, "story"),
            )
        }
        notificationRepository.save(
            receiverId = member.id,
            content = "삭제된 게시글 알림",
            metadata = NotificationTargetMetadata("story_comment", "POST", 999_999_991L, "story"),
        )
        repeat(2) {
            notificationRepository.save(
                receiverId = member.id,
                content = "일기 알림",
                metadata = NotificationTargetMetadata("diary", "DIARY", diary.id, "diary"),
            )
            notificationRepository.save(
                receiverId = member.id,
                content = "편지 알림",
                metadata = NotificationTargetMetadata("letter_read", "LETTER", letter.id, "letter"),
            )
        }
        notificationRepository.save(
            receiverId = member.id,
            content = "신고 알림",
            metadata = NotificationTargetMetadata("report_status", "REPORT", report.id, "report"),
        )

        val user = AuthenticatedUser(member.id.toString(), member.email, setOf("USER"))
        val (notifications, sqls) = sqlStatementTracker.capture {
            notificationUseCase.list(user)
        }

        assertThat(notifications).hasSize(12)
        assertThat(notifications.count { !it.targetState.available }).isEqualTo(1)
        assertThat(notifications.count { it.targetState.available }).isEqualTo(11)
        // findActiveMember (1) + findByReceiverId (1) + 1 batch IN query per target type (POST, COMMENT, DIARY, LETTER, REPORT)
        assertThat(sqls).hasSizeLessThanOrEqualTo(7)
    }

    @Test
    fun memberSettingsReadsExportSummaryWithoutContentJsonColumn() {
        val tag = uniqueTag()
        val member = saveMember("settings-summary-$tag@example.com", "요약회원-$tag")
        val now = Instant.now()
        memberDataExportRepository.save(
            MemberDataExportJob(
                id = 0,
                memberId = member.id,
                status = MemberDataExportStatus.COMPLETED,
                requestedAt = now.minusSeconds(60).toUtcIso6(),
                completedAt = now.toUtcIso6(),
                expiresAt = now.plusSeconds(3600).toUtcIso6(),
                downloadedAt = null,
                failureReason = null,
                contentJson = """{"largePayload":"should-not-be-selected-by-summary"}""",
            ),
        )

        val user = AuthenticatedUser(member.id.toString(), member.email, setOf("USER"))
        val (settings, sqls) = sqlStatementTracker.capture {
            memberSettingsUseCase.get(user)
        }

        assertThat(settings.latestDataExport).isNotNull
        assertThat(settings.latestDataExport!!.status).isEqualTo("COMPLETED")
        assertThat(sqls).hasSizeLessThanOrEqualTo(2)
        assertThat(sqls).noneMatch { sql -> sql.contains("content_json", ignoreCase = true) }
    }

    @Test
    fun moderationAuditPersistsViaRequiresNewWhenDiaryTransactionRollsBack() {
        val tag = uniqueTag()
        val member = saveMember("audit-tx-$tag@example.com", "감사회원-$tag")
        val user = AuthenticatedUser(member.id.toString(), member.email, setOf("USER"))
        val initialDiaryCount = diaryRepository.countByMemberId(member.id)
        val initialAuditCount = contentModerationAuditRepository.findAll().count { it.memberId == member.id }

        assertThatThrownBy {
            diaryUseCase.create(
                user,
                DiarySaveCommand(
                    title = "롤백 확인",
                    content = "죽고싶다 정말 끝내고싶다",
                    categoryName = "일상",
                    imageUrl = null,
                    isPrivate = true,
                    imageFilename = null,
                ),
            )
        }
            .isInstanceOf(ApiException::class.java)
            .satisfies({ thrown ->
                assertThat((thrown as ApiException).errorCode).isEqualTo(ErrorCode.INVALID_REQUEST)
            })

        assertThatThrownBy {
            transactionTemplate.executeWithoutResult {
                diaryRepository.save(
                    memberId = member.id,
                    nickname = member.nickname,
                    draft = DiaryDraft("외부 트랜잭션 롤백", "정상 본문", "일상", null, true, null),
                )
                contentModerationService.ensureAllowed(
                    member.id,
                    ContentModerationTarget.DIARY,
                    "죽고싶다",
                )
            }
        }.isInstanceOf(ApiException::class.java)

        assertThat(diaryRepository.countByMemberId(member.id)).isEqualTo(initialDiaryCount)
        val memberAudits = contentModerationAuditRepository.findAll().filter { it.memberId == member.id }
        assertThat(memberAudits).hasSize(initialAuditCount + 2)
        assertThat(memberAudits).allSatisfy { audit ->
            assertThat(audit.allowed).isFalse()
            assertThat(audit.target).isEqualTo(ContentModerationTarget.DIARY)
        }
    }

    private fun saveMember(
        email: String,
        nickname: String,
        role: AuthMemberRole = AuthMemberRole.USER,
    ): AuthMember {
        return authMemberRepository.save(
            AuthMember(
                id = 0,
                email = email,
                passwordHash = "encoded-password",
                nickname = nickname,
                randomReceiveAllowed = true,
                socialAccount = false,
                role = role,
                status = AuthMemberStatus.ACTIVE,
            ),
        )
    }

    private fun uniqueTag(): String = UUID.randomUUID().toString().replace("-", "").take(10)

    class SqlStatementTracker {
        private val activeStatements = ThreadLocal<MutableList<String>?>()

        fun <T> capture(block: () -> T): Pair<T, List<String>> {
            val captured = mutableListOf<String>()
            val previous = activeStatements.get()
            activeStatements.set(captured)
            return try {
                val result = block()
                result to captured.toList()
            } finally {
                activeStatements.set(previous)
            }
        }

        fun wrap(delegate: DataSource): DataSource {
            return object : DelegatingDataSource(delegate) {
                override fun getConnection(): Connection = wrapConnection(super.getConnection())
                override fun getConnection(username: String, password: String): Connection =
                    wrapConnection(super.getConnection(username, password))
            }
        }

        private fun record(sql: String?) {
            activeStatements.get()?.add(sql.orEmpty())
        }

        private fun wrapConnection(connection: Connection): Connection {
            return Proxy.newProxyInstance(
                connection.javaClass.classLoader,
                arrayOf(Connection::class.java),
            ) { _, method, args ->
                val safeArgs = args ?: emptyArray()
                val result = method.invoke(connection, *safeArgs)
                when (method.name) {
                    "createStatement" -> wrapStatement(result as Statement, preparedSql = null)
                    "prepareStatement" -> wrapStatement(result as PreparedStatement, preparedSql = safeArgs.firstOrNull() as? String)
                    "prepareCall" -> wrapStatement(result as CallableStatement, preparedSql = safeArgs.firstOrNull() as? String)
                    else -> result
                }
            } as Connection
        }

        private fun wrapStatement(statement: Statement, preparedSql: String?): Statement {
            val interfaces = when (statement) {
                is CallableStatement -> arrayOf(CallableStatement::class.java)
                is PreparedStatement -> arrayOf(PreparedStatement::class.java)
                else -> arrayOf(Statement::class.java)
            }
            return Proxy.newProxyInstance(
                statement.javaClass.classLoader,
                interfaces,
            ) { _, method, args ->
                val safeArgs = args ?: emptyArray()
                if (method.name in EXECUTE_METHOD_NAMES) {
                    val sql = (safeArgs.firstOrNull() as? String) ?: preparedSql
                    record(sql)
                }
                method.invoke(statement, *safeArgs)
            } as Statement
        }

        private companion object {
            private val EXECUTE_METHOD_NAMES = setOf(
                "execute",
                "executeQuery",
                "executeUpdate",
                "executeLargeUpdate",
                "executeBatch",
                "executeLargeBatch",
            )
        }
    }

    @TestConfiguration
    class SqlStatementCounterConfig {
        @Bean
        fun sqlStatementTracker(): SqlStatementTracker = SqlStatementTracker()

        @Bean
        fun countingDataSourceBeanPostProcessor(tracker: SqlStatementTracker): BeanPostProcessor {
            return object : BeanPostProcessor {
                override fun postProcessAfterInitialization(bean: Any, beanName: String): Any {
                    return if (bean is DataSource) {
                        tracker.wrap(bean)
                    } else {
                        bean
                    }
                }
            }
        }
    }
}
