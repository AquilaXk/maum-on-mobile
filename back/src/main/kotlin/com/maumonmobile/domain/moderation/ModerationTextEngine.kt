/*
 * Ported bit/word algorithms and canonicalization routines with source attribution:
 * 1. robert-bor/aho-corasick (Apache-2.0) & hankcs/AhoCorasickDoubleArrayTrie (Apache-2.0)
 *    - Flat IntArray-backed Aho-Corasick failure-link multi-pattern automaton with bitmask output tags.
 * 2. Myers (1999) / krisk/Fuse (Apache-2.0)
 *    - 64-bit word (Long) bit-parallel approximate string matching (peq, pv, mv, zero heap allocations).
 * 3. toss/es-hangul (MIT)
 *    - Arithmetic Hangul syllable/Jamo canonicalization (0xAC00..0xD7A3, 0x3131..0x3163).
 */
package com.maumonmobile.domain.moderation

import kotlin.math.floor

object ModerationTextEngine {
    const val MAX_MODERATION_SCAN_LENGTH = 20_000
    const val REPORT_CONTENT_MAX_LENGTH = 300
    const val SUSPICION_SIMILARITY_THRESHOLD = 0.67

    const val BIT_PRE_PROFANITY = 1 shl 0
    const val BIT_PRE_SELF_HARM = 1 shl 1
    const val BIT_PRE_VIOLENCE = 1 shl 2
    const val BIT_PRE_ABUSE = 1 shl 3
    const val BIT_SUSP_PROFANITY_ALIAS = 1 shl 4
    const val BIT_SUSP_SELF_HARM_ALIAS = 1 shl 5
    const val BIT_SUSP_VIOLENCE_ALIAS = 1 shl 6
    const val BIT_SUSP_ABUSE_ALIAS = 1 shl 7
    const val BIT_FAMILY_TARGET = 1 shl 8
    const val BIT_EXPLOITATION = 1 shl 9
    const val BIT_SPAM_COMPACT = 1 shl 10
    const val BIT_SELF_HARM_EXTRA = 1 shl 11

    const val BIT_SPAM_RAW = 1 shl 0

    const val BIT_SUSP_ALL_ALIAS =
        BIT_SUSP_PROFANITY_ALIAS or
            BIT_SUSP_SELF_HARM_ALIAS or
            BIT_SUSP_VIOLENCE_ALIAS or
            BIT_SUSP_ABUSE_ALIAS

    const val BIT_CLASSIFIER_PROFANITY = BIT_PRE_PROFANITY or BIT_SUSP_PROFANITY_ALIAS
    const val BIT_CLASSIFIER_SELF_HARM =
        BIT_PRE_SELF_HARM or BIT_SUSP_SELF_HARM_ALIAS or BIT_SELF_HARM_EXTRA
    const val BIT_CLASSIFIER_VIOLENCE = BIT_PRE_VIOLENCE or BIT_SUSP_VIOLENCE_ALIAS
    const val BIT_CLASSIFIER_ABUSE = BIT_PRE_ABUSE

    // 128-bit ASCII lookup bitmask: '0'..'9' (48..57) in low word, 'A'..'Z' (65..90) and 'a'..'z' (97..122) in high word.
    private const val ASCII_LO_ALNUM_MASK: Long = ((1L shl 10) - 1L) shl '0'.code
    private const val ASCII_HI_ALNUM_MASK: Long =
        (((1L shl 26) - 1L) shl ('A'.code - 64)) or
            (((1L shl 26) - 1L) shl ('a'.code - 64))

    // Arithmetic Hangul code constants (toss/es-hangul).
    private const val HANGUL_SYLLABLE_START = 0xAC00
    private const val HANGUL_SYLLABLE_END = 0xD7A3
    private const val HANGUL_CONSONANT_START = 0x3131
    private const val HANGUL_JAMO_END = 0x3163
    private const val HANGUL_MEDIAL_COUNT = 21
    private const val HANGUL_FINAL_COUNT = 28

    private val SPAM_RAW_TERMS = arrayOf(
        "http://",
        "https://",
        "무료체험",
        "오픈채팅",
        "카톡",
    )

    private val PRE_PROFANITY_TERMS = arrayOf(
        "시발",
        "씨발",
        "씨팔",
        "she발",
        "쉬발",
        "쉬2발",
        "야발",
        "병신",
        "개새끼",
        "꺼져",
        "좆같",
        "느금마",
        "느그엄마",
        "니엄마",
        "니애미",
    )

    private val PRE_SELF_HARM_TERMS = arrayOf(
        "죽고싶",
        "자살",
        "자해",
        "목숨을끊",
        "극단적선택",
        "끝내고싶",
    )

    private val PRE_VIOLENCE_TERMS = arrayOf(
        "죽일",
        "죽여버",
        "죽어버",
        "해치고싶",
        "때리고싶",
        "칼로",
        "복수할거",
    )

    private val PRE_ABUSE_TERMS = arrayOf(
        "학대",
        "폭행",
        "성폭력",
        "감금",
        "맞고있",
        "섬노예",
        "착취",
    )

    private val SUSP_PROFANITY_ALIASES = arrayOf(
        "ㅅㅂ",
        "ㅆㅂ",
        "ㅅㅣ발",
        "ㅂㅅ",
        "ㅄ",
        "ㅈ같",
        "쉬발",
        "쉬2발",
        "시바",
    )

    private val SUSP_SELF_HARM_ALIASES = arrayOf(
        "ㅈㅏ살",
        "ㅈㅎ",
        "ㅈㅏ해",
    )

    private val SUSP_VIOLENCE_ALIASES = arrayOf(
        "죽어",
        "ㅈㅇ버",
        "죽ㅇ버",
    )

    private val SUSP_ABUSE_ALIASES = arrayOf(
        "ㅎㄷ",
        "ㅍㅎ",
        "노예",
    )

    private val FAMILY_TARGET_TERMS = arrayOf(
        "너희어머니",
        "니어머니",
        "어머니",
        "너희엄마",
        "느그엄마",
        "니엄마",
        "엄마",
        "니애미",
        "애미",
    )

    private val EXPLOITATION_TERMS = arrayOf(
        "섬노예",
        "노예",
        "감금",
        "착취",
        "팔려",
        "학대",
    )

    private val FUZZY_SUSPICIOUS_PATTERNS: Array<MyersPattern> = arrayOf(
        "시발",
        "씨발",
        "she발",
        "쉬발",
        "병신",
        "개새끼",
        "느금마",
        "니애미",
        "자살",
        "자해",
        "죽고싶",
        "죽일",
        "해치고싶",
        "때리고싶",
        "학대",
        "폭행",
        "성폭력",
        "감금",
        "섬노예",
        "착취",
    ).map { MyersPattern.compile(compactForModeration(it)) }.toTypedArray()

    private val COMPACT_AUTOMATON: FlatAhoCorasickAutomaton = FlatAhoCorasickAutomaton.builder().apply {
        addAll(PRE_PROFANITY_TERMS, BIT_PRE_PROFANITY, compact = true)
        addAll(PRE_SELF_HARM_TERMS, BIT_PRE_SELF_HARM, compact = true)
        addAll(PRE_VIOLENCE_TERMS, BIT_PRE_VIOLENCE, compact = true)
        addAll(PRE_ABUSE_TERMS, BIT_PRE_ABUSE, compact = true)
        addAll(SUSP_PROFANITY_ALIASES, BIT_SUSP_PROFANITY_ALIAS, compact = true)
        addAll(SUSP_SELF_HARM_ALIASES, BIT_SUSP_SELF_HARM_ALIAS, compact = true)
        addAll(SUSP_VIOLENCE_ALIASES, BIT_SUSP_VIOLENCE_ALIAS, compact = true)
        addAll(SUSP_ABUSE_ALIASES, BIT_SUSP_ABUSE_ALIAS, compact = true)
        addAll(FAMILY_TARGET_TERMS, BIT_FAMILY_TARGET, compact = true)
        addAll(EXPLOITATION_TERMS, BIT_EXPLOITATION, compact = true)
        addAll(SPAM_RAW_TERMS, BIT_SPAM_COMPACT, compact = true)
        addPattern(compactForModeration("자살해"), BIT_SELF_HARM_EXTRA)
    }.build()

    private val RAW_SPAM_AUTOMATON: FlatAhoCorasickAutomaton = FlatAhoCorasickAutomaton.builder().apply {
        addAll(SPAM_RAW_TERMS, BIT_SPAM_RAW, compact = false)
    }.build()

    private val PHONE_PATTERN = Regex("""01[016789][-.\s]?\d{3,4}[-.\s]?\d{4}""")
    private val EMAIL_PATTERN = Regex("""[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}""")

    fun compactForModeration(input: String): String {
        val len = input.length
        if (len == 0) return ""
        val out = CharArray(len)
        var outLen = 0
        for (i in 0 until len) {
            val c = input[i]
            val code = c.code
            if (code < 128) {
                val bit = if (code < 64) {
                    (ASCII_LO_ALNUM_MASK ushr code) and 1L
                } else {
                    (ASCII_HI_ALNUM_MASK ushr (code - 64)) and 1L
                }
                if (bit != 0L) {
                    out[outLen++] = if (code in 'A'.code..'Z'.code) (code or 0x20).toChar() else c
                }
            } else if (isHangulSyllableCode(code) || isCompatibilityHangulJamoCode(code)) {
                out[outLen++] = c
            }
        }
        return if (outLen == 0) "" else String(out, 0, outLen)
    }

    fun isHangulSyllableCode(code: Int): Boolean =
        code in HANGUL_SYLLABLE_START..HANGUL_SYLLABLE_END

    fun isCompatibilityHangulJamoCode(code: Int): Boolean =
        code in HANGUL_CONSONANT_START..HANGUL_JAMO_END

    fun decomposeHangulSyllableIndices(syllable: Char): IntArray? {
        val offset = syllable.code - HANGUL_SYLLABLE_START
        if (offset < 0 || offset > HANGUL_SYLLABLE_END - HANGUL_SYLLABLE_START) return null
        val medialBlock = HANGUL_MEDIAL_COUNT * HANGUL_FINAL_COUNT
        val initial = offset / medialBlock
        val rem = offset % medialBlock
        val medial = rem / HANGUL_FINAL_COUNT
        val finalConsonant = rem % HANGUL_FINAL_COUNT
        return intArrayOf(initial, medial, finalConsonant)
    }

    fun scanCompactMask(compact: CharSequence): Int =
        COMPACT_AUTOMATON.scanMask(compact, asciiFold = false)

    fun scanRawSpamMask(rawText: CharSequence): Int =
        RAW_SPAM_AUTOMATON.scanMask(rawText, asciiFold = true)

    fun containsPersonalInfo(text: CharSequence): Boolean {
        val hasPhoneCandidate = indexOfTwoChars(text, '0', '1') >= 0
        if (hasPhoneCandidate && PHONE_PATTERN.containsMatchIn(text)) {
            return true
        }
        val hasEmailCandidate = indexOfChar(text, '@') >= 0
        return hasEmailCandidate && EMAIL_PATTERN.containsMatchIn(text)
    }

    fun containsAnySuspiciousFuzzyTerm(
        compact: CharSequence,
        threshold: Double = SUSPICION_SIMILARITY_THRESHOLD,
        excludeExactOnly: Boolean = false,
    ): Boolean {
        if (compact.isEmpty()) return false
        for (pattern in FUZZY_SUSPICIOUS_PATTERNS) {
            if (excludeExactOnly && pattern.length <= 2 && threshold > 2.0 / 3.0) {
                continue
            }
            if (matchesWithinSimilarity(compact, pattern, threshold)) {
                return true
            }
        }
        return false
    }

    fun maxSimilarityTo(compact: CharSequence, rawTerm: String): Double {
        val termCompact = compactForModeration(rawTerm)
        if (compact.isEmpty() || termCompact.isEmpty()) return 0.0
        val pattern = MyersPattern.compile(termCompact)
        return maxWindowSimilarity(compact, pattern)
    }

    fun matchesWithinSimilarity(
        compact: CharSequence,
        termCompact: String,
        threshold: Double = SUSPICION_SIMILARITY_THRESHOLD,
    ): Boolean {
        if (compact.isEmpty() || termCompact.isEmpty()) return false
        return matchesWithinSimilarity(compact, MyersPattern.compile(termCompact), threshold)
    }

    fun countWhitespaceTokens(text: CharSequence): Int {
        var count = 0
        var inToken = false
        for (i in 0 until text.length) {
            if (text[i].isWhitespace()) {
                inToken = false
            } else if (!inToken) {
                count++
                inToken = true
            }
        }
        return count
    }

    private fun indexOfChar(text: CharSequence, target: Char): Int {
        for (i in 0 until text.length) {
            if (text[i] == target) return i
        }
        return -1
    }

    private fun indexOfTwoChars(text: CharSequence, first: Char, second: Char): Int {
        val limit = text.length - 1
        for (i in 0 until limit) {
            if (text[i] == first && text[i + 1] == second) return i
        }
        return -1
    }

    private fun matchesWithinSimilarity(
        compact: CharSequence,
        pattern: MyersPattern,
        threshold: Double,
    ): Boolean {
        val m = pattern.length
        if (m == 0) return true
        val n = compact.length
        if (n == 0) return false
        val maxCandidateLen = maxOf(n.coerceAtMost(m + 1), m)
        val kMax = floor((1.0 - threshold) * maxCandidateLen + 1e-12).toInt()
        if (m > 63) {
            return maxWindowSimilarityFallback(compact, pattern.raw) >= threshold
        }
        if (n < m) {
            val dist = globalMyersDistance(compact, 0, n, pattern)
            return similarity(dist, m) >= threshold
        }
        if (kMax <= 0) {
            return containsExact(compact, pattern.raw)
        }

        // Semi-global Myers pass: score[j] = min edit distance between pattern and ANY suffix ending at j.
        val highBit = 1L shl (m - 1)
        var pv = -1L
        var mv = 0L
        var score = m
        for (j in 0 until n) {
            val eq = pattern.eqMask(compact[j])
            val xv = eq or mv
            val xh = (((eq and pv) + pv) xor pv) or eq
            var ph = mv or (xh or pv).inv()
            var mh = pv and xh

            if ((ph and highBit) != 0L) {
                score++
            } else if ((mh and highBit) != 0L) {
                score--
            }

            ph = ph shl 1
            mh = mh shl 1
            pv = mh or (xv or ph).inv()
            mv = ph and xv

            if (score <= kMax) {
                val end = j + 1
                if (end >= m) {
                    val distM = globalMyersDistance(compact, end - m, end, pattern)
                    if (similarity(distM, m) >= threshold) return true
                }
                if (end >= m + 1) {
                    val distM1 = globalMyersDistance(compact, end - m - 1, end, pattern)
                    if (similarity(distM1, m + 1) >= threshold) return true
                }
            }
        }
        return false
    }

    private fun maxWindowSimilarity(compact: CharSequence, pattern: MyersPattern): Double {
        val m = pattern.length
        val n = compact.length
        if (m == 0 || n == 0) return 0.0
        if (m > 63) return maxWindowSimilarityFallback(compact, pattern.raw)
        if (n < m) {
            return similarity(globalMyersDistance(compact, 0, n, pattern), m)
        }
        var best = 0.0
        for (end in m..n) {
            val sM = similarity(globalMyersDistance(compact, end - m, end, pattern), m)
            if (sM > best) best = sM
            if (end >= m + 1) {
                val sM1 = similarity(globalMyersDistance(compact, end - m - 1, end, pattern), m + 1)
                if (sM1 > best) best = sM1
            }
            if (best == 1.0) return 1.0
        }
        return best
    }

    // Global Myers edit distance between pattern[0..m) and text[start..end) with zero allocations.
    private fun globalMyersDistance(
        text: CharSequence,
        start: Int,
        end: Int,
        pattern: MyersPattern,
    ): Int {
        val m = pattern.length
        val highBit = 1L shl (m - 1)
        var pv = -1L
        var mv = 0L
        var score = m
        for (j in start until end) {
            val eq = pattern.eqMask(text[j])
            val xv = eq or mv
            val xh = (((eq and pv) + pv) xor pv) or eq
            var ph = mv or (xh or pv).inv()
            var mh = pv and xh

            if ((ph and highBit) != 0L) {
                score++
            } else if ((mh and highBit) != 0L) {
                score--
            }

            ph = (ph shl 1) or 1L
            mh = mh shl 1
            pv = mh or (xv or ph).inv()
            mv = ph and xv
        }
        return score
    }

    private fun containsExact(text: CharSequence, pattern: String): Boolean {
        val m = pattern.length
        val n = text.length
        if (m == 0) return true
        if (n < m) return false
        val first = pattern[0]
        outer@ for (i in 0..(n - m)) {
            if (text[i] != first) continue
            for (k in 1 until m) {
                if (text[i + k] != pattern[k]) continue@outer
            }
            return true
        }
        return false
    }

    private fun similarity(distance: Int, maxLen: Int): Double {
        if (maxLen == 0) return 1.0
        return 1.0 - (distance.toDouble() / maxLen.toDouble())
    }

    private fun maxWindowSimilarityFallback(compact: CharSequence, pattern: String): Double {
        val n = compact.length
        val m = pattern.length
        if (n <= m) {
            return similarity(levenshteinFallback(compact, 0, n, pattern), maxOf(n, m))
        }
        var best = 0.0
        for (end in m..n) {
            val sM = similarity(levenshteinFallback(compact, end - m, end, pattern), m)
            if (sM > best) best = sM
            if (end >= m + 1) {
                val sM1 = similarity(levenshteinFallback(compact, end - m - 1, end, pattern), m + 1)
                if (sM1 > best) best = sM1
            }
        }
        return best
    }

    private fun levenshteinFallback(
        source: CharSequence,
        start: Int,
        end: Int,
        other: String,
    ): Int {
        var prev = IntArray(other.length + 1) { it }
        var curr = IntArray(other.length + 1)
        for (i in start until end) {
            curr[0] = (i - start) + 1
            for (j in other.indices) {
                val cost = if (source[i] == other[j]) 0 else 1
                curr[j + 1] = minOf(curr[j] + 1, prev[j + 1] + 1, prev[j] + cost)
            }
            val tmp = prev
            prev = curr
            curr = tmp
        }
        return prev[other.length]
    }

    private class MyersPattern(
        val raw: String,
        private val uniqueChars: CharArray,
        private val uniquePeq: LongArray,
    ) {
        val length: Int get() = raw.length

        fun eqMask(c: Char): Long {
            for (i in uniqueChars.indices) {
                if (uniqueChars[i] == c) return uniquePeq[i]
            }
            return 0L
        }

        companion object {
            fun compile(pattern: String): MyersPattern {
                val chars = ArrayList<Char>(pattern.length)
                val masks = ArrayList<Long>(pattern.length)
                for (i in pattern.indices) {
                    val ch = pattern[i]
                    val bit = 1L shl i
                    val existing = chars.indexOf(ch)
                    if (existing >= 0) {
                        masks[existing] = masks[existing] or bit
                    } else {
                        chars.add(ch)
                        masks.add(bit)
                    }
                }
                return MyersPattern(
                    raw = pattern,
                    uniqueChars = chars.toCharArray(),
                    uniquePeq = masks.toLongArray(),
                )
            }
        }
    }

    private class FlatAhoCorasickAutomaton private constructor(
        private val nodeEdgeStart: IntArray,
        private val nodeEdgeEnd: IntArray,
        private val edgeChar: CharArray,
        private val edgeTarget: IntArray,
        private val fail: IntArray,
        private val outputMask: IntArray,
        private val rootAscii: IntArray,
    ) {
        fun scanMask(text: CharSequence, asciiFold: Boolean): Int {
            var state = 0
            var matched = 0
            for (i in 0 until text.length) {
                var c = text[i]
                if (asciiFold && c in 'A'..'Z') {
                    c = (c.code or 0x20).toChar()
                }
                while (state != 0) {
                    val next = nextTransition(state, c)
                    if (next >= 0) {
                        state = next
                        break
                    }
                    state = fail[state]
                }
                if (state == 0) {
                    state = rootTransition(c)
                }
                matched = matched or outputMask[state]
            }
            return matched
        }

        private fun rootTransition(c: Char): Int {
            val code = c.code
            if (code < 128) return rootAscii[code]
            val next = nextTransition(0, c)
            return if (next >= 0) next else 0
        }

        private fun nextTransition(state: Int, c: Char): Int {
            val start = nodeEdgeStart[state]
            val end = nodeEdgeEnd[state]
            val count = end - start
            if (count <= 0) return -1
            if (count <= 4) {
                for (idx in start until end) {
                    val edgeC = edgeChar[idx]
                    if (edgeC == c) return edgeTarget[idx]
                    if (edgeC > c) return -1
                }
                return -1
            }
            var lo = start
            var hi = end - 1
            while (lo <= hi) {
                val mid = (lo + hi) ushr 1
                val edgeC = edgeChar[mid]
                when {
                    edgeC < c -> lo = mid + 1
                    edgeC > c -> hi = mid - 1
                    else -> return edgeTarget[mid]
                }
            }
            return -1
        }

        class Builder {
            private class TrieNode {
                val children = sortedMapOf<Char, Int>()
                var mask = 0
            }

            private val nodes = arrayListOf(TrieNode())

            fun addAll(terms: Array<String>, bitMask: Int, compact: Boolean) {
                for (term in terms) {
                    val normalized = if (compact) compactForModeration(term) else term.lowercase()
                    addPattern(normalized, bitMask)
                }
            }

            fun addPattern(pattern: String, bitMask: Int) {
                if (pattern.isEmpty()) return
                var curr = 0
                for (i in pattern.indices) {
                    val ch = pattern[i]
                    val next = nodes[curr].children[ch]
                    curr = if (next != null) {
                        next
                    } else {
                        val created = nodes.size
                        nodes.add(TrieNode())
                        nodes[curr].children[ch] = created
                        created
                    }
                }
                nodes[curr].mask = nodes[curr].mask or bitMask
            }

            fun build(): FlatAhoCorasickAutomaton {
                val numStates = nodes.size
                val fail = IntArray(numStates)
                val outMask = IntArray(numStates) { nodes[it].mask }
                val nodeEdgeStart = IntArray(numStates)
                val nodeEdgeEnd = IntArray(numStates)
                var totalEdges = 0
                for (s in 0 until numStates) {
                    nodeEdgeStart[s] = totalEdges
                    totalEdges += nodes[s].children.size
                    nodeEdgeEnd[s] = totalEdges
                }

                val edgeChar = CharArray(totalEdges)
                val edgeTarget = IntArray(totalEdges)
                var cursor = 0
                for (s in 0 until numStates) {
                    for ((ch, target) in nodes[s].children) {
                        edgeChar[cursor] = ch
                        edgeTarget[cursor] = target
                        cursor++
                    }
                }

                val queue = IntArray(numStates)
                var qHead = 0
                var qTail = 0
                val rootAscii = IntArray(128)
                for ((ch, child) in nodes[0].children) {
                    fail[child] = 0
                    queue[qTail++] = child
                    if (ch.code < 128) {
                        rootAscii[ch.code] = child
                    }
                }

                while (qHead < qTail) {
                    val u = queue[qHead++]
                    for ((ch, v) in nodes[u].children) {
                        var f = fail[u]
                        while (f != 0 && !nodes[f].children.containsKey(ch)) {
                            f = fail[f]
                        }
                        val nextFail = nodes[f].children[ch] ?: 0
                        fail[v] = nextFail
                        outMask[v] = outMask[v] or outMask[nextFail]
                        queue[qTail++] = v
                    }
                }

                return FlatAhoCorasickAutomaton(
                    nodeEdgeStart = nodeEdgeStart,
                    nodeEdgeEnd = nodeEdgeEnd,
                    edgeChar = edgeChar,
                    edgeTarget = edgeTarget,
                    fail = fail,
                    outputMask = outMask,
                    rootAscii = rootAscii,
                )
            }
        }

        companion object {
            fun builder(): Builder = Builder()
        }
    }
}
