package com.godotframework.taptap

import com.taptap.sdk.cloudsave.ArchiveMetadata
import com.taptap.sdk.cloudsave.TapTapCloudSave
import com.taptap.sdk.cloudsave.internal.TapCloudSaveCallback
import com.taptap.sdk.cloudsave.internal.TapCloudSaveRequestCallback

internal class TapSdkCloudSaveGateway : TapCloudSaveGateway {
    override fun register(callback: TapCloudSaveCallback) =
        TapTapCloudSave.registerCloudSaveCallback(callback)

    override fun unregister(callback: TapCloudSaveCallback) =
        TapTapCloudSave.unregisterCloudSaveCallback(callback)

    override fun create(
        metadata: ArchiveMetadata,
        archivePath: String,
        coverPath: String,
        callback: TapCloudSaveRequestCallback
    ) = TapTapCloudSave.createArchive(metadata, archivePath, coverPath, callback)

    override fun list(callback: TapCloudSaveRequestCallback) =
        TapTapCloudSave.getArchiveList(callback)

    override fun downloadData(uuid: String, fileId: String, callback: TapCloudSaveRequestCallback) =
        TapTapCloudSave.getArchiveData(uuid, fileId, callback)

    override fun update(
        uuid: String,
        metadata: ArchiveMetadata,
        archivePath: String,
        coverPath: String,
        callback: TapCloudSaveRequestCallback
    ) = TapTapCloudSave.updateArchive(uuid, metadata, archivePath, coverPath, callback)

    override fun delete(uuid: String, callback: TapCloudSaveRequestCallback) =
        TapTapCloudSave.deleteArchive(uuid, callback)

    override fun downloadCover(uuid: String, fileId: String, callback: TapCloudSaveRequestCallback) =
        TapTapCloudSave.getArchiveCover(uuid, fileId, callback)
}
