package com.maumonmobile.performance

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
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import kotlin.math.ceil
import kotlin.system.measureTimeMillis

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MobileApiPerformanceSmokeTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun coreMobileApiFlowStaysWithinSmokeBudget() {
        val samples = mutableListOf<ApiSmokeSample>()
        val email = "smoke-${System.nanoTime()}@example.com"
        var accessToken = ""
        var postId = 0

        samples += measure("auth.signup") {
            mockMvc.post("/api/v1/auth/signup") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"email":"$email","password":"pass1234","nickname":"스모크"}"""
            }
                .andExpect { status { isOk() } }
        }
        samples += measure("auth.login") {
            val result = mockMvc.post("/api/v1/auth/login") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"email":"$email","password":"pass1234"}"""
            }
                .andExpect { status { isOk() } }
                .andReturn()
            accessToken = result.response.readJsonString("$.data.accessToken")
        }
        samples += measure("home.stats") {
            mockMvc.get("/api/v1/home/stats")
                .andExpect { status { isOk() } }
        }
        samples += measure("diary.list") {
            mockMvc.get("/api/v1/diaries") {
                header("Authorization", "Bearer $accessToken")
            }
                .andExpect { status { isOk() } }
        }
        samples += measure("story.create") {
            val result = mockMvc.post("/api/v1/posts") {
                header("Authorization", "Bearer $accessToken")
                contentType = MediaType.APPLICATION_JSON
                content = """{"title":"성능 점검","content":"핵심 흐름 확인","category":"WORRY"}"""
            }
                .andExpect { status { isOk() } }
                .andReturn()
            postId = result.response.readJsonInt("$.data")
        }
        samples += measure("story.list") {
            mockMvc.get("/api/v1/posts")
                .andExpect { status { isOk() } }
        }
        samples += measure("letter.stats") {
            mockMvc.get("/api/v1/letters/stats") {
                header("Authorization", "Bearer $accessToken")
            }
                .andExpect { status { isOk() } }
        }
        samples += measure("consultation.chat") {
            mockMvc.post("/api/v1/consultations/chat") {
                header("Authorization", "Bearer $accessToken")
                contentType = MediaType.APPLICATION_JSON
                content = """{"message":"오늘 마음이 복잡해요"}"""
            }
                .andExpect { status { isOk() } }
        }
        samples += measure("notification.list") {
            mockMvc.get("/api/v1/notifications") {
                header("Authorization", "Bearer $accessToken")
            }
                .andExpect { status { isOk() } }
        }
        samples += measure("report.create") {
            mockMvc.post("/api/v1/reports") {
                header("Authorization", "Bearer $accessToken")
                contentType = MediaType.APPLICATION_JSON
                content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"도배 의심"}"""
            }
                .andExpect { status { isOk() } }
        }

        val p95LatencyMs = percentile(samples.map { sample -> sample.elapsedMs }, 0.95)
        val totalLatencyMs = samples.sumOf { sample -> sample.elapsedMs }
        println(
            "mobile-api-smoke p95Ms=$p95LatencyMs totalMs=$totalLatencyMs " +
                samples.joinToString(separator = " ") { sample -> "${sample.name}=${sample.elapsedMs}ms" },
        )

        assertThat(p95LatencyMs).isLessThanOrEqualTo(P95_LATENCY_BUDGET_MS)
        assertThat(totalLatencyMs).isLessThanOrEqualTo(TOTAL_LATENCY_BUDGET_MS)
    }

    private fun measure(name: String, block: () -> Unit): ApiSmokeSample {
        val elapsedMs = measureTimeMillis(block)
        return ApiSmokeSample(name = name, elapsedMs = elapsedMs)
    }

    private fun percentile(values: List<Long>, percentile: Double): Long {
        require(values.isNotEmpty()) { "values must not be empty" }
        require(percentile in 0.0..1.0) { "percentile must be between 0 and 1" }
        val sorted = values.sorted()
        val index = ceil(sorted.size * percentile).toInt() - 1
        return sorted[index.coerceIn(0, sorted.lastIndex)]
    }

    private companion object {
        private const val P95_LATENCY_BUDGET_MS = 2_500L
        private const val TOTAL_LATENCY_BUDGET_MS = 8_000L
    }
}

private data class ApiSmokeSample(
    val name: String,
    val elapsedMs: Long,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}
