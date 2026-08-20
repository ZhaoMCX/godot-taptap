package com.godotframework.taptap

import java.io.File

internal class AtomicFileWriter {
    /** Returns null on success or a safe diagnostic message on failure. */
    fun write(destinationPath: String, data: ByteArray): String? {
        val destination = File(destinationPath)
        val parent = destination.parentFile
            ?: return "下载目标没有有效的父目录"
        if (!parent.exists() && !parent.mkdirs()) {
            return "无法创建下载目标目录"
        }

        val suffix = "${System.nanoTime()}-${Thread.currentThread().name.hashCode()}"
        val temporary = File(parent, ".${destination.name}.$suffix.tmp")
        val backup = File(parent, ".${destination.name}.$suffix.bak")
        return try {
            temporary.writeBytes(data)
            if (destination.exists() && !destination.renameTo(backup)) {
                return "无法暂存原有下载文件"
            }
            if (!temporary.renameTo(destination)) {
                if (backup.exists()) backup.renameTo(destination)
                return "无法替换下载目标文件"
            }
            if (backup.exists()) backup.delete()
            null
        } catch (error: Throwable) {
            if (!destination.exists() && backup.exists()) backup.renameTo(destination)
            error.message ?: "写入下载文件失败"
        } finally {
            if (temporary.exists()) temporary.delete()
            if (backup.exists() && destination.exists()) backup.delete()
        }
    }
}
