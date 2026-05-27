package com.maumonmobile.global.security

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.validation.annotation.Validated
import java.time.Duration

@Validated
@ConfigurationProperties(prefix = "app.security.jwt")
data class JwtProperties(
    @field:NotBlank
    val issuer: String,
    @field:NotBlank
    @field:Size(min = 32, message = "JWT secret must be at least 32 characters.")
    val secret: String,
    val accessTokenTtl: Duration,
)
