package com.godotframework.taptap

import com.taptap.sdk.cloudsave.ArchiveMetadata
import com.taptap.sdk.cloudsave.internal.TapCloudSaveCallback
import com.taptap.sdk.cloudsave.internal.TapCloudSaveRequestCallback

internal interface TapCloudSaveGateway {
    fun register(callback: TapCloudSaveCallback)
    fun unregister(callback: TapCloudSaveCallback)
    fun create(
        metadata: ArchiveMetadata,
        archivePath: String,
        coverPath: String,
        callback: TapCloudSaveRequestCallback
    )
    fun list(callback: TapCloudSaveRequestCallback)
    fun downloadData(uuid: String, fileId: String, callback: TapCloudSaveRequestCallback)
    fun update(
        uuid: String,
        metadata: ArchiveMetadata,
        archivePath: String,
        coverPath: String,
        callback: TapCloudSaveRequestCallback
    )
    fun delete(uuid: String, callback: TapCloudSaveRequestCallback)
    fun downloadCover(uuid: String, fileId: String, callback: TapCloudSaveRequestCallback)
}
