package com.maumonmobile.application.port.out

import java.time.Instant

interface PasswordResetMailSender {
    fun send(command: PasswordResetMailCommand)
}

data class PasswordResetMailCommand(
    val email: String,
    val token: String,
    val expiresAt: Instant,
)
