package com.maumonmobile

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication

@ConfigurationPropertiesScan
@SpringBootApplication
class MaumOnMobileApplication

fun main(args: Array<String>) {
    runApplication<MaumOnMobileApplication>(*args)
}
