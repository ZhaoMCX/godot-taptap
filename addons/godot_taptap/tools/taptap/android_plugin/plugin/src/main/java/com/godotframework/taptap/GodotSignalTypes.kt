package com.godotframework.taptap

internal object GodotSignalTypes {
    // GodotPlugin.emitSignal receives Object varargs, so numeric values are boxed.
    // A primitive signal declaration fails Class.isInstance and terminates the Android activity.
    val LONG: Class<Long> = Long::class.javaObjectType
}
