package com.rachit.ojas

import android.content.Context
import android.content.Intent
import android.net.Uri

import android.os.Handler
import android.os.Looper
import androidx.media3.common.MimeTypes
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.CompositionPlayer
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

import android.os.Bundle
import android.view.View
import android.view.WindowManager
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.ui.PlayerView
import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MainActivity : FlutterActivity() {
    private var pendingAudioResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    private fun pickAudioFile(result: MethodChannel.Result) {
        if (pendingAudioResult != null) {
            result.error("PICKER_BUSY", "Another audio picker request is already active.", null)
            return
        }

        pendingAudioResult = result
        startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "audio/*"
            },
            AUDIO_PICK_REQUEST,
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != AUDIO_PICK_REQUEST) return

        val result = pendingAudioResult
        pendingAudioResult = null
        if (result == null) return

        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            val uri = data.data as Uri
            val directory = File(filesDir, "ojas/audio")
            directory.mkdirs()

            val name = "audio_" + System.currentTimeMillis() + ".bin"
            val target = File(directory, name)

            contentResolver.openInputStream(uri).use { input ->
                requireNotNull(input) { "Unable to open selected audio." }
                FileOutputStream(target).use { output ->
                    input.copyTo(output)
                }
            }

            val durationMs = runCatching {
                android.media.MediaMetadataRetriever().run {
                    setDataSource(target.absolutePath)
                    extractMetadata(
                        android.media.MediaMetadataRetriever.METADATA_KEY_DURATION,
                    )?.toLongOrNull() ?: 0L
                }
            }.getOrDefault(0L)

            result.success(
                mapOf(
                    "path" to target.absolutePath,
                    "durationMs" to durationMs,
                ),
            )
        } catch (error: Throwable) {
            result.error(
                "AUDIO_PICK_FAILED",
                error.message ?: "Unable to import audio.",
                null,
            )
        }
    }

    companion object {
        private const val AUDIO_PICK_REQUEST = 9217
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "ojas/hls_player",
            OjasHlsPlayerFactory(),
        )
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "ojas/composition_preview",
            OjasCompositionPlayerFactory(),
        )

        OjasVideoExportBridge(this, flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ojas/audio_picker",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAudio" -> pickAudioFile(result)
                else -> result.notImplemented()
            }
        }

    }
}

@UnstableApi
private class OjasHlsPlayerFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        val params = args as? Map<*, *>
        val url = params?.get("url") as? String ?: ""
        return OjasHlsPlayer(context, url)
    }
}

@UnstableApi
private class OjasHlsPlayer(
    context: Context,
    url: String,
) : PlatformView {
    private val playerView = PlayerView(context)
    private val player: ExoPlayer

    init {
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                2_000,
                3_000,
                1_000,
                1_000,
            )
            .setBackBuffer(0, false)
            .setPrioritizeTimeOverSizeThresholds(true)
            .setTargetBufferBytes(C.LENGTH_UNSET)
            .build()

        player = ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .build()
            .apply {
                repeatMode = ExoPlayer.REPEAT_MODE_ONE
                setMediaItem(MediaItem.fromUri(url))
                prepare()
                playWhenReady = true
            }

        playerView.useController = false
        playerView.player = player
        playerView.setOnClickListener {
            if (player.isPlaying) player.pause() else player.play()
        }
    }

    override fun getView(): View = playerView

    override fun dispose() {
        playerView.player = null
        player.release()
    }
}


@UnstableApi
private class OjasVideoExportBridge(
    private val context: Context,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methods =
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ojas/video_transformer/methods")
    private val events =
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "ojas/video_transformer/events")
    private val handler = Handler(Looper.getMainLooper())
    private val progressHolder = ProgressHolder()
    private var transformer: Transformer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var requestId: String? = null
    private var outputPath: String? = null

    private val progressRunnable = object : Runnable {
        override fun run() {
            val active = transformer ?: return
            val id = requestId ?: return

            when (active.getProgress(progressHolder)) {
                Transformer.PROGRESS_STATE_AVAILABLE -> {
                    eventSink?.success(
                        mapOf(
                            "type" to "progress",
                            "requestId" to id,
                            "progress" to progressHolder.progress,
                        ),
                    )
                }
            }

            handler.postDelayed(this, 500L)
        }
    }

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startExport" -> startExport(call, result)
            "startCompositionExport" -> startCompositionExport(call, result)
            "cancelExport" -> cancelExport(result)
            else -> result.notImplemented()
        }
    }

    private fun startExport(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (transformer != null) {
            result.error("EXPORT_BUSY", "Another video export is already running.", null)
            return
        }

        val inputPath = call.argument<String>("inputPath").orEmpty()
        val targetPath = call.argument<String>("outputPath").orEmpty()
        val startMs = call.argument<Int>("startMs") ?: -1
        val endMs = call.argument<Int>("endMs") ?: -1
        val removeAudio = call.argument<Boolean>("removeAudio") ?: false

        val input = File(inputPath)
        if (!input.exists() || !input.isFile) {
            result.error("INPUT_MISSING", "The source video file does not exist.", null)
            return
        }

        if (startMs < 0 || endMs <= startMs) {
            result.error("INVALID_RANGE", "The selected trim range is invalid.", null)
            return
        }

        try {
            val target = File(targetPath)
            target.parentFile?.mkdirs()
            if (target.exists()) {
                target.delete()
            }

            val id = UUID.randomUUID().toString()
            requestId = id
            outputPath = target.absolutePath

            val inputMediaItem = androidx.media3.common.MediaItem.Builder()
                .setUri(input.toURI().toString())
                .setClippingConfiguration(
                    androidx.media3.common.MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(startMs.toLong())
                        .setEndPositionMs(endMs.toLong())
                        .build(),
                )
                .build()

            val editedMediaItem = EditedMediaItem.Builder(inputMediaItem)
                .setRemoveAudio(removeAudio)
                .build()

            val builtTransformer = Transformer.Builder(context)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(
                    object : Transformer.Listener {
                        override fun onCompleted(
                            composition: androidx.media3.transformer.Composition,
                            exportResult: ExportResult,
                        ) {
                            handler.removeCallbacks(progressRunnable)
                            val path = outputPath
                            val bytes = if (path != null) File(path).length() else 0L
                            eventSink?.success(
                                mapOf(
                                    "type" to "completed",
                                    "requestId" to id,
                                    "outputPath" to (path ?: ""),
                                    "bytes" to bytes,
                                ),
                            )
                            clearState()
                        }

                        override fun onError(
                            composition: androidx.media3.transformer.Composition,
                            exportResult: ExportResult,
                            exportException: ExportException,
                        ) {
                            handler.removeCallbacks(progressRunnable)
                            val path = outputPath
                            if (path != null) {
                                File(path).takeIf { it.exists() }?.delete()
                            }
                            eventSink?.success(
                                mapOf(
                                    "type" to "error",
                                    "requestId" to id,
                                    "message" to (exportException.message ?: "Local video export failed."),
                                ),
                            )
                            clearState()
                        }
                    },
                )
                .build()

            transformer = builtTransformer
            eventSink?.success(
                mapOf(
                    "type" to "started",
                    "requestId" to id,
                ),
            )
            builtTransformer.start(editedMediaItem, target.absolutePath)
            handler.post(progressRunnable)
            result.success(id)
        } catch (error: Throwable) {
            handler.removeCallbacks(progressRunnable)
            clearState()
            result.error(
                "EXPORT_START_FAILED",
                error.message ?: "Unable to start local video export.",
                null,
            )
        }
    }


    private fun startCompositionExport(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (transformer != null) {
            result.error("EXPORT_BUSY", "Another video export is already running.", null)
            return
        }

        val targetPath = call.argument<String>("outputPath").orEmpty()
        @Suppress("UNCHECKED_CAST")
        val project = call.argument<Map<String, Any?>>("project")
        if (targetPath.isBlank() || project == null) {
            result.error("INVALID_PROJECT", "The composition project is missing.", null)
            return
        }

        try {
            val target = File(targetPath)
            target.parentFile?.mkdirs()
            if (target.exists()) target.delete()

            val id = UUID.randomUUID().toString()
            requestId = id
            outputPath = target.absolutePath

            val composition = OjasMediaComposition.build(context, project)
            val builtTransformer = Transformer.Builder(context)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(
                    object : Transformer.Listener {
                        override fun onCompleted(
                            composition: androidx.media3.transformer.Composition,
                            exportResult: ExportResult,
                        ) {
                            handler.removeCallbacks(progressRunnable)
                            val path = outputPath
                            val bytes = if (path != null) File(path).length() else 0L
                            eventSink?.success(
                                mapOf(
                                    "type" to "completed",
                                    "requestId" to id,
                                    "outputPath" to (path ?: ""),
                                    "bytes" to bytes,
                                ),
                            )
                            clearState()
                        }

                        override fun onError(
                            composition: androidx.media3.transformer.Composition,
                            exportResult: ExportResult,
                            exportException: ExportException,
                        ) {
                            handler.removeCallbacks(progressRunnable)
                            val path = outputPath
                            if (path != null) {
                                File(path).takeIf { it.exists() }?.delete()
                            }
                            eventSink?.success(
                                mapOf(
                                    "type" to "error",
                                    "requestId" to id,
                                    "message" to (
                                        exportException.message
                                            ?: "Local composition export failed."
                                    ),
                                ),
                            )
                            clearState()
                        }
                    },
                )
                .build()

            transformer = builtTransformer
            eventSink?.success(
                mapOf(
                    "type" to "started",
                    "requestId" to id,
                ),
            )
            builtTransformer.start(composition, target.absolutePath)
            handler.post(progressRunnable)
            result.success(id)
        } catch (error: Throwable) {
            handler.removeCallbacks(progressRunnable)
            clearState()
            result.error(
                "COMPOSITION_EXPORT_FAILED",
                error.message ?: "Unable to start composition export.",
                null,
            )
        }
    }

    private fun cancelExport(result: MethodChannel.Result) {
        val active = transformer
        val id = requestId
        val path = outputPath

        if (active == null || id == null) {
            result.success(null)
            return
        }

        handler.removeCallbacks(progressRunnable)
        active.cancel()
        if (path != null) {
            File(path).takeIf { it.exists() }?.delete()
        }

        eventSink?.success(
            mapOf(
                "type" to "error",
                "requestId" to id,
                "message" to "Video export was cancelled.",
            ),
        )
        clearState()
        result.success(null)
    }

    private fun clearState() {
        handler.removeCallbacks(progressRunnable)
        transformer?.removeAllListeners()
        transformer = null
        requestId = null
        outputPath = null
    }
}


@androidx.media3.common.util.UnstableApi
@androidx.media3.common.util.ExperimentalApi
private class OjasCompositionPlayerFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val project = (args as? Map<*, *>)?.mapKeys { it.key }?.mapValues { it.value }
            ?: emptyMap<String, Any?>()
        return OjasCompositionPlayer(context, project)
    }
}

@androidx.media3.common.util.UnstableApi
@androidx.media3.common.util.ExperimentalApi
private class OjasCompositionPlayer(
    context: Context,
    private val project: Map<*, *>,
) : PlatformView {
    private val playerView = PlayerView(context)
    private val player: CompositionPlayer

    init {
        @Suppress("UNCHECKED_CAST")
        val safeProject = project as Map<String, Any?>
        val composition = OjasMediaComposition.build(context, safeProject)

        player = CompositionPlayer.Builder(context).build().apply {
            repeatMode = androidx.media3.common.Player.REPEAT_MODE_OFF
            setComposition(composition)
            prepare()
            playWhenReady = true
        }

        playerView.useController = false
        playerView.player = player
    }

    override fun getView(): View = playerView

    override fun dispose() {
        playerView.player = null
        player.release()
    }
}
