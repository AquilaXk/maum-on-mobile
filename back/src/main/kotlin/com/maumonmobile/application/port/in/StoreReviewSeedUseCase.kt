package com.maumonmobile.application.port.`in`

data class StoreReviewSeedCommand(
    val dryRun: Boolean,
    val seedSecret: String?,
)

data class StoreReviewSeedResult(
    val dryRun: Boolean,
    val profile: String,
    val accounts: List<StoreReviewSeedAccountResult>,
    val testDataScope: List<String>,
    val records: List<StoreReviewSeedRecordResult>,
    val createdRecords: Int,
    val retainedRecords: Int,
    val reviewerNotes: StoreReviewSeedReviewerNotes,
)

data class StoreReviewSeedAccountResult(
    val id: Long?,
    val accountId: String,
    val role: String,
    val email: String?,
    val emailSecretName: String,
    val passwordSecretName: String,
    val accessPaths: List<String>,
)

data class StoreReviewSeedRecordResult(
    val area: String,
    val created: Int,
    val retained: Int,
)

data class StoreReviewSeedReviewerNotes(
    val inputLocation: String,
    val secretNames: List<String>,
    val accountRoles: List<String>,
    val accessPaths: List<String>,
    val testDataScope: List<String>,
)

interface StoreReviewSeedUseCase {
    fun seed(command: StoreReviewSeedCommand): StoreReviewSeedResult
}
