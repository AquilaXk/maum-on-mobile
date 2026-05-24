package com.maumonmobile.adapter.out.persistence.auth

import com.maumonmobile.application.port.out.AuthMemberRepository
import com.maumonmobile.domain.auth.AuthMember
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
}
