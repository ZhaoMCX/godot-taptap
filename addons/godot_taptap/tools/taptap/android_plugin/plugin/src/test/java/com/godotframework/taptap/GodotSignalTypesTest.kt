package com.godotframework.taptap

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GodotSignalTypesTest {
    @Test
    fun longSignalTypeAcceptsBoxedKotlinLongValues() {
        val emittedValue: Any = 300001L

        assertEquals(java.lang.Long::class.java, GodotSignalTypes.LONG)
        assertFalse(GodotSignalTypes.LONG.isPrimitive)
        assertTrue(GodotSignalTypes.LONG.isInstance(emittedValue))
    }
}
