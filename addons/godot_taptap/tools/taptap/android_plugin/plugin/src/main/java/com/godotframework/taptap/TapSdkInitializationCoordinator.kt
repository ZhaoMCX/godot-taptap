package com.godotframework.taptap

import com.taptap.sdk.initializer.api.TapInitCallback

internal interface TapInitCallbackGateway {
    fun add(callback: TapInitCallback)
    fun remove(callback: TapInitCallback)
}

internal class TapSdkInitializationCoordinator(
    private val gateway: TapInitCallbackGateway,
    private val onSuccess: () -> Unit,
    private val onFailure: (Int, String) -> Unit
) {
    private var awaitingResult = false

    private val callback = object : TapInitCallback {
        override fun onInitSuccess() {
            if (!awaitingResult) return
            awaitingResult = false
            gateway.remove(this)
            onSuccess()
        }

        override fun onInitFail(errorCode: Int, errorMsg: String) {
            if (!awaitingResult) return
            awaitingResult = false
            gateway.remove(this)
            onFailure(errorCode, errorMsg)
        }
    }

    fun initialize(initAction: () -> Unit) {
        gateway.remove(callback)
        awaitingResult = true
        gateway.add(callback)
        try {
            initAction()
        } catch (error: Throwable) {
            if (!awaitingResult) return
            awaitingResult = false
            gateway.remove(callback)
            onFailure(0, error.message ?: "TapSDK 初始化失败")
        }
    }

    fun dispose() {
        awaitingResult = false
        gateway.remove(callback)
    }
}
