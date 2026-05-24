package com.maumonmobile.global

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path

class SourceLayoutPolicyTest {

    @Test
    fun javaSourceDirectoriesAreNotCreated() {
        assertFalse(Files.exists(Path.of("src/main/java")))
        assertFalse(Files.exists(Path.of("src/test/java")))
    }
}
