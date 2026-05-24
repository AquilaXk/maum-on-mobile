package com.maumonmobile.adapter.out.persistence.jdbc

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import org.springframework.jdbc.support.GeneratedKeyHolder

internal fun NamedParameterJdbcTemplate.insertAndReturnId(
    sql: String,
    parameters: MapSqlParameterSource,
): Long {
    val keyHolder = GeneratedKeyHolder()
    update(sql, parameters, keyHolder, arrayOf("id"))
    return keyHolder.key?.toLong()
        ?: error("생성된 영속 ID를 확인하지 못했습니다.")
}

internal fun params(): MapSqlParameterSource = MapSqlParameterSource()

internal fun MapSqlParameterSource.withValue(name: String, value: Any?): MapSqlParameterSource {
    addValue(name, value)
    return this
}
