package com.maumonmobile.global.security

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter

@Component
class JwtAuthenticationFilter(
    private val jwtTokenProvider: JwtTokenProvider,
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        val token = resolveBearerToken(request)

        if (token != null && SecurityContextHolder.getContext().authentication == null) {
            jwtTokenProvider.authenticate(token)?.let { authentication ->
                SecurityContextHolder.getContext().authentication = authentication
            }
        }

        filterChain.doFilter(request, response)
    }

    private fun resolveBearerToken(request: HttpServletRequest): String? {
        val authorization = request.getHeader("Authorization") ?: return null

        return if (authorization.startsWith(BEARER_PREFIX, ignoreCase = true)) {
            authorization.substring(BEARER_PREFIX.length).trim().takeIf { token -> token.isNotEmpty() }
        } else {
            null
        }
    }

    private companion object {
        private const val BEARER_PREFIX = "Bearer "
    }
}
