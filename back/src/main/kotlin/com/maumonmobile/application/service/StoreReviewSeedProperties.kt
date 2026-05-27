package com.maumonmobile.application.service

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "app.store-review.seed")
class StoreReviewSeedProperties {
    var enabled: Boolean = false
    var secret: String = ""
    var reviewer: StoreReviewSeedAccountProperties = StoreReviewSeedAccountProperties()
    var operations: StoreReviewSeedAccountProperties = StoreReviewSeedAccountProperties()
}

class StoreReviewSeedAccountProperties {
    var email: String = ""
    var password: String = ""
}
