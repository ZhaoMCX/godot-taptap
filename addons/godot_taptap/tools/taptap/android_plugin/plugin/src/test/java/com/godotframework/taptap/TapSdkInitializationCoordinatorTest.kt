package com.godotframework.taptap

import com.taptap.sdk.initializer.api.TapInitCallback
import org.junit.Assert.assertEquals
import org.junit.Test

class TapSdkInitializationCoordinatorTest {
    @Test
    fun registersCallbackBeforeInitAndCompletesOnSuccess() {
        val gateway = FakeGateway()
        val events = mutableListOf<String>()
        val coordinator = TapSdkInitializationCoordinator(
            gateway,
            onSuccess = { events += "success" },
            onFailure = { code, _ -> events += "failure:$code" }
        )

        coordinator.initialize { gateway.calls += "init" }
        gateway.callback!!.onInitSuccess()

        assertEquals(listOf("remove", "add", "init", "remove"), gateway.calls)
        assertEquals(listOf("success"), events)
    }

    @Test
    fun propagatesNativeFailureAndIgnoresDuplicateTerminalCallback() {
        val gateway = FakeGateway()
        val events = mutableListOf<String>()
        val coordinator = TapSdkInitializationCoordinator(
            gateway,
            onSuccess = { events += "success" },
            onFailure = { code, message -> events += "$code:$message" }
        )

        coordinator.initialize {}
        gateway.callback!!.onInitFail(23, "failed")
        gateway.callback!!.onInitSuccess()

        assertEquals(listOf("23:failed"), events)
    }

    @Test
    fun convertsSynchronousExceptionToFailure() {
        val gateway = FakeGateway()
        val events = mutableListOf<String>()
        val coordinator = TapSdkInitializationCoordinator(
            gateway,
            onSuccess = { events += "success" },
            onFailure = { code, message -> events += "$code:$message" }
        )

        coordinator.initialize { error("sync failure") }

        assertEquals(listOf("0:sync failure"), events)
        assertEquals(listOf("remove", "add", "remove"), gateway.calls)
    }

    private class FakeGateway : TapInitCallbackGateway {
        val calls = mutableListOf<String>()
        var callback: TapInitCallback? = null

        override fun add(callback: TapInitCallback) {
            calls += "add"
            this.callback = callback
        }

        override fun remove(callback: TapInitCallback) {
            calls += "remove"
        }
    }
}
