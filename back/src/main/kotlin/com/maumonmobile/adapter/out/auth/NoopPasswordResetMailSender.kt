package com.maumonmobile.adapter.out.auth

import com.maumonmobile.application.port.out.PasswordResetMailCommand
import com.maumonmobile.application.port.out.PasswordResetMailSender
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

@Component
class NoopPasswordResetMailSender : PasswordResetMailSender {
    override fun send(command: PasswordResetMailCommand) {
        log.info("Password reset mail accepted for {}", command.email)
    }

    private companion object {
        private val log = LoggerFactory.getLogger(NoopPasswordResetMailSender::class.java)
    }
}
