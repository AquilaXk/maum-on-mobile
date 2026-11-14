package com.maumonmobile.domain.moderation

import com.maumonmobile.adapter.out.ai.moderation.RuleBasedContentModerationClassifier
import com.maumonmobile.adapter.out.persistence.moderation.InMemoryContentModerationAuditRepository
import com.maumonmobile.application.port.out.ContentModerationClassificationRequest
import com.maumonmobile.application.service.ContentModerationService
import com.maumonmobile.global.observability.MobileApiMetricsRegistry
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.slf4j.LoggerFactory
import java.time.Duration
import kotlin.random.Random

class ModerationTextEngineTest {
    private val log = LoggerFactory.getLogger(ModerationTextEngineTest::class.java)
    private val preFilter = ContentModerationPreFilter()
    private val classifier = RuleBasedContentModerationClassifier()

    @Test
    fun `single-pass canonicalizer matches legacy regex across edge and randomized inputs`() {
        val samples = mutableListOf(
            "",
            "   \t\n\r  ",
            "Hello, WORLD! 0123456789",
            "안녕하세요! ㄱㄴㄷㄹ ㅏㅑㅓㅕ 😊✨",
            "H.T.T.P://무료-체험! ㅅㅣ발",
            "\uAC00\uD7A3\u3131\u314E\u314F\u3163",
        )
        val alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789가나다라마바사아자차카타파하힣ㄱㄴㄷㅅㅂㅈㅎㅏㅣ!@#\$%^&*()_+-=[]{}|;':,.<>?/ \n\t"
        val random = Random(42)
        repeat(500) {
            val len = random.nextInt(0, 80)
            val sb = StringBuilder(len)
            repeat(len) { sb.append(alphabet[random.nextInt(alphabet.length)]) }
            samples += sb.toString()
        }

        val referenceRegex = Regex("""[^0-9a-z가-힣ㄱ-ㅎㅏ-ㅣ]+""")
        for (sample in samples) {
            val expected = sample.lowercase().replace(referenceRegex, "")
            val actual = ModerationTextEngine.compactForModeration(sample)
            assertEquals(expected, actual, "Mismatch on input='$sample'")
        }
    }

    @Test
    fun `64-bit Myers scanner matches windowed reference Levenshtein similarity across fuzz inputs`() {
        val fuzzyTerms = listOf(
            "she발", "개새끼", "느금마", "니애미", "죽고싶", "해치고싶", "때리고싶", "성폭력", "섬노예", "자살", "시발",
        )
        val probeTexts = mutableListOf(
            "",
            "개",
            "개새",
            "개새벽",
            "개1새끼",
            "해치고",
            "해치고십",
            "해a치고싶",
            "느a금마",
            "니애a미",
            "오늘 산책하면서 따뜻한 차를 마셨어요.",
            "섬1노예이야기",
        )
        val corpusChars = "가나다라마바사개새끼시발해치고싶따뜻한차마음온abc123"
        val random = Random(99)
        repeat(500) {
            val len = random.nextInt(1, 35)
            val sb = StringBuilder(len)
            repeat(len) { sb.append(corpusChars[random.nextInt(corpusChars.length)]) }
            probeTexts += sb.toString()
        }

        for (raw in probeTexts) {
            val compact = ModerationTextEngine.compactForModeration(raw)
            val engineAnyMatch = ModerationTextEngine.containsAnySuspiciousFuzzyTerm(compact)
            val refAnyMatch = fuzzyTerms.any { term ->
                referenceMaxSimilarity(compact, ModerationTextEngine.compactForModeration(term)) >=
                    ModerationTextEngine.SUSPICION_SIMILARITY_THRESHOLD
            }
            assertEquals(refAnyMatch, engineAnyMatch, "Fuzzy decision mismatch for compact='$compact'")

            for (term in fuzzyTerms) {
                val termCompact = ModerationTextEngine.compactForModeration(term)
                val engineSim = ModerationTextEngine.maxSimilarityTo(compact, term)
                val refSim = referenceMaxSimilarity(compact, termCompact)
                assertEquals(refSim, engineSim, 1e-12, "Similarity mismatch for compact='$compact' term='$termCompact'")
                assertEquals(
                    refSim >= ModerationTextEngine.SUSPICION_SIMILARITY_THRESHOLD,
                    ModerationTextEngine.matchesWithinSimilarity(compact, termCompact),
                    "Threshold match mismatch for compact='$compact' term='$termCompact'",
                )
            }
        }
    }

    @Test
    fun `pre-filter scans past 2000 chars preventing padding bypass and fails closed over 20000 chars`() {
        val cleanLong = "오늘도 조용히 숨을 고르며 산책했어요. ".repeat(200)
        assertTrue(cleanLong.length in 2_001..20_000)
        assertEquals(ContentModerationPreFilterAction.ALLOW, preFilter.evaluate(ContentModerationTarget.DIARY, cleanLong).action)

        val paddedBypassAttempt = "가".repeat(2_005) + "개새끼"
        val blocked = preFilter.evaluate(ContentModerationTarget.DIARY, paddedBypassAttempt)
        assertEquals(ContentModerationPreFilterAction.BLOCK, blocked.action)
        assertTrue(ContentModerationCategory.PROFANITY in blocked.categories)

        val oversized = "가".repeat(ModerationTextEngine.MAX_MODERATION_SCAN_LENGTH + 1)
        val preFilteredOversized = preFilter.evaluate(ContentModerationTarget.STORY, oversized)
        assertEquals(ContentModerationPreFilterAction.BLOCK, preFilteredOversized.action)
        assertEquals(listOf(ContentModerationCategory.INAPPROPRIATE), preFilteredOversized.categories)

        val classifiedOversized = classifier.classify(
            ContentModerationClassificationRequest(
                target = ContentModerationTarget.STORY,
                text = oversized,
                timeout = Duration.ofSeconds(1),
            ),
        )
        assertFalse(classifiedOversized.allowed)
        assertEquals(ContentModerationRiskLevel.HIGH, classifiedOversized.riskLevel)
        assertTrue(ContentModerationCategory.INAPPROPRIATE in classifiedOversized.categories)

        val service = ContentModerationService(
            contentModerationClassifier = classifier,
            metricsRegistry = MobileApiMetricsRegistry(),
            auditRepository = InMemoryContentModerationAuditRepository(),
            moderationTimeout = Duration.ofSeconds(1),
            preFilter = preFilter,
        )
        val serviceResult = service.reviewForService(ContentModerationTarget.DIARY, 1L, oversized)
        assertFalse(serviceResult.allowed)
        assertTrue(ContentModerationCategory.INAPPROPRIATE in serviceResult.categories)
    }

    @Test
    fun `whitespace token counter and hangul arithmetic helper match invariants`() {
        val cases = listOf("", "   ", "hello", "  one   two\tthree\nfour  ")
        for (c in cases) {
            val normalized = c.trim()
            val expected = normalized.split(Regex("\\s+")).count(String::isNotBlank)
            assertEquals(expected, ModerationTextEngine.countWhitespaceTokens(normalized))
        }
        assertArrayEquals(intArrayOf(0, 0, 0), ModerationTextEngine.decomposeHangulSyllableIndices('가'))
        assertArrayEquals(intArrayOf(18, 20, 27), ModerationTextEngine.decomposeHangulSyllableIndices('힣'))
        assertNull(ModerationTextEngine.decomposeHangulSyllableIndices('A'))
    }

    @Test
    fun `benchmark Aho-Corasick and Myers vs legacy regex Levenshtein baseline`() {
        val payload = ("오늘은 마음이 잔잔해서 따뜻한 차를 한 잔 마시며 천천히 호흡을 가다듬었어요. ").repeat(400)
        require(payload.length > 10_000)

        // Warmup
        repeat(20) {
            preFilter.evaluate(ContentModerationTarget.DIARY, payload)
            legacyPreFilterEvaluate(payload)
        }

        val iterations = 100
        val legacyStart = System.nanoTime()
        repeat(iterations) {
            legacyPreFilterEvaluate(payload)
        }
        val legacyMicros = (System.nanoTime() - legacyStart) / (iterations * 1_000.0)

        val engineStart = System.nanoTime()
        repeat(iterations) {
            preFilter.evaluate(ContentModerationTarget.DIARY, payload)
        }
        val engineMicros = (System.nanoTime() - engineStart) / (iterations * 1_000.0)

        log.info(
            "Moderation 16KB scan benchmark: legacy={} us/op, engine={} us/op, speedup={}x",
            String.format("%.1f", legacyMicros),
            String.format("%.1f", engineMicros),
            String.format("%.1f", if (engineMicros > 0.0) legacyMicros / engineMicros else 0.0),
        )
        assertTrue(engineMicros < legacyMicros, "Expected engine ($engineMicros us) < legacy ($legacyMicros us)")
    }

    private fun legacyPreFilterEvaluate(text: String): Boolean {
        val regex = Regex("""[^0-9a-z가-힣ㄱ-ㅎㅏ-ㅣ]+""")
        val compact = text.lowercase().replace(regex, "")
        val fuzzyTerms = listOf("she발", "개새끼", "느금마", "니애미", "죽고싶", "해치고싶", "때리고싶", "성폭력", "섬노예")
        return fuzzyTerms.any { term -> referenceMaxSimilarity(compact, term) >= 0.67 }
    }

    private fun referenceMaxSimilarity(source: String, term: String): Double {
        if (source.isBlank() || term.isBlank()) return 0.0
        if (source.contains(term)) return 1.0
        val lengths = listOf(term.length, term.length + 1)
            .filter { it > 0 && it <= source.length }
            .distinct()
        return lengths
            .flatMap { length -> if (source.length <= length) listOf(source) else source.windowed(length) }
            .maxOfOrNull { candidate ->
                val maxLen = maxOf(candidate.length, term.length)
                1.0 - referenceLevenshtein(candidate, term).toDouble() / maxLen.toDouble()
            }
            ?: (1.0 - referenceLevenshtein(source, term).toDouble() / maxOf(source.length, term.length).toDouble())
    }

    private fun referenceLevenshtein(a: String, b: String): Int {
        var prev = IntArray(b.length + 1) { it }
        var curr = IntArray(b.length + 1)
        for (i in a.indices) {
            curr[0] = i + 1
            for (j in b.indices) {
                val cost = if (a[i] == b[j]) 0 else 1
                curr[j + 1] = minOf(curr[j] + 1, prev[j + 1] + 1, prev[j] + cost)
            }
            val tmp = prev
            prev = curr
            curr = tmp
        }
        return prev[b.length]
    }
}
