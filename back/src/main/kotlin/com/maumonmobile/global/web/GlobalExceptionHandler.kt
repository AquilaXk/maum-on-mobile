package com.maumonmobile.global.web

import org.slf4j.LoggerFactory
import org.springframework.http.ResponseEntity
import org.springframework.security.access.AccessDeniedException
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.servlet.resource.NoResourceFoundException

@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(ApiException::class)
    fun handleApiException(exception: ApiException): ResponseEntity<ApiResponse<Nothing>> {
        return errorResponse(
            errorCode = exception.errorCode,
            message = exception.message,
        )
    }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidationException(exception: MethodArgumentNotValidException): ResponseEntity<ApiResponse<Nothing>> {
        val fieldErrors = exception.bindingResult.fieldErrors.map { fieldError ->
            ApiFieldError(
                field = fieldError.field,
                message = fieldError.defaultMessage ?: ErrorCode.VALIDATION_ERROR.defaultMessage,
            )
        }

        return errorResponse(
            errorCode = ErrorCode.VALIDATION_ERROR,
            message = ErrorCode.VALIDATION_ERROR.defaultMessage,
            fieldErrors = fieldErrors,
        )
    }

    @ExceptionHandler(AccessDeniedException::class)
    fun handleAccessDeniedException(exception: AccessDeniedException): ResponseEntity<ApiResponse<Nothing>> {
        return errorResponse(
            errorCode = ErrorCode.FORBIDDEN,
            message = exception.message ?: ErrorCode.FORBIDDEN.defaultMessage,
        )
    }

    @ExceptionHandler(NoResourceFoundException::class)
    fun handleNoResourceFoundException(exception: NoResourceFoundException): ResponseEntity<ApiResponse<Nothing>> {
        return errorResponse(
            errorCode = ErrorCode.NOT_FOUND,
            message = ErrorCode.NOT_FOUND.defaultMessage,
        )
    }

    @ExceptionHandler(Exception::class)
    fun handleException(exception: Exception): ResponseEntity<ApiResponse<Nothing>> {
        log.error("Unhandled API exception", exception)

        return errorResponse(
            errorCode = ErrorCode.INTERNAL_SERVER_ERROR,
            message = ErrorCode.INTERNAL_SERVER_ERROR.defaultMessage,
        )
    }

    private fun errorResponse(
        errorCode: ErrorCode,
        message: String,
        fieldErrors: List<ApiFieldError> = emptyList(),
    ): ResponseEntity<ApiResponse<Nothing>> {
        val error = ApiError(
            code = errorCode.name,
            message = message,
            fieldErrors = fieldErrors,
        )

        return ResponseEntity
            .status(errorCode.httpStatus)
            .body(ApiResponse.failure(error))
    }

    private companion object {
        private val log = LoggerFactory.getLogger(GlobalExceptionHandler::class.java)
    }
}
