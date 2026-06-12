package com.maumonmobile.adapter.`in`.web.contract

import com.maumonmobile.domain.letter.LetterStatus
import com.maumonmobile.domain.moderation.ContentModerationCategory
import com.maumonmobile.domain.moderation.ContentModerationRiskLevel
import com.maumonmobile.domain.moderation.ContentModerationTarget
import com.maumonmobile.domain.report.ReportReason
import com.maumonmobile.domain.report.ReportTargetType
import com.maumonmobile.global.web.ErrorCode
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import tools.jackson.databind.JsonNode
import tools.jackson.databind.ObjectMapper
import java.nio.file.Files
import java.nio.file.Path

class MobileApiSnapshotContractTest {
    private val objectMapper = ObjectMapper()

    @Test
    fun sharedSnapshotsCoverEveryMobileApiArea() {
        val contract = readContract()
        val areas = snapshots(contract)
            .map { snapshot -> snapshot.requiredText("area") }
            .toSet()

        assertThat(areas)
            .containsExactlyInAnyOrder(
                "auth",
                "home",
                "diary",
                "story",
                "letter",
                "consultation",
                "notification",
                "settings",
                "moderation",
                "report",
            )
    }

    @Test
    fun sharedSnapshotsKeepCommonEnvelopePageAndErrorShapesSeparate() {
        val contract = readContract()
        val schema = contract.required("schema")
        val pageKeys = schema.requiredArray("pageKeys")
        val errorKeys = schema.requiredArray("errorKeys")

        assertThat(schema.requiredArray("envelopeKeys"))
            .containsExactly("success", "data", "error")
        assertThat(pageKeys)
            .containsExactly(
                "content",
                "page",
                "size",
                "totalElements",
                "totalPages",
                "last",
                "hasNext",
            )
        assertThat(errorKeys)
            .containsExactly("code", "message", "fieldErrors", "retryable", "cause")

        snapshots(contract).forEach { snapshot ->
            val response = snapshot.required("response")
            assertThat(response.has("success"))
                .withFailMessage("Update contracts/mobile-api/response-snapshots.json: ${snapshot.requiredText("id")} is missing success")
                .isTrue()

            if (response.required("success").asBoolean()) {
                assertThat(response.has("data"))
                    .withFailMessage("Update contracts/mobile-api/response-snapshots.json: ${snapshot.requiredText("id")} success response needs data")
                    .isTrue()
            } else {
                val error = response.required("error")
                assertRequiredKeys(error, errorKeys, snapshot.requiredText("id"))
                assertThat(error.required("fieldErrors").isArray).isTrue()
            }

            if (snapshot.requiredText("contract") == "page") {
                val data = response.required("data")
                assertRequiredKeys(data, pageKeys, snapshot.requiredText("id"))
            }
        }
    }

    @Test
    fun backendEnumsMatchSnapshotSchemaWithActionableFailures() {
        val enumValues = readContract().required("schema").required("enumValues")

        assertEnumValues(enumValues, "letterStatus", LetterStatus.entries.map { it.name })
        assertEnumValues(
            enumValues,
            "reportTargetType",
            ReportTargetType.entries.map { it.name },
        )
        assertEnumValues(enumValues, "reportReason", ReportReason.entries.map { it.name })
        assertEnumValues(
            enumValues,
            "moderationTarget",
            ContentModerationTarget.entries.map { it.name },
        )
        assertEnumValues(
            enumValues,
            "moderationRiskLevel",
            ContentModerationRiskLevel.entries.map { it.name },
        )
        assertEnumValues(
            enumValues,
            "moderationCategory",
            ContentModerationCategory.entries.map { it.name },
        )
        assertEnumValues(enumValues, "errorCode", ErrorCode.entries.map { it.name })
    }

    private fun readContract(): JsonNode {
        val path = contractPath()
        assertThat(Files.exists(path))
            .withFailMessage("Missing shared mobile API contract snapshot file: $path")
            .isTrue()
        return objectMapper.readTree(path.toFile())
    }

    private fun contractPath(): Path {
        val cwd = Path.of("").toAbsolutePath()
        val root = if (cwd.fileName.toString() == "back") cwd.parent else cwd
        return root.resolve("contracts/mobile-api/response-snapshots.json")
    }

    private fun snapshots(contract: JsonNode): List<JsonNode> {
        val snapshots = contract.required("snapshots")
        assertThat(snapshots.isArray).isTrue()
        return snapshots.toList()
    }

    private fun assertEnumValues(
        enumValues: JsonNode,
        name: String,
        expected: List<String>,
    ) {
        assertThat(enumValues.requiredArray(name))
            .withFailMessage(
                "Update contracts/mobile-api/response-snapshots.json schema.enumValues.$name and matching Kotlin/Flutter parsers together.",
            )
            .containsExactlyElementsOf(expected)
    }

    private fun assertRequiredKeys(
        node: JsonNode,
        keys: List<String>,
        snapshotId: String,
    ) {
        keys.forEach { key ->
            assertThat(node.has(key))
                .withFailMessage("Update contracts/mobile-api/response-snapshots.json: $snapshotId is missing $key")
                .isTrue()
        }
    }
}

private fun JsonNode.required(fieldName: String): JsonNode {
    val value = get(fieldName)
    assertThat(value)
        .withFailMessage("Missing required JSON field: $fieldName")
        .isNotNull()
    return value
}

private fun JsonNode.requiredText(fieldName: String): String = required(fieldName).asString()

private fun JsonNode.requiredArray(fieldName: String): List<String> {
    val value = required(fieldName)
    assertThat(value.isArray)
        .withFailMessage("Expected JSON array field: $fieldName")
        .isTrue()
    return value.map { item -> item.asString() }
}
