package com.maumonmobile.global.security

import org.springframework.security.core.Authentication
import org.springframework.stereotype.Component
import java.time.Duration

@Component
class JwtTokenProvider(
    private val jwtProperties: JwtProperties,
) {

    fun authenticate(rawToken: String): Authentication? {
        if (rawToken.isBlank()) {
            return null
        }

        // 실제 서명 검증과 클레임 매핑 전까지 임의 bearer 값은 인증하지 않는다.
        return null
    }

    fun tokenTtl(): Duration = jwtProperties.accessTokenTtl
}
