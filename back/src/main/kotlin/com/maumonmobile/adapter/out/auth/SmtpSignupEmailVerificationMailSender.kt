package com.maumonmobile.adapter.out.auth

import com.maumonmobile.application.port.out.SignupEmailVerificationMailCommand
import com.maumonmobile.application.port.out.SignupEmailVerificationMailSender
import com.maumonmobile.global.web.ApiException
import com.maumonmobile.global.web.ErrorCode
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.mail.javamail.JavaMailSender
import org.springframework.mail.javamail.MimeMessageHelper
import org.springframework.stereotype.Component
import java.nio.charset.StandardCharsets
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Component
@ConditionalOnProperty(
    prefix = "app.auth.signup-email.mail",
    name = ["enabled"],
    havingValue = "true",
)
class SmtpSignupEmailVerificationMailSender(
    private val javaMailSender: JavaMailSender,
    @param:Value("\${app.auth.signup-email.mail.from:}")
    private val mailFrom: String,
    @param:Value("\${app.auth.signup-email.mail.subject:[Maum On] 회원가입 이메일 인증}")
    private val mailSubject: String,
) : SignupEmailVerificationMailSender {
    override fun send(command: SignupEmailVerificationMailCommand) {
        if (mailFrom.isBlank()) {
            throw ApiException(ErrorCode.INTERNAL_SERVER_ERROR, "회원가입 메일 발송 설정을 확인해 주세요.")
        }

        val expiresAtText = command.expiresAt.atZone(SEOUL_ZONE_ID).format(EXPIRES_AT_FORMATTER)
        val message = javaMailSender.createMimeMessage()
        val helper = MimeMessageHelper(message, true, StandardCharsets.UTF_8.name())
        val subject = mailSubject.trim().ifBlank { DEFAULT_SUBJECT }

        helper.setFrom(mailFrom)
        helper.setTo(command.email)
        message.setSubject(subject, StandardCharsets.UTF_8.name())
        message.setHeader("Content-Language", "ko")
        helper.setText(
            plainTextBody(command.code, expiresAtText),
            htmlBody(command.code, expiresAtText),
        )

        javaMailSender.send(message)
    }

    private fun plainTextBody(code: String, expiresAtText: String): String =
        """
        Maum On 회원가입 인증번호입니다.

        인증번호: $code

        이 번호는 $expiresAtText 까지 유효합니다.
        본인이 요청하지 않았다면 이 메일을 무시해 주세요.
        """.trimIndent()

    private fun htmlBody(code: String, expiresAtText: String): String =
        """
        <!doctype html>
        <html lang="ko">
          <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0" />
            <title>${escapeHtml(mailSubject.trim().ifBlank { DEFAULT_SUBJECT })}</title>
          </head>
          <body style="margin:0; padding:0; background-color:#f6f9ff; color:#111827; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f6f9ff; margin:0; padding:32px 0;">
              <tr>
                <td align="center" style="padding:0 16px;">
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px; margin:0 auto; background:#ffffff; border:1px solid #d9e5f6; border-radius:20px;">
                    <tr>
                      <td style="padding:32px; text-align:center;">
                        <div style="font-size:15px; font-weight:800; color:#1d4ed8; letter-spacing:0.08em;">MAUM ON</div>
                        <div style="margin-top:16px; font-size:26px; line-height:1.3; font-weight:800; color:#0f172a;">회원가입 인증번호</div>
                        <div style="margin:24px auto 8px; padding:18px 24px; display:inline-block; border-radius:16px; background:#eff6ff; color:#1d4ed8; font-size:34px; font-weight:900; letter-spacing:0.16em;">
                          ${escapeHtml(code)}
                        </div>
                        <div style="margin-top:18px; color:#475569; font-size:15px; line-height:1.7;">
                          앱의 인증번호 입력란에 위 번호를 입력해 회원가입을 계속 진행해 주세요.
                        </div>
                        <div style="margin-top:24px; padding-top:18px; border-top:1px solid #e5e7eb; color:#64748b; font-size:14px; line-height:1.7;">
                          이 번호는 <strong style="color:#334155;">${escapeHtml(expiresAtText)}</strong> 까지 유효합니다.
                        </div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </body>
        </html>
        """.trimIndent()

    private fun escapeHtml(value: String): String =
        value
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")

    private companion object {
        private const val DEFAULT_SUBJECT = "[Maum On] 회원가입 이메일 인증"
        private val SEOUL_ZONE_ID: ZoneId = ZoneId.of("Asia/Seoul")
        private val EXPIRES_AT_FORMATTER: DateTimeFormatter =
            DateTimeFormatter.ofPattern("yyyy.MM.dd HH:mm 'KST'")
    }
}
