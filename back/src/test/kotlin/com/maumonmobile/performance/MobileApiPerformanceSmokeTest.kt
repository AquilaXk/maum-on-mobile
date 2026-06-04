package com.maumonmobile.performance

import com.fasterxml.jackson.databind.ObjectMapper
import com.jayway.jsonpath.JsonPath
import com.maumonmobile.adapter.`in`.web.auth.signupVerifiedMember
import org.assertj.core.api.Assertions.assertThat
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import kotlin.io.path.Path
import kotlin.io.path.createDirectories
import kotlin.math.ceil
import kotlin.system.measureTimeMillis

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test", "performance")
class MobileApiPerformanceSmokeTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {
    private val objectMapper = ObjectMapper()

    @org.junit.jupiter.api.Test
    fun coreMobileApiFlowStaysWithinSmokeBudget() {
        val samples = mutableListOf<ApiSmokeSample>()
        val sampleCount = envLong("MOBILE_PERFORMANCE_SAMPLES", 3).coerceIn(1, 20).toInt()
        val p95BudgetMs = envLong("MOBILE_PERFORMANCE_P95_BUDGET_MS", 2_500L)
        val maxErrorRate = envDouble("MOBILE_PERFORMANCE_ERROR_RATE_BUDGET", 0.01)
        val minSuccessRate = envDouble("MOBILE_PERFORMANCE_MIN_SUCCESS_RATE", 0.99)
        val runId = "mobile-smoke-${System.nanoTime()}"

        repeat(sampleCount) { index ->
            samples += runScenario(index, runId)
        }

        val p95LatencyMs = percentile(samples.map { sample -> sample.elapsedMs }, 0.95)
        val successRate = samples.count(ApiSmokeSample::success).toDouble() / samples.size
        val errorRate = 1 - successRate
        val status = if (
            p95LatencyMs <= p95BudgetMs &&
            errorRate <= maxErrorRate &&
            successRate >= minSuccessRate
        ) {
            "pass"
        } else {
            "fail"
        }
        val report = MobilePerformanceReport(
            runId = runId,
            profile = "performance",
            status = status,
            summary = MobilePerformanceSummary(
                sampleCount = samples.size,
                p95LatencyMs = p95LatencyMs,
                successRate = successRate,
                errorRate = errorRate,
                budgets = MobilePerformanceBudgets(
                    p95LatencyMs = p95BudgetMs,
                    maxErrorRate = maxErrorRate,
                    minSuccessRate = minSuccessRate,
                ),
            ),
            scenarios = samples
                .groupBy { sample -> sample.scenario }
                .map { (scenario, scenarioSamples) ->
                    MobilePerformanceScenarioReport(
                        scenario = scenario,
                        status = if (scenarioSamples.all(ApiSmokeSample::success)) "pass" else "fail",
                        endpoints = scenarioSamples.map(ApiSmokeSample::toEndpointReport),
                    )
                },
            cleanup = MobilePerformanceCleanup(
                deletedRecords = 0,
                retainedRecords = sampleCount,
            ),
            reproduce = "MOBILE_PERFORMANCE_SAMPLES=$sampleCount tools/ci/run-mobile-performance-smoke.sh",
        )

        writeReport(report)
        println(
            "mobile-api-smoke p95Ms=$p95LatencyMs successRate=$successRate " +
                samples.joinToString(separator = " ") { sample -> "${sample.name}=${sample.elapsedMs}ms" },
        )

        assertThat(status).isEqualTo("pass")
    }

    private fun runScenario(index: Int, runId: String): List<ApiSmokeSample> {
        val samples = mutableListOf<ApiSmokeSample>()
        var accessToken = ""
        var adminAccessToken = ""
        var postId = 0
        val email = "smoke-$runId-$index@example.com"

        val reset = measure("performance.reset", "auth.session", "POST /api/v1/performance/test-data/reset") {
            mockMvc.post("/api/v1/performance/test-data/reset") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"scenario":"operations.actions","memberCount":3}"""
            }
                .andReturn()
                .response
        }
        samples += reset.sample
        assertThat(reset.response.status).isEqualTo(200)
        val adminEmail = reset.response.readJsonString("$.data.admin.email")
        val adminPassword = reset.response.readJsonString("$.data.password")

        val signup = measure("auth.signup", "auth.session", "POST /api/v1/auth/signup") {
            mockMvc.signupVerifiedMember(
                email = email,
                password = "pass1234",
                nickname = "스모크",
            )
                .andReturn()
                .response
        }
        samples += signup.sample
        assertThat(signup.response.status).isEqualTo(200)

        val login = measure("auth.login", "auth.session", "POST /api/v1/auth/login") {
            mockMvc.post("/api/v1/auth/login") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"email":"$email","password":"pass1234"}"""
            }
                .andReturn()
                .response
        }
        samples += login.sample
        assertThat(login.response.status).isEqualTo(200)
        accessToken = login.response.readJsonString("$.data.accessToken")

        val adminLogin = measure("auth.adminLogin", "operations.actions", "POST /api/v1/auth/login") {
            mockMvc.post("/api/v1/auth/login") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"email":"$adminEmail","password":"$adminPassword"}"""
            }
                .andReturn()
                .response
        }
        samples += adminLogin.sample
        assertThat(adminLogin.response.status).isEqualTo(200)
        adminAccessToken = adminLogin.response.readJsonString("$.data.accessToken")

        samples += measureOk("auth.session", "auth.session", "GET /api/v1/auth/session") {
            mockMvc.get("/api/v1/auth/session") {
                header("Authorization", "Bearer $accessToken")
            }
                .andReturn()
                .response
        }
        samples += measureOk("home.stats", "home.feed", "GET /api/v1/home/stats") {
            mockMvc.get("/api/v1/home/stats")
                .andReturn()
                .response
        }
        samples += measureOk("diary.create", "diary.write", "POST /api/v1/diaries") {
            mockMvc.perform(
                multipart("/api/v1/diaries")
                    .file(jsonPart("data", """{"title":"성능 기록","content":"반복 점검","categoryName":"감정","isPrivate":false}"""))
                    .header("Authorization", "Bearer $accessToken"),
            )
                .andReturn()
                .response
        }
        samples += measureOk("diary.list", "diary.write", "GET /api/v1/diaries") {
            mockMvc.get("/api/v1/diaries") {
                header("Authorization", "Bearer $accessToken")
            }
                .andReturn()
                .response
        }

        val story = measure("story.create", "story.feed", "POST /api/v1/posts") {
            mockMvc.post("/api/v1/posts") {
                header("Authorization", "Bearer $accessToken")
                contentType = MediaType.APPLICATION_JSON
                content = """{"title":"성능 점검","content":"핵심 흐름 확인","category":"WORRY"}"""
            }
                .andReturn()
                .response
        }
        samples += story.sample
        assertThat(story.response.status).isEqualTo(200)
        postId = story.response.readJsonInt("$.data")

        samples += measureOk("story.list", "story.feed", "GET /api/v1/posts") {
            mockMvc.get("/api/v1/posts")
                .andReturn()
                .response
        }
        samples += measureOk("letter.stats", "letter.flow", "GET /api/v1/letters/stats") {
            mockMvc.get("/api/v1/letters/stats") {
                header("Authorization", "Bearer $accessToken")
            }
                .andReturn()
                .response
        }
        samples += measureOk("letter.create", "letter.flow", "POST /api/v1/letters") {
            mockMvc.post("/api/v1/letters") {
                header("Authorization", "Bearer $accessToken")
                contentType = MediaType.APPLICATION_JSON
                content = """{"title":"성능 편지","content":"흐름 점검"}"""
            }
                .andReturn()
                .response
        }
        samples += measureOk("notification.list", "notification.flow", "GET /api/v1/notifications") {
            mockMvc.get("/api/v1/notifications") {
                header("Authorization", "Bearer $accessToken")
            }
                .andReturn()
                .response
        }
        samples += measureOk("report.create", "report.flow", "POST /api/v1/reports") {
            mockMvc.post("/api/v1/reports") {
                header("Authorization", "Bearer $accessToken")
                contentType = MediaType.APPLICATION_JSON
                content = """{"targetId":$postId,"targetType":"POST","reason":"SPAM","content":"도배 의심"}"""
            }
                .andReturn()
                .response
        }
        samples += measureOk("operations.dashboard", "operations.actions", "GET /api/v1/admin/dashboard") {
            mockMvc.get("/api/v1/admin/dashboard") {
                header("Authorization", "Bearer $adminAccessToken")
            }
                .andReturn()
                .response
        }
        samples += measureOk("operations.metrics", "operations.actions", "GET /api/v1/observability/api-metrics") {
            mockMvc.get("/api/v1/observability/api-metrics") {
                header("Authorization", "Bearer $adminAccessToken")
            }
                .andReturn()
                .response
        }

        return samples
    }

    private fun measureOk(
        name: String,
        scenario: String,
        endpoint: String,
        block: () -> MockHttpServletResponse,
    ): ApiSmokeSample {
        val measured = measure(name, scenario, endpoint, block)
        assertThat(measured.response.status).isBetween(200, 399)
        return measured.sample
    }

    private fun measure(
        name: String,
        scenario: String,
        endpoint: String,
        block: () -> MockHttpServletResponse,
    ): MeasuredResponse {
        lateinit var response: MockHttpServletResponse
        val elapsedMs = measureTimeMillis {
            response = block()
        }
        val success = response.status in 200..399
        return MeasuredResponse(
            response = response,
            sample = ApiSmokeSample(
                name = name,
                scenario = scenario,
                endpoint = endpoint,
                elapsedMs = elapsedMs,
                statusCode = response.status,
                success = success,
            ),
        )
    }

    private fun writeReport(report: MobilePerformanceReport) {
        val reportDir = Path(
            System.getenv("MOBILE_PERFORMANCE_REPORT_DIR")
                ?: "build/reports/mobile-performance",
        )
        reportDir.createDirectories()
        objectMapper
            .writerWithDefaultPrettyPrinter()
            .writeValue(reportDir.resolve("mobile-performance-smoke.json").toFile(), report)
    }

    private fun percentile(values: List<Long>, percentile: Double): Long {
        require(values.isNotEmpty()) { "values must not be empty" }
        require(percentile in 0.0..1.0) { "percentile must be between 0 and 1" }
        val sorted = values.sorted()
        val index = ceil(sorted.size * percentile).toInt() - 1
        return sorted[index.coerceIn(0, sorted.lastIndex)]
    }
}

private data class MeasuredResponse(
    val response: MockHttpServletResponse,
    val sample: ApiSmokeSample,
)

private data class ApiSmokeSample(
    val name: String,
    val scenario: String,
    val endpoint: String,
    val elapsedMs: Long,
    val statusCode: Int,
    val success: Boolean,
) {
    fun toEndpointReport(): MobilePerformanceEndpointReport {
        return MobilePerformanceEndpointReport(
            name = name,
            endpoint = endpoint,
            p95LatencyMs = elapsedMs,
            statusCode = statusCode,
            successRate = if (success) 1.0 else 0.0,
            errorRate = if (success) 0.0 else 1.0,
            budgetMs = envLong("MOBILE_PERFORMANCE_P95_BUDGET_MS", 2_500L),
            reproduce = "tools/ci/run-mobile-performance-smoke.sh",
        )
    }
}

private data class MobilePerformanceReport(
    val runId: String,
    val profile: String,
    val status: String,
    val summary: MobilePerformanceSummary,
    val scenarios: List<MobilePerformanceScenarioReport>,
    val cleanup: MobilePerformanceCleanup,
    val reproduce: String,
)

private data class MobilePerformanceSummary(
    val sampleCount: Int,
    val p95LatencyMs: Long,
    val successRate: Double,
    val errorRate: Double,
    val budgets: MobilePerformanceBudgets,
)

private data class MobilePerformanceBudgets(
    val p95LatencyMs: Long,
    val maxErrorRate: Double,
    val minSuccessRate: Double,
)

private data class MobilePerformanceScenarioReport(
    val scenario: String,
    val status: String,
    val endpoints: List<MobilePerformanceEndpointReport>,
)

private data class MobilePerformanceEndpointReport(
    val name: String,
    val endpoint: String,
    val p95LatencyMs: Long,
    val statusCode: Int,
    val successRate: Double,
    val errorRate: Double,
    val budgetMs: Long,
    val reproduce: String,
)

private data class MobilePerformanceCleanup(
    val deletedRecords: Int,
    val retainedRecords: Int,
)

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}

private fun MockHttpServletResponse.readJsonInt(path: String): Int {
    return JsonPath.read<Int>(contentAsString, path)
}

private fun jsonPart(name: String, value: String): MockMultipartFile {
    return MockMultipartFile(name, "", MediaType.APPLICATION_JSON_VALUE, value.toByteArray())
}

private fun envLong(name: String, defaultValue: Long): Long {
    return System.getenv(name)?.toLongOrNull() ?: defaultValue
}

private fun envDouble(name: String, defaultValue: Double): Double {
    return System.getenv(name)?.toDoubleOrNull() ?: defaultValue
}
