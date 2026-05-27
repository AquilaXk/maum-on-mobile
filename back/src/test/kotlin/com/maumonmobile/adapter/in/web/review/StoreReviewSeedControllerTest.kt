package com.maumonmobile.adapter.`in`.web.review

import com.jayway.jsonpath.JsonPath
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment.MOCK
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.hamcrest.Matchers.greaterThanOrEqualTo

@SpringBootTest(webEnvironment = MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test", "store-review-seed")
@TestPropertySource(
    properties = [
        "app.store-review.seed.enabled=true",
        "app.store-review.seed.secret=review-seed-secret",
        "app.store-review.seed.reviewer.email=reviewer-controller@example.com",
        "app.store-review.seed.reviewer.password=reviewer-controller-password",
        "app.store-review.seed.operations.email=operations-controller@example.com",
        "app.store-review.seed.operations.password=operations-controller-password",
    ],
)
class StoreReviewSeedControllerTest @Autowired constructor(
    private val mockMvc: MockMvc,
) {

    @Test
    fun seedEndpointRequiresSecretHeaderAndSupportsDryRun() {
        mockMvc.post("/api/v1/store-review/test-data/seed") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"dryRun":true}"""
        }
            .andExpect {
                status { isForbidden() }
                jsonPath("$.error.code") { value("FORBIDDEN") }
            }

        mockMvc.post("/api/v1/store-review/test-data/seed") {
            header("X-Maumon-Review-Seed-Secret", "review-seed-secret")
            contentType = MediaType.APPLICATION_JSON
            content = """{"dryRun":true}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.dryRun") { value(true) }
                jsonPath("$.data.profile") { value("store-review-seed") }
                jsonPath("$.data.createdRecords") { value(0) }
                jsonPath("$.data.reviewerNotes.inputLocation") { value("App Store Connect and Play Console review notes") }
            }
    }

    @Test
    fun seedCreatesLoginableReviewerAndOperationsAccountsWithAdminBoundary() {
        mockMvc.post("/api/v1/store-review/test-data/seed") {
            header("X-Maumon-Review-Seed-Secret", "review-seed-secret")
            contentType = MediaType.APPLICATION_JSON
            content = """{"dryRun":false}"""
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.dryRun") { value(false) }
                jsonPath("$.data.accounts[0].passwordSecretName") { exists() }
                jsonPath("$.data.testDataScope[0]") { exists() }
            }

        val reviewerToken = login("reviewer-controller@example.com", "reviewer-controller-password")
        val operationsToken = login("operations-controller@example.com", "operations-controller-password")

        mockMvc.get("/api/v1/admin/dashboard") {
            header("Authorization", "Bearer $reviewerToken")
        }
            .andExpect {
                status { isForbidden() }
            }

        mockMvc.get("/api/v1/admin/dashboard") {
            header("Authorization", "Bearer $operationsToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.adminMemberCount") { value(greaterThanOrEqualTo(1)) }
            }

        mockMvc.post("/api/v1/members/me/data-exports") {
            header("Authorization", "Bearer $reviewerToken")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.data.status") { value("COMPLETED") }
            }
    }

    private fun login(email: String, password: String): String {
        val response = mockMvc.post("/api/v1/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"$email","password":"$password"}"""
        }
            .andExpect {
                status { isOk() }
            }
            .andReturn()
            .response

        val accessToken = response.readJsonString("$.data.accessToken")
        assertThat(accessToken).isNotBlank()
        return accessToken
    }
}

private fun MockHttpServletResponse.readJsonString(path: String): String {
    return JsonPath.read<String>(contentAsString, path)
}
