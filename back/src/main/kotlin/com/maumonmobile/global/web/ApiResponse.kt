package com.maumonmobile.global.web

class ApiResponse<T> private constructor(
    val success: Boolean,
    val data: T? = null,
    val error: ApiError? = null,
) {
    companion object {
        fun <T> success(data: T): ApiResponse<T> = ApiResponse(
            success = true,
            data = data,
        )

        fun failure(error: ApiError): ApiResponse<Nothing> = ApiResponse(
            success = false,
            error = error,
        )
    }
}

data class ApiError(
    val code: String,
    val message: String,
    val fieldErrors: List<ApiFieldError> = emptyList(),
)

data class ApiFieldError(
    val field: String,
    val message: String,
)
