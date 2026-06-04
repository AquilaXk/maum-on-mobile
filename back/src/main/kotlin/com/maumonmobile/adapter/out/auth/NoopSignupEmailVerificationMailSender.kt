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
        log.info("Signup email verification mail accepted for {}", command.email)
    }

    private companion object {
        private val log = LoggerFactory.getLogger(NoopSignupEmailVerificationMailSender::class.java)
    }
}
