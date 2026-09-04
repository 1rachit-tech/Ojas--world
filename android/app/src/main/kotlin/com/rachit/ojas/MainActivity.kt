package com.rachit.ojas

import android.content.Context
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
    override fun onCreate(savedInstanceState: Bundle?) {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "ojas/hls_player",
            OjasHlsPlayerFactory(),
        )
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
