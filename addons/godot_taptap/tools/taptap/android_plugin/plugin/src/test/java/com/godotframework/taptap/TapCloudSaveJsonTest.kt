package com.godotframework.taptap

import com.taptap.sdk.cloudsave.ArchiveData
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class TapCloudSaveJsonTest {
    @Test
    fun mapsMetadataAndAllArchiveFields() {
        val metadata = TapCloudSaveJson.metadataFromJson(
            """{"name":"slot_1","summary":"summary","extra":"v1","playtime":42}"""
        )
        assertEquals("slot_1", metadata.name)
        assertEquals("summary", metadata.summary)
        assertEquals("v1", metadata.extra)
        assertEquals(42, metadata.playtime)

        val archive = archive()
        val json = JSONObject(TapCloudSaveJson.archiveToJson(archive))
        assertEquals("uuid-1", json.getString("uuid"))
        assertEquals("file-1", json.getString("file_id"))
        assertEquals(6L, json.getLong("save_size"))
        assertEquals(9L, json.getLong("modified_time"))

        val list = JSONArray(TapCloudSaveJson.archivesToJson(listOf(archive)))
        assertEquals(1, list.length())
        assertEquals("slot_1", list.getJSONObject(0).getString("name"))
    }

    private fun archive() = ArchiveData(
        "uuid-1", "file-1", "slot_1", "summary", "v1", 5, 6L, 7L, 8L, 9L
    )
}
