package com.godotframework.taptap

import com.taptap.sdk.cloudsave.ArchiveData
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class TapCloudSaveBridgeTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun routesCrudCallbacksAndPreservesErrorsAndStatus() {
        val gateway = FakeTapCloudSaveGateway()
        val created = mutableListOf<String>()
        val updated = mutableListOf<String>()
        val deleted = mutableListOf<String>()
        val lists = mutableListOf<String>()
        val failures = mutableListOf<Pair<Long, String>>()
        val statuses = mutableListOf<Long>()
        val bridge = bridge(gateway, created, updated, deleted, lists, failures, statuses)
        val metadata = """{"name":"slot_1","summary":"summary","extra":"","playtime":1}"""

        bridge.registerStatusCallback()
        gateway.statusCallback!!.onResult(300001)
        bridge.create(metadata, "save.dat", "cover.png")
        gateway.requestCallback!!.onArchiveCreated(archive())
        bridge.update("uuid-1", metadata, "save2.dat", "")
        gateway.requestCallback!!.onArchiveUpdated(archive())
        bridge.list()
        gateway.requestCallback!!.onArchiveListResult(listOf(archive()))
        bridge.delete("uuid-1")
        gateway.requestCallback!!.onArchiveDeleted(archive())
        bridge.list()
        gateway.requestCallback!!.onRequestError(400001, "limited")
        bridge.dispose()

        assertEquals(listOf(300001L), statuses)
        assertEquals("uuid-1", JSONObject(created.single()).getString("uuid"))
        assertEquals(1, updated.size)
        assertEquals(1, deleted.size)
        assertTrue(lists.single().contains("slot_1"))
        assertEquals(400001L to "limited", failures.single())
        assertTrue(gateway.unregisterCount >= 2)
    }

    @Test
    fun writesDataAndCoverBeforeEmittingCompletion() {
        val gateway = FakeTapCloudSaveGateway()
        var dataCompleted = 0
        var coverCompleted = 0
        val failures = mutableListOf<Pair<Long, String>>()
        val bridge = TapCloudSaveBridge(
            gateway, AtomicFileWriter(), {}, {}, {}, {},
            { dataCompleted += 1 }, { coverCompleted += 1 },
            { code, message -> failures += code to message }, {}
        )
        val dataTarget = temporaryFolder.root.resolve("nested/data.dat")
        val coverTarget = temporaryFolder.root.resolve("nested/cover.png")

        bridge.downloadData("uuid-1", "file-1", dataTarget.absolutePath)
        gateway.requestCallback!!.onArchiveDataResult(byteArrayOf(1, 2, 3))
        bridge.downloadCover("uuid-1", "file-1", coverTarget.absolutePath)
        gateway.requestCallback!!.onArchiveCoverResult(byteArrayOf(4, 5))

        assertEquals(1, dataCompleted)
        assertEquals(1, coverCompleted)
        assertArrayEquals(byteArrayOf(1, 2, 3), dataTarget.readBytes())
        assertArrayEquals(byteArrayOf(4, 5), coverTarget.readBytes())
        assertTrue(failures.isEmpty())
    }

    private fun bridge(
        gateway: FakeTapCloudSaveGateway,
        created: MutableList<String>,
        updated: MutableList<String>,
        deleted: MutableList<String>,
        lists: MutableList<String>,
        failures: MutableList<Pair<Long, String>>,
        statuses: MutableList<Long>,
    ) = TapCloudSaveBridge(
        gateway,
        AtomicFileWriter(),
        { created += it },
        { updated += it },
        { deleted += it },
        { lists += it },
        {},
        {},
        { code, message -> failures += code to message },
        { statuses += it },
    )

    private fun archive() = ArchiveData(
        "uuid-1", "file-1", "slot_1", "summary", "", 1, 3L, 2L, 100L, 200L
    )
}
