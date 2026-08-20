package com.godotframework.taptap

import com.taptap.sdk.cloudsave.ArchiveData
import com.taptap.sdk.cloudsave.ArchiveMetadata
import org.json.JSONArray
import org.json.JSONObject

internal object TapCloudSaveJson {
    fun metadataFromJson(raw: String): ArchiveMetadata {
        val json = JSONObject(raw)
        return ArchiveMetadata.Builder()
            .setName(json.getString("name"))
            .setSummary(json.getString("summary"))
            .setExtra(json.optString("extra", ""))
            .setPlaytime(json.optInt("playtime", 0))
            .build()
    }

    fun archiveToJson(archive: ArchiveData): String = archiveToObject(archive).toString()

    fun archivesToJson(archives: List<ArchiveData>): String {
        val result = JSONArray()
        archives.forEach { result.put(archiveToObject(it)) }
        return result.toString()
    }

    private fun archiveToObject(archive: ArchiveData) = JSONObject()
        .put("uuid", archive.uuid)
        .put("file_id", archive.fileId)
        .put("name", archive.name)
        .put("summary", archive.summary)
        .put("extra", archive.extra)
        .put("playtime", archive.playtime)
        .put("save_size", archive.saveSize)
        .put("cover_size", archive.coverSize)
        .put("created_time", archive.createdTime)
        .put("modified_time", archive.modifiedTime)
}
