package com.maumonmobile.application.port.out

import com.maumonmobile.domain.auth.AuthOidcState

interface AuthOidcStateRepository {
    fun save(state: AuthOidcState): AuthOidcState

    fun findByState(state: String): AuthOidcState?

    fun markConsumed(id: Long, consumedAt: String)
}
