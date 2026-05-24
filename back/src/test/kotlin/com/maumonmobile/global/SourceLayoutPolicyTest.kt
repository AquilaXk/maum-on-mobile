package com.maumonmobile.global

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path

class SourceLayoutPolicyTest {

    @Test
    fun javaSourceDirectoriesAreNotCreated() {
        val projectRoot = Path.of(System.getProperty("user.dir")).toAbsolutePath()

        assertTrue(projectRoot.endsWith("back"))
        assertFalse(Files.exists(projectRoot.resolve("src/main/java")))
        assertFalse(Files.exists(projectRoot.resolve("src/test/java")))
    }
}
