package com.maumonmobile.adapter.out.storage.image

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Configuration
import org.springframework.context.annotation.Profile
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer
import java.nio.file.Path

@Configuration
@Profile("!object-storage")
class LocalImageResourceConfig(
    @param:Value("\${app.images.local.root:./data/images}")
    private val root: String,
    @param:Value("\${app.images.local.public-base-path:/images/uploads}")
    private val publicBasePath: String,
) : WebMvcConfigurer {

    override fun addResourceHandlers(registry: ResourceHandlerRegistry) {
        registry.addResourceHandler("${publicBasePath.trimEnd('/')}/**")
            .addResourceLocations(Path.of(root).toUri().toString())
    }
}
