package com.maumonmobile.application.port.out

import java.time.Instant

interface SignupEmailVerificationMailSender {
    fun send(command: SignupEmailVerificationMailCommand)
}

data class SignupEmailVerificationMailCommand(
    val email: String,
    val code: String,
    val expiresAt: Instant,
)
