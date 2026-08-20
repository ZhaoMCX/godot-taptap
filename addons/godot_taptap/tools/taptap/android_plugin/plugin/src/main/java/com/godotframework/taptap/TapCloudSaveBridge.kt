package com.godotframework.taptap

import com.taptap.sdk.cloudsave.ArchiveData
import com.taptap.sdk.cloudsave.internal.TapCloudSaveCallback
import com.taptap.sdk.cloudsave.internal.TapCloudSaveRequestCallback

internal class TapCloudSaveBridge(
    private val gateway: TapCloudSaveGateway,
    private val fileWriter: AtomicFileWriter,
    private val onCreated: (String) -> Unit,
    private val onUpdated: (String) -> Unit,
    private val onDeleted: (String) -> Unit,
    private val onList: (String) -> Unit,
    private val onDataDownloaded: () -> Unit,
    private val onCoverDownloaded: () -> Unit,
    private val onFailure: (Long, String) -> Unit,
    private val onStatus: (Long) -> Unit,
) {
    companion object {
        const val LOCAL_IO_ERROR = -1000L
    }

    private val statusCallback = object : TapCloudSaveCallback {
        override fun onResult(resultCode: Int) = onStatus(resultCode.toLong())
    }

    fun registerStatusCallback() {
        gateway.unregister(statusCallback)
        gateway.register(statusCallback)
    }

    fun dispose() {
        gateway.unregister(statusCallback)
    }

    fun create(metadataJson: String, archivePath: String, coverPath: String) = guard {
        gateway.create(
            TapCloudSaveJson.metadataFromJson(metadataJson),
            archivePath,
            coverPath,
            callback(onArchiveCreated = { onCreated(TapCloudSaveJson.archiveToJson(it)) })
        )
    }

    fun list() = guard {
        gateway.list(callback(onArchiveList = { onList(TapCloudSaveJson.archivesToJson(it)) }))
    }

    fun downloadData(uuid: String, fileId: String, destinationPath: String) = guard {
        gateway.downloadData(
            uuid,
            fileId,
            callback(onArchiveData = { writeDownload(destinationPath, it, onDataDownloaded) })
        )
    }

    fun update(
        uuid: String,
        metadataJson: String,
        archivePath: String,
        coverPath: String
    ) = guard {
        gateway.update(
            uuid,
            TapCloudSaveJson.metadataFromJson(metadataJson),
            archivePath,
            coverPath,
            callback(onArchiveUpdated = { onUpdated(TapCloudSaveJson.archiveToJson(it)) })
        )
    }

    fun delete(uuid: String) = guard {
        gateway.delete(
            uuid,
            callback(onArchiveDeleted = { onDeleted(TapCloudSaveJson.archiveToJson(it)) })
        )
    }

    fun downloadCover(uuid: String, fileId: String, destinationPath: String) = guard {
        gateway.downloadCover(
            uuid,
            fileId,
            callback(onArchiveCover = { writeDownload(destinationPath, it, onCoverDownloaded) })
        )
    }

    private fun callback(
        onArchiveCreated: (ArchiveData) -> Unit = {},
        onArchiveUpdated: (ArchiveData) -> Unit = {},
        onArchiveDeleted: (ArchiveData) -> Unit = {},
        onArchiveList: (List<ArchiveData>) -> Unit = {},
        onArchiveData: (ByteArray) -> Unit = {},
        onArchiveCover: (ByteArray) -> Unit = {},
    ) = object : TapCloudSaveRequestCallback {
        override fun onArchiveCreated(archive: ArchiveData) = onArchiveCreated(archive)
        override fun onArchiveUpdated(archive: ArchiveData) = onArchiveUpdated(archive)
        override fun onArchiveDeleted(archive: ArchiveData) = onArchiveDeleted(archive)
        override fun onArchiveListResult(archiveList: List<ArchiveData>) = onArchiveList(archiveList)
        override fun onArchiveDataResult(archiveData: ByteArray) = onArchiveData(archiveData)
        override fun onArchiveCoverResult(coverData: ByteArray) = onArchiveCover(coverData)
        override fun onRequestError(errorCode: Int, errorMessage: String) =
            onFailure(errorCode.toLong(), errorMessage)
    }

    private fun writeDownload(destinationPath: String, data: ByteArray, onSuccess: () -> Unit) {
        val error = fileWriter.write(destinationPath, data)
        if (error == null) onSuccess() else onFailure(LOCAL_IO_ERROR, error)
    }

    private inline fun guard(action: () -> Unit) {
        try {
            action()
        } catch (error: Throwable) {
            onFailure(0L, error.message ?: "TapTap 云存档请求失败")
        }
    }
}
