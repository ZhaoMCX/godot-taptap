package com.godotframework.taptap

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.taptap.sdk.compliance.TapTapCompliance
import com.taptap.sdk.compliance.TapTapComplianceCallback
import com.taptap.sdk.compliance.option.TapTapComplianceOptions
import com.taptap.sdk.core.TapTapRegion
import com.taptap.sdk.core.TapTapSdk
import com.taptap.sdk.core.TapTapSdkOptions
import com.taptap.sdk.initializer.api.TapInitCallback
import com.taptap.sdk.kit.internal.callback.TapTapCallback
import com.taptap.sdk.kit.internal.exception.TapTapException
import com.taptap.sdk.login.TapTapAccount
import com.taptap.sdk.login.TapTapLogin
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONArray
import org.json.JSONObject

class TapTapSdkPlugin(godot: Godot) : GodotPlugin(godot) {
    companion object {
        private const val TAG = "GodotTapTap"
        private val INITIALIZATION_SUCCEEDED = SignalInfo("initialization_succeeded")
        private val INITIALIZATION_FAILED = SignalInfo(
            "initialization_failed",
            GodotSignalTypes.LONG,
            String::class.java
        )
        private val LOGIN_SUCCEEDED = SignalInfo("login_succeeded", String::class.java)
        private val LOGIN_CANCELLED = SignalInfo("login_cancelled")
        private val LOGIN_FAILED = SignalInfo("login_failed", GodotSignalTypes.LONG, String::class.java)
        private val LOGOUT_SUCCEEDED = SignalInfo("logout_succeeded")
        private val LOGOUT_FAILED = SignalInfo("logout_failed", GodotSignalTypes.LONG, String::class.java)
        private val COMPLIANCE_RESULT = SignalInfo("compliance_result", String::class.java)
        private val CLOUD_SAVE_ARCHIVE_CREATED = SignalInfo("cloud_save_archive_created", String::class.java)
        private val CLOUD_SAVE_ARCHIVE_UPDATED = SignalInfo("cloud_save_archive_updated", String::class.java)
        private val CLOUD_SAVE_ARCHIVE_DELETED = SignalInfo("cloud_save_archive_deleted", String::class.java)
        private val CLOUD_SAVE_ARCHIVE_LIST_RECEIVED = SignalInfo(
            "cloud_save_archive_list_received",
            String::class.java
        )
        private val CLOUD_SAVE_DATA_DOWNLOADED = SignalInfo("cloud_save_data_downloaded")
        private val CLOUD_SAVE_COVER_DOWNLOADED = SignalInfo("cloud_save_cover_downloaded")
        private val CLOUD_SAVE_REQUEST_FAILED = SignalInfo(
            "cloud_save_request_failed",
            GodotSignalTypes.LONG,
            String::class.java
        )
        private val CLOUD_SAVE_STATUS = SignalInfo("cloud_save_status", GodotSignalTypes.LONG)
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private val cloudSaveBridge = TapCloudSaveBridge(
        gateway = TapSdkCloudSaveGateway(),
        fileWriter = AtomicFileWriter(),
        onCreated = { emitOnMainThread(CLOUD_SAVE_ARCHIVE_CREATED, it) },
        onUpdated = { emitOnMainThread(CLOUD_SAVE_ARCHIVE_UPDATED, it) },
        onDeleted = { emitOnMainThread(CLOUD_SAVE_ARCHIVE_DELETED, it) },
        onList = { emitOnMainThread(CLOUD_SAVE_ARCHIVE_LIST_RECEIVED, it) },
        onDataDownloaded = { emitOnMainThread(CLOUD_SAVE_DATA_DOWNLOADED) },
        onCoverDownloaded = { emitOnMainThread(CLOUD_SAVE_COVER_DOWNLOADED) },
        onFailure = { code, message ->
            emitOnMainThread(CLOUD_SAVE_REQUEST_FAILED, code, message)
        },
        onStatus = { emitOnMainThread(CLOUD_SAVE_STATUS, it) },
    )

    private val complianceCallback = object : TapTapComplianceCallback {
        override fun onComplianceResult(code: Int, extra: Map<String, Any>?) {
            Log.i(TAG, "Compliance callback code=$code")
            val metadata = runCatching {
                JSONObject(extra ?: emptyMap<String, Any>())
            }.getOrDefault(JSONObject())
            val payload = JSONObject()
                .put("code", code)
                .put("metadata", metadata)
                .toString()
            emitOnMainThread(COMPLIANCE_RESULT, payload)
        }
    }

    private val initializationCoordinator = TapSdkInitializationCoordinator(
        object : TapInitCallbackGateway {
            override fun add(callback: TapInitCallback) = TapTapSdk.addInitCallback(callback)
            override fun remove(callback: TapInitCallback) = TapTapSdk.removeInitCallback(callback)
        },
        onSuccess = {
            try {
                registerComplianceCallback()
                cloudSaveBridge.registerStatusCallback()
                Log.i(TAG, "SDK initialization callback success")
                emitOnMainThread(INITIALIZATION_SUCCEEDED)
            } catch (error: Throwable) {
                emitOnMainThread(
                    INITIALIZATION_FAILED,
                    0L,
                    error.message ?: "TapSDK 初始化后回调注册失败"
                )
            }
        },
        onFailure = { errorCode, errorMsg ->
            Log.i(TAG, "SDK initialization callback failed code=$errorCode")
            emitOnMainThread(INITIALIZATION_FAILED, errorCode.toLong(), errorMsg)
        }
    )

    override fun getPluginName() = "TapTapSdkBridge"

    override fun getPluginSignals() = setOf(
        INITIALIZATION_SUCCEEDED,
        INITIALIZATION_FAILED,
        LOGIN_SUCCEEDED,
        LOGIN_CANCELLED,
        LOGIN_FAILED,
        LOGOUT_SUCCEEDED,
        LOGOUT_FAILED,
        COMPLIANCE_RESULT,
        CLOUD_SAVE_ARCHIVE_CREATED,
        CLOUD_SAVE_ARCHIVE_UPDATED,
        CLOUD_SAVE_ARCHIVE_DELETED,
        CLOUD_SAVE_ARCHIVE_LIST_RECEIVED,
        CLOUD_SAVE_DATA_DOWNLOADED,
        CLOUD_SAVE_COVER_DOWNLOADED,
        CLOUD_SAVE_REQUEST_FAILED,
        CLOUD_SAVE_STATUS
    )

    @UsedByGodot
    fun initialize(payloadJson: String): Boolean {
        val activity = currentActivity() ?: return false
        return try {
            val payload = JSONObject(payloadJson)
            val clientId = payload.getString("client_id")
            val clientToken = payload.getString("client_token")
            val enableLog = payload.optBoolean("enable_debug_log", false)
            val complianceOptions = TapTapComplianceOptions(
                payload.optBoolean("show_switch_account", true),
                false
            )
            activity.runOnUiThread {
                initializationCoordinator.initialize {
                    TapTapSdk.init(
                        activity.applicationContext,
                        TapTapSdkOptions(clientId, clientToken, TapTapRegion.CN, "", enableLog),
                        complianceOptions
                    )
                }
            }
            true
        } catch (error: Throwable) {
            emitSignal(INITIALIZATION_FAILED.name, 0L, error.message ?: "TapSDK 配置格式无效")
            false
        }
    }

    @UsedByGodot
    fun login(scopesJson: String): Boolean {
        val activity = currentActivity() ?: return false
        return try {
            val array = JSONArray(scopesJson)
            val scopes = Array(array.length()) { index -> array.getString(index) }
            activity.runOnUiThread {
                TapTapLogin.loginWithScopes(activity, scopes, object : TapTapCallback<TapTapAccount> {
                    override fun onSuccess(result: TapTapAccount) {
                        Log.i(TAG, "Login callback success")
                        emitOnMainThread(LOGIN_SUCCEEDED, accountToJson(result))
                    }

                    override fun onCancel() {
                        Log.i(TAG, "Login callback cancelled")
                        emitOnMainThread(LOGIN_CANCELLED)
                    }

                    override fun onFail(exception: TapTapException) {
                        Log.i(TAG, "Login callback failed")
                        emitOnMainThread(LOGIN_FAILED, 0L, exception.message ?: "TapTap 登录失败")
                    }
                })
            }
            true
        } catch (error: Throwable) {
            emitSignal(LOGIN_FAILED.name, 0L, error.message ?: "TapTap 登录参数无效")
            false
        }
    }

    @UsedByGodot
    fun get_current_account(): String {
        return TapTapLogin.getCurrentTapAccount()?.let(::accountToJson) ?: ""
    }

    @UsedByGodot
    fun logout(): Boolean {
        val activity = currentActivity() ?: return false
        activity.runOnUiThread {
            try {
                TapTapLogin.logout()
                emitSignal(LOGOUT_SUCCEEDED.name)
            } catch (error: Throwable) {
                emitSignal(LOGOUT_FAILED.name, 0L, error.message ?: "TapTap 登出失败")
            }
        }
        return true
    }

    @UsedByGodot
    fun start_compliance(openId: String): Boolean {
        val activity = currentActivity() ?: return false
        if (openId.isBlank()) return false
        activity.runOnUiThread {
            try {
                TapTapCompliance.startup(activity, openId)
            } catch (error: Throwable) {
                emitSignal(
                    COMPLIANCE_RESULT.name,
                    JSONObject()
                        .put("code", 1200)
                        .put("metadata", JSONObject().put("message", error.message ?: "防沉迷启动失败"))
                        .toString()
                )
            }
        }
        return true
    }

    @UsedByGodot
    fun exit_compliance(): Boolean {
        val activity = currentActivity() ?: return false
        activity.runOnUiThread { TapTapCompliance.exit() }
        return true
    }

    @UsedByGodot
    fun cloud_save_create(
        metadataJson: String,
        archivePath: String,
        coverPath: String
    ): Boolean = runCloudSaveRequest {
        cloudSaveBridge.create(metadataJson, archivePath, coverPath)
    }

    @UsedByGodot
    fun cloud_save_list(): Boolean = runCloudSaveRequest {
        cloudSaveBridge.list()
    }

    @UsedByGodot
    fun cloud_save_download_data(
        uuid: String,
        fileId: String,
        destinationPath: String
    ): Boolean = runCloudSaveRequest {
        cloudSaveBridge.downloadData(uuid, fileId, destinationPath)
    }

    @UsedByGodot
    fun cloud_save_update(
        uuid: String,
        metadataJson: String,
        archivePath: String,
        coverPath: String
    ): Boolean = runCloudSaveRequest {
        cloudSaveBridge.update(uuid, metadataJson, archivePath, coverPath)
    }

    @UsedByGodot
    fun cloud_save_delete(uuid: String): Boolean = runCloudSaveRequest {
        cloudSaveBridge.delete(uuid)
    }

    @UsedByGodot
    fun cloud_save_download_cover(
        uuid: String,
        fileId: String,
        destinationPath: String
    ): Boolean = runCloudSaveRequest {
        cloudSaveBridge.downloadCover(uuid, fileId, destinationPath)
    }

    override fun onMainDestroy() {
        initializationCoordinator.dispose()
        cloudSaveBridge.dispose()
        TapTapCompliance.unregisterComplianceCallback(complianceCallback)
        TapTapCompliance.exit()
        super.onMainDestroy()
    }

    private fun currentActivity(): Activity? = activity

    private fun registerComplianceCallback() {
        TapTapCompliance.unregisterComplianceCallback(complianceCallback)
        TapTapCompliance.registerComplianceCallback(complianceCallback)
        Log.i(TAG, "Compliance callback registered")
    }

    private fun runCloudSaveRequest(action: () -> Unit): Boolean {
        val activity = currentActivity() ?: return false
        activity.runOnUiThread(action)
        return true
    }

    private fun accountToJson(account: TapTapAccount): String {
        val scopes = runCatching {
            JSONArray(account.accessToken.scopes.toList())
        }.getOrDefault(JSONArray())
        return JSONObject()
            .put("open_id", account.openId ?: "")
            .put("union_id", account.unionId ?: "")
            .put("name", account.name ?: "")
            .put("avatar_url", account.avatar ?: "")
            .put("scopes", scopes)
            .toString()
    }

    private fun emitOnMainThread(signal: SignalInfo, vararg args: Any) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            emitSignal(signal.name, *args)
            return
        }
        mainHandler.post { emitSignal(signal.name, *args) }
    }
}
