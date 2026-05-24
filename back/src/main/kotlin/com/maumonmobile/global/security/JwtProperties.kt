package com.maumonmobile.global.security

import jakarta.validation.constraints.NotBlank
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.validation.annotation.Validated
import java.time.Duration

@Validated
@ConfigurationProperties(prefix = "app.security.jwt")
data class JwtProperties(
    @field:NotBlank
    val issuer: String,
    @field:NotBlank
    val secret: String,
    val accessTokenTtl: Duration,
)
