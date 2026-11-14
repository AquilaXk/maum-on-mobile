package com.maumonmobile.domain.common

import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

private val UTC_ISO_MICROS_FORMATTER: DateTimeFormatter =
    DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'")
        .withZone(ZoneOffset.UTC)

fun Instant.toUtcIso6(): String = UTC_ISO_MICROS_FORMATTER.format(this)
