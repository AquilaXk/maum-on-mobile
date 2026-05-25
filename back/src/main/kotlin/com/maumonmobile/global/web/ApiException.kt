package com.maumonmobile.global.web

open class ApiException(
    val errorCode: ErrorCode,
    override val message: String = errorCode.defaultMessage,
    val retryable: Boolean = false,
    val reason: String = errorCode.name,
) : RuntimeException(message)
