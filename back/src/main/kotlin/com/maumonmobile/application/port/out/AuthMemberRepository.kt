package com.maumonmobile.application.port.out

import com.maumonmobile.domain.auth.AuthMember

interface AuthMemberRepository {
    fun save(member: AuthMember): AuthMember

    fun findById(id: Long): AuthMember?

    fun findAllActive(): List<AuthMember>

    fun findByEmail(email: String): AuthMember?

    fun saveRefreshToken(memberId: Long, refreshToken: String)

    fun findByRefreshToken(refreshToken: String): AuthMember?

    fun revokeRefreshToken(refreshToken: String)
}
