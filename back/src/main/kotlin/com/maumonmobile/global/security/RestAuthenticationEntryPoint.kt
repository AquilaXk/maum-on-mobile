package com.maumonmobile.global.security

import com.maumonmobile.global.web.ApiError
import com.maumonmobile.global.web.ApiResponse
import com.maumonmobile.global.web.ErrorCode
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.MediaType
import org.springframework.security.core.AuthenticationException
import org.springframework.security.web.AuthenticationEntryPoint
import org.springframework.stereotype.Component
import tools.jackson.databind.ObjectMapper

@Component
class RestAuthenticationEntryPoint(
    private val objectMapper: ObjectMapper,
) : AuthenticationEntryPoint {

    override fun commence(
        request: HttpServletRequest,
        response: HttpServletResponse,
        authException: AuthenticationException,
    ) {
        val errorCode = ErrorCode.UNAUTHORIZED
        val body = ApiResponse.failure(
            ApiError(
                code = errorCode.name,
                message = errorCode.defaultMessage,
            ),
        )

        response.status = errorCode.httpStatus.value()
        response.contentType = MediaType.APPLICATION_JSON_VALUE
        objectMapper.writeValue(response.outputStream, body)
    }
}
