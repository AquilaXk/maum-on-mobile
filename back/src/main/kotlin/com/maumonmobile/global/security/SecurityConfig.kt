package com.maumonmobile.global.security

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.core.env.Environment
import org.springframework.core.env.Profiles
import org.springframework.http.HttpMethod
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter

@Configuration(proxyBeanMethods = false)
@EnableWebSecurity
class SecurityConfig(
    private val jwtAuthenticationFilter: JwtAuthenticationFilter,
    private val restAuthenticationEntryPoint: RestAuthenticationEntryPoint,
    private val environment: Environment,
) {

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain {
        http
            .csrf { csrf -> csrf.disable() }
            .sessionManagement { session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .exceptionHandling { exceptionHandling ->
                exceptionHandling.authenticationEntryPoint(restAuthenticationEntryPoint)
            }
            .authorizeHttpRequests { authorize ->
                authorize
                    .requestMatchers("/api/health", "/actuator/health")
                    .permitAll()
                if (environment.acceptsProfiles(Profiles.of("performance"))) {
                    authorize
                        .requestMatchers("/api/v1/performance/**")
                        .permitAll()
                }
                if (environment.acceptsProfiles(Profiles.of("store-review-seed"))) {
                    authorize
                        .requestMatchers("/api/v1/store-review/test-data/**")
                        .permitAll()
                }
                authorize
                    .requestMatchers(
                        HttpMethod.GET,
                        "/api/v1/posts",
                        "/api/v1/posts/*",
                        "/api/v1/posts/*/comments",
                        "/api/v1/home/stats",
                        "/api/v1/diaries/public",
                        "/api/v1/letters/*/status",
                        "/api/v1/notifications/subscribe",
                    )
                    .permitAll()
                    .requestMatchers(
                        "/api/v1/auth/signup",
                        "/api/v1/auth/signup/**",
                        "/api/v1/auth/login",
                        "/api/v1/auth/refresh",
                        "/api/v1/auth/logout",
                        "/api/v1/auth/password-reset/**",
                        "/api/v1/auth/oidc/**",
                    )
                    .permitAll()
                    .requestMatchers("/api/v1/observability/**")
                    .hasRole("ADMIN")
                    .requestMatchers("/api/v1/admin/**")
                    .hasRole("ADMIN")
                    .anyRequest()
                    .authenticated()
            }
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter::class.java)

        return http.build()
    }

    @Bean
    fun passwordEncoder(): PasswordEncoder = BCryptPasswordEncoder()
}
