package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.application.port.out.AuthMemberDashboardCounts
import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

@Repository
@Profile("memory")
class InMemoryAuthMemberRepository : AuthMemberRepository {
    private val sequence = AtomicLong(1L)
    private val membersById = ConcurrentHashMap<Long, AuthMember>()
    private val memberIdsByEmail = ConcurrentHashMap<String, Long>()
    private val memberIdsByRefreshToken = ConcurrentHashMap<String, Long>()

    override fun save(member: AuthMember): AuthMember {
        val persistedMember = if (member.id == 0L) {
            member.copy(id = sequence.getAndIncrement())
        } else {
            member
        }

        membersById[persistedMember.id]
            ?.takeIf { existingMember -> existingMember.email != persistedMember.email }
            ?.let { existingMember -> memberIdsByEmail.remove(existingMember.email) }
        membersById[persistedMember.id] = persistedMember
        memberIdsByEmail[persistedMember.email] = persistedMember.id
        return persistedMember
    }

    override fun findById(id: Long): AuthMember? = membersById[id]

    override fun findByIds(ids: Collection<Long>): Map<Long, AuthMember> {
        if (ids.isEmpty()) {
            return emptyMap()
        }
        return buildMap {
            ids.forEach { id ->
                membersById[id]?.let { member -> put(id, member) }
            }
        }
    }

    override fun findIdsMatchingEmail(query: String): Set<Long> {
        val normalized = query.trim().lowercase()
        if (normalized.isEmpty()) {
            return emptySet()
        }
        return membersById.values
            .filter { member -> member.email.lowercase().contains(normalized) }
            .mapTo(mutableSetOf(), AuthMember::id)
    }

    override fun findAll(): List<AuthMember> {
        return membersById.values.sortedBy { member -> member.id }
    }

    override fun findAllActive(): List<AuthMember> {
        return membersById.values
            .filter { member -> member.status == AuthMemberStatus.ACTIVE }
            .sortedBy { member -> member.id }
    }

    override fun findPage(
        query: String?,
        status: AuthMemberStatus?,
        role: AuthMemberRole?,
        socialAccount: Boolean?,
        page: Int,
        size: Int,
    ): List<AuthMember> {
        val safePage = page.coerceAtLeast(0)
        val safeSize = size.coerceIn(1, 100)
        val filtered = filterMembers(query, status, role, socialAccount)
            .sortedBy { member -> member.id }
        val offset = (safePage.toLong() * safeSize.toLong()).coerceAtMost(filtered.size.toLong()).toInt()
        val endIndex = (offset + safeSize).coerceAtMost(filtered.size)
        return filtered.subList(offset, endIndex)
    }

    override fun countMembers(
        query: String?,
        status: AuthMemberStatus?,
        role: AuthMemberRole?,
        socialAccount: Boolean?,
    ): Long {
        return filterMembers(query, status, role, socialAccount).size.toLong()
    }

    override fun countDashboardMetrics(): AuthMemberDashboardCounts {
        var receivable = 0L
        var blocked = 0L
        var admin = 0L
        membersById.values.forEach { member ->
            if (member.status == AuthMemberStatus.ACTIVE && member.randomReceiveAllowed) {
                receivable += 1L
            }
            if (member.status == AuthMemberStatus.BLOCKED) {
                blocked += 1L
            }
            if (member.role == AuthMemberRole.ADMIN) {
                admin += 1L
            }
        }
        return AuthMemberDashboardCounts(
            receivableMemberCount = receivable,
            blockedMemberCount = blocked,
            adminMemberCount = admin,
        )
    }

    private fun filterMembers(
        query: String?,
        status: AuthMemberStatus?,
        role: AuthMemberRole?,
        socialAccount: Boolean?,
    ): List<AuthMember> {
        val normalizedQuery = query?.trim()?.lowercase()?.takeIf(String::isNotEmpty)
        return membersById.values.filter { member ->
            (status == null || member.status == status) &&
                (role == null || member.role == role) &&
                (socialAccount == null || member.socialAccount == socialAccount) &&
                (
                    normalizedQuery == null ||
                        member.email.lowercase().contains(normalizedQuery) ||
                        member.nickname.lowercase().contains(normalizedQuery)
                    )
        }
    }

    override fun findByEmail(email: String): AuthMember? {
        val memberId = memberIdsByEmail[email.trim().lowercase()] ?: return null
        return membersById[memberId]
    }

    override fun saveRefreshToken(memberId: Long, refreshToken: String) {
        memberIdsByRefreshToken[refreshToken] = memberId
    }

    override fun findByRefreshToken(refreshToken: String): AuthMember? {
        val memberId = memberIdsByRefreshToken[refreshToken] ?: return null
        return membersById[memberId]
    }

    override fun revokeRefreshToken(refreshToken: String) {
        memberIdsByRefreshToken.remove(refreshToken)
    }

    override fun revokeRefreshTokens(memberId: Long): Int {
        val tokens = memberIdsByRefreshToken.entries
            .filter { (_, tokenMemberId) -> tokenMemberId == memberId }
            .map { (refreshToken, _) -> refreshToken }
        tokens.forEach(memberIdsByRefreshToken::remove)
        return tokens.size
    }
}
