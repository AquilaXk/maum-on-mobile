package com.maumonmobile.adapter.`in`.web.health

import com.maumonmobile.application.service.CheckHealthService
import com.maumonmobile.global.security.JwtAuthenticationFilter
import org.junit.jupiter.api.Test
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.ComponentScan
import org.springframework.context.annotation.FilterType
import org.springframework.context.annotation.Import
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@WebMvcTest(
    controllers = [HealthController::class],
    excludeFilters = [
        ComponentScan.Filter(
            type = FilterType.ASSIGNABLE_TYPE,
            classes = [JwtAuthenticationFilter::class],
        ),
    ],
)
@AutoConfigureMockMvc(addFilters = false)
@Import(CheckHealthService::class)
class HealthControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun healthReturnsOk() {
        mockMvc.perform(get("/api/health"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.status").value("ok"))
            .andExpect(jsonPath("$.error").doesNotExist())
    }
}
