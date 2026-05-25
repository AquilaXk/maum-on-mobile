package com.maumonmobile.application.service

import com.maumonmobile.application.port.`in`.PerformanceTestActor
import com.maumonmobile.application.port.`in`.PerformanceTestCleanupResult
import com.maumonmobile.application.port.`in`.PerformanceTestDataResetCommand
import com.maumonmobile.application.port.`in`.PerformanceTestDataResult
import com.maumonmobile.application.port.`in`.PerformanceTestDataUseCase
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import org.springframework.context.annotation.Profile
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import java.util.UUID

@Service
@Profile("performance")
class PerformanceTestDataService(
    private val authMemberRepository: AuthMemberRepository,
    private val passwordEncoder: PasswordEncoder,
) : PerformanceTestDataUseCase {

    override fun reset(command: PerformanceTestDataResetCommand): PerformanceTestDataResult {
        val scenario = command.scenario.normalizedScenario()
        val memberCount = command.memberCount.coerceIn(1, MAX_MEMBER_COUNT)
        val runId = "$scenario-${UUID.randomUUID().toString().take(8)}"
        val password = DEFAULT_PASSWORD
        val passwordHash = passwordEncoder.encode(password) ?: password
        val admin = authMemberRepository.save(
            AuthMember(
                id = 0L,
                email = "$scenario-admin-$runId@example.com",
                passwordHash = passwordHash,
                nickname = "$scenario 관리자",
                role = AuthMemberRole.ADMIN,
            ),
        )
        val users = (1..memberCount).map { index ->
            authMemberRepository.save(
                AuthMember(
                    id = 0L,
                    email = "$scenario-user-$index-$runId@example.com",
                    passwordHash = passwordHash,
                    nickname = "$scenario 사용자 $index",
                ),
            )
        }

        return PerformanceTestDataResult(
            runId = runId,
            profile = "performance",
            scenario = scenario,
            password = password,
            admin = admin.toActor(),
            users = users.map { user -> user.toActor() },
            cleanup = PerformanceTestCleanupResult(
                deletedRecords = 0,
                retainedRecords = users.size + 1,
            ),
        )
    }

    private fun AuthMember.toActor(): PerformanceTestActor {
        return PerformanceTestActor(
            id = id,
            email = email,
            nickname = nickname,
            role = role.name,
        )
    }

    private fun String.normalizedScenario(): String {
        return trim()
            .lowercase()
            .replace(Regex("[^a-z0-9-]"), "-")
            .trim('-')
            .ifEmpty { "mobile-performance" }
            .take(80)
    }

    private companion object {
        private const val DEFAULT_PASSWORD = "pass1234"
        private const val MAX_MEMBER_COUNT = 100
    }
}
