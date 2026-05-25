package com.maumonmobile.adapter.`in`.web.performance

import com.jayway.jsonpath.JsonPath
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test", "performance")
class PerformanceTestDataControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun resetCreatesIndependentPerformanceActorsAndReturnsLoginContract() {
        val result = mockMvc.post("/api/v1/performance/test-data/reset") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"scenario":"operations.actions","memberCount":4}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data.profile") { value("performance") }
                jsonPath("$.data.runId") { isNotEmpty() }
                jsonPath("$.data.admin.email") { isNotEmpty() }
                jsonPath("$.data.users[0].email") { isNotEmpty() }
                jsonPath("$.data.cleanup.deletedRecords") { value(0) }
            }
            .andReturn()

        val adminEmail = result.response.readJsonString("$.data.admin.email")
        val userEmail = result.response.readJsonString("$.data.users[0].email")

        assertThat(adminEmail).contains("operations-actions-admin")
        assertThat(userEmail).contains("operations-actions-user")
    }
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
