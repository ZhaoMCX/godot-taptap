package com.godotframework.taptap

import com.taptap.sdk.cloudsave.ArchiveMetadata
import com.taptap.sdk.cloudsave.internal.TapCloudSaveCallback
import com.taptap.sdk.cloudsave.internal.TapCloudSaveRequestCallback

internal class FakeTapCloudSaveGateway : TapCloudSaveGateway {
    var statusCallback: TapCloudSaveCallback? = null
    var requestCallback: TapCloudSaveRequestCallback? = null
    var lastOperation = ""
    var lastUuid = ""
    var lastFileId = ""
    var lastArchivePath = ""
    var lastCoverPath = ""
    var lastMetadata: ArchiveMetadata? = null
    var unregisterCount = 0

    override fun register(callback: TapCloudSaveCallback) {
        statusCallback = callback
    }

    override fun unregister(callback: TapCloudSaveCallback) {
        unregisterCount += 1
        if (statusCallback === callback) statusCallback = null
    }

    override fun create(
        metadata: ArchiveMetadata,
        archivePath: String,
        coverPath: String,
        callback: TapCloudSaveRequestCallback
    ) {
        lastOperation = "create"
        lastMetadata = metadata
        lastArchivePath = archivePath
        lastCoverPath = coverPath
        requestCallback = callback
    }

    override fun list(callback: TapCloudSaveRequestCallback) {
        lastOperation = "list"
        requestCallback = callback
    }

    override fun downloadData(uuid: String, fileId: String, callback: TapCloudSaveRequestCallback) {
        lastOperation = "download_data"
        lastUuid = uuid
        lastFileId = fileId
        requestCallback = callback
    }

    override fun update(
        uuid: String,
        metadata: ArchiveMetadata,
        archivePath: String,
        coverPath: String,
        callback: TapCloudSaveRequestCallback
    ) {
        lastOperation = "update"
        lastUuid = uuid
        lastMetadata = metadata
        lastArchivePath = archivePath
        lastCoverPath = coverPath
        requestCallback = callback
    }

    override fun delete(uuid: String, callback: TapCloudSaveRequestCallback) {
        lastOperation = "delete"
        lastUuid = uuid
        requestCallback = callback
    }

    override fun downloadCover(uuid: String, fileId: String, callback: TapCloudSaveRequestCallback) {
        lastOperation = "download_cover"
        lastUuid = uuid
        lastFileId = fileId
        requestCallback = callback
    }
}
