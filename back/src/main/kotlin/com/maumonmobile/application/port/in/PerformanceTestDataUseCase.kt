package com.maumonmobile.application.port.`in`

data class PerformanceTestDataResetCommand(
    val scenario: String,
    val memberCount: Int,
)

data class PerformanceTestDataResult(
    val runId: String,
    val profile: String,
    val scenario: String,
    val password: String,
    val admin: PerformanceTestActor,
    val users: List<PerformanceTestActor>,
    val cleanup: PerformanceTestCleanupResult,
)

data class PerformanceTestActor(
    val id: Long,
    val email: String,
    val nickname: String,
    val role: String,
)

data class PerformanceTestCleanupResult(
    val deletedRecords: Int,
    val retainedRecords: Int,
)

interface PerformanceTestDataUseCase {
    fun reset(command: PerformanceTestDataResetCommand): PerformanceTestDataResult
}
