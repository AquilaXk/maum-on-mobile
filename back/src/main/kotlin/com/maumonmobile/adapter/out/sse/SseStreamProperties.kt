package com.maumonmobile.adapter.out.sse

import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.Duration

@ConfigurationProperties(prefix = "app.sse")
class SseStreamProperties {
    var instanceId: String = ""
    var streamTimeout: Duration = Duration.ofMinutes(30)
    var sessionTtl: Duration = Duration.ofMinutes(30)
    var heartbeatInterval: Duration = Duration.ofSeconds(15)
    var reconnectDelay: Duration = Duration.ofSeconds(3)
    var pollBatchSize: Int = 500
}
