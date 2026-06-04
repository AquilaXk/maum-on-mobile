package com.maumonmobile.adapter.`in`.web.auth

import com.maumonmobile.application.port.out.SignupEmailVerificationMailCommand
import com.maumonmobile.application.port.out.SignupEmailVerificationMailSender
import org.springframework.http.MediaType
import org.springframework.context.annotation.Primary
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post
import java.util.concurrent.CopyOnWriteArrayList

fun MockMvc.signupVerifiedMember(
    email: String,
    password: String,
    nickname: String,
) = run {
    RecordingSignupEmailVerificationMailSender.clear()
    post("/api/v1/auth/signup/email-verifications") {
        contentType = MediaType.APPLICATION_JSON
        content = """{"email":"${email.jsonString()}"}"""
    }
        .andExpect {
            status { isAccepted() }
            jsonPath("$.data.accepted") { value(true) }
        }

    val code = RecordingSignupEmailVerificationMailSender.sent.single().code
    post("/api/v1/auth/signup") {
        contentType = MediaType.APPLICATION_JSON
        content =
            """
            {
              "email":"${email.jsonString()}",
              "password":"${password.jsonString()}",
              "nickname":"${nickname.jsonString()}",
              "emailVerificationCode":"$code"
            }
            """.trimIndent()
    }
}

@Component
@Profile("test")
@Primary
class RecordingSignupEmailVerificationMailSender : SignupEmailVerificationMailSender {
    val sent: List<SignupEmailVerificationMailCommand>
        get() = Companion.sent

    override fun send(command: SignupEmailVerificationMailCommand) {
        Companion.sent += command
    }

    fun clear() {
        Companion.clear()
    }

    companion object {
        val sent = CopyOnWriteArrayList<SignupEmailVerificationMailCommand>()

        fun clear() {
            sent.clear()
        }
    }
}

private fun String.jsonString(): String {
    return replace("\\", "\\\\").replace("\"", "\\\"")
}
