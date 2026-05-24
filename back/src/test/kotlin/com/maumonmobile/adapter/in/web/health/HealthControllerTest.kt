package com.maumonmobile.adapter.`in`.web.health

import com.maumonmobile.application.service.CheckHealthService
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@WebMvcTest(HealthController::class)
@Import(CheckHealthService::class)
class HealthControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun healthReturnsOk() {
        mockMvc.perform(get("/api/health"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("ok"))
    }
}
