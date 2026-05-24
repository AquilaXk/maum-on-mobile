package com.maumonmobile.global.web

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ApiResponseTest {

    @Test
    fun successWrapsDataWithoutError() {
        val response = ApiResponse.success(mapOf("status" to "ok"))

        assertTrue(response.success)
        assertEquals(mapOf("status" to "ok"), response.data)
        assertNull(response.error)
    }

    @Test
    fun failureWrapsErrorWithoutData() {
        val error = ApiError(
            code = "INVALID_REQUEST",
            message = "요청 값이 올바르지 않습니다.",
            fieldErrors = listOf(ApiFieldError(field = "email", message = "must not be blank")),
        )

        val response = ApiResponse.failure(error)

        assertFalse(response.success)
        assertNull(response.data)
        assertEquals(error, response.error)
    }

    @Test
    fun constructorIsNotPublic() {
        assertTrue(ApiResponse::class.java.constructors.isEmpty())
    }
}
