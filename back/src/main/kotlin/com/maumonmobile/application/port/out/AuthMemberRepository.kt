package com.maumonmobile.application.port.out

import com.maumonmobile.domain.auth.AuthMember
import com.maumonmobile.domain.auth.AuthMemberRole
import com.maumonmobile.domain.auth.AuthMemberStatus

data class AuthMemberDashboardCounts(
    val receivableMemberCount: Long,
    val blockedMemberCount: Long,
    val adminMemberCount: Long,
)

interface AuthMemberRepository {
    fun save(member: AuthMember): AuthMember

    fun findById(id: Long): AuthMember?

    fun findByIds(ids: Collection<Long>): Map<Long, AuthMember>

    fun findIdsMatchingEmail(query: String): Set<Long>

    fun findAll(): List<AuthMember>

    fun findAllActive(): List<AuthMember>

    fun findPage(
        query: String?,
        status: AuthMemberStatus?,
        role: AuthMemberRole?,
        socialAccount: Boolean?,
        page: Int,
        size: Int,
    ): List<AuthMember>

    fun countMembers(
        query: String?,
        status: AuthMemberStatus?,
        role: AuthMemberRole?,
        socialAccount: Boolean?,
    ): Long

    fun countDashboardMetrics(): AuthMemberDashboardCounts

    fun findByEmail(email: String): AuthMember?

    fun saveRefreshToken(memberId: Long, refreshToken: String)

    fun findByRefreshToken(refreshToken: String): AuthMember?

    fun revokeRefreshToken(refreshToken: String): Boolean

    fun revokeRefreshTokens(memberId: Long): Int
}
