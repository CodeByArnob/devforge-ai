package com.devforge.ai.client

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channelName = "devforge/native_workspace"
    private val maxFileBytes = 1_048_576L
    private val maxEntries = 500
    private val maxDepth = 6

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "runtimeInfo" -> result.success(runtimeInfo())
                        "listEntries" -> {
                            val path = call.argument<String>("path") ?: ""
                            result.success(listEntries(resolveWorkspacePath(path)))
                        }
                        "readFile" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("A file path is required.")
                            val file = resolveWorkspacePath(path)
                            if (!file.isFile) throw IllegalArgumentException("The requested path is not a file.")
                            if (file.length() > maxFileBytes) {
                                throw IllegalArgumentException("Files larger than 1 MiB cannot be opened in the mobile editor.")
                            }
                            result.success(file.readText(Charsets.UTF_8))
                        }
                        "writeFile" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("A file path is required.")
                            val content = call.argument<String>("content")
                                ?: throw IllegalArgumentException("File content is required.")
                            if (content.toByteArray(Charsets.UTF_8).size > maxFileBytes) {
                                throw IllegalArgumentException("Files larger than 1 MiB cannot be saved in the mobile editor.")
                            }
                            val file = resolveWorkspacePath(path)
                            file.parentFile?.mkdirs()
                            file.writeText(content, Charsets.UTF_8)
                            result.success(mapOf("saved" to true, "size" to file.length()))
                        }
                        "createDirectory" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("A directory path is required.")
                            val directory = resolveWorkspacePath(path)
                            if (directory.exists() && !directory.isDirectory) {
                                throw IllegalArgumentException("A file already exists at this path.")
                            }
                            if (!directory.exists() && !directory.mkdirs()) {
                                throw IOException("Unable to create the directory.")
                            }
                            result.success(mapOf("created" to true))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("NATIVE_WORKSPACE_ERROR", error.message ?: "Workspace operation failed.", null)
                }
            }
    }

    private fun workspaceRoot(): File {
        val root = File(filesDir, "devforge-workspace")
        if (!root.exists() && !root.mkdirs()) {
            throw IOException("Unable to initialize the private workspace.")
        }
        return root.canonicalFile
    }

    private fun resolveWorkspacePath(relativePath: String): File {
        if (relativePath.startsWith("/") || relativePath.contains(0.toChar())) {
            throw IllegalArgumentException("Absolute paths and invalid characters are not allowed.")
        }
        val root = workspaceRoot()
        val candidate = File(root, relativePath).canonicalFile
        if (candidate != root && !candidate.path.startsWith(root.path + File.separator)) {
            throw SecurityException("The requested path escapes the private workspace.")
        }
        return candidate
    }

    private fun listEntries(directory: File): List<Map<String, Any>> {
        if (!directory.exists()) return emptyList()
        if (!directory.isDirectory) throw IllegalArgumentException("The requested path is not a directory.")
        val root = workspaceRoot()
        val results = mutableListOf<Map<String, Any>>()
        fun walk(current: File, depth: Int) {
            if (depth > maxDepth || results.size >= maxEntries) return
            val children = current.listFiles()?.sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
                ?: return
            for (child in children) {
                if (results.size >= maxEntries) break
                val canonical = child.canonicalFile
                if (canonical != root && !canonical.path.startsWith(root.path + File.separator)) continue
                val relative = canonical.path.removePrefix(root.path + File.separator).replace(File.separatorChar, '/')
                results += mapOf(
                    "name" to child.name,
                    "path" to relative,
                    "type" to if (child.isDirectory) "directory" else "file",
                    "size" to if (child.isFile) child.length() else 0L
                )
                if (child.isDirectory) walk(child, depth + 1)
            }
        }
        walk(directory, 0)
        return results
    }

    private fun runtimeInfo(): Map<String, Any> {
        val root = workspaceRoot()
        val runtimeHome = File(filesDir, "linux-runtime")
        val bash = File(runtimeHome, "bin/bash")
        return mapOf(
            "platform" to "android",
            "sdkInt" to Build.VERSION.SDK_INT,
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "workspaceReady" to root.isDirectory,
            "workspaceName" to "DevForge Private Workspace",
            "linuxRuntimeInstalled" to (bash.isFile && bash.canExecute()),
            "linuxRuntimeStatus" to if (bash.isFile && bash.canExecute()) "installed" else "not_installed",
            "executionBackend" to "local_workspace_only"
        )
    }
}
