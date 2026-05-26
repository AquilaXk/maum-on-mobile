package com.maumonmobile.adapter.out.sse

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.time.Clock

@Configuration
class SseStreamClockConfiguration {
    @Bean
    fun sseStreamClock(): Clock {
        return Clock.systemUTC()
    }
}
