package com.godotframework.taptap

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class AtomicFileWriterTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun replacesExistingFileAndCleansTemporaryArtifacts() {
        val directory = temporaryFolder.newFolder("download")
        val destination = directory.resolve("save.dat")
        destination.writeBytes(byteArrayOf(9))

        val error = AtomicFileWriter().write(destination.absolutePath, byteArrayOf(1, 2, 3))

        assertNull(error)
        assertArrayEquals(byteArrayOf(1, 2, 3), destination.readBytes())
        assertFalse(directory.listFiles().orEmpty().any { it.name.endsWith(".tmp") || it.name.endsWith(".bak") })
    }
}
