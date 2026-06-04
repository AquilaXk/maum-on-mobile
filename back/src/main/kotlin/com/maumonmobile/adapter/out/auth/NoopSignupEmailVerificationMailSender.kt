package com.maumonmobile.adapter.out.auth

import com.maumonmobile.application.port.out.SignupEmailVerificationMailCommand
import com.maumonmobile.application.port.out.SignupEmailVerificationMailSender
import org.slf4j.LoggerFactory
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.stereotype.Component

@Component
@ConditionalOnProperty(
    prefix = "app.auth.signup-email.mail",
    name = ["enabled"],
    havingValue = "false",
    matchIfMissing = true,
)
class NoopSignupEmailVerificationMailSender : SignupEmailVerificationMailSender {
    override fun send(command: SignupEmailVerificationMailCommand) {
        log.info("Signup email verification mail accepted for {}", command.email.maskedEmail())
    }

    private companion object {
        private val log = LoggerFactory.getLogger(NoopSignupEmailVerificationMailSender::class.java)
    }
}

private fun String.maskedEmail(): String {
    val normalized = trim()
    val atIndex = normalized.indexOf('@')
    if (atIndex <= 0 || atIndex != normalized.lastIndexOf('@')) {
        return "***"
    }

    val local = normalized.take(atIndex)
    val visibleLocal = local.take(2).ifEmpty { "*" }
    return "$visibleLocal***${normalized.substring(atIndex)}"
}
