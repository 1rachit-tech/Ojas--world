package com.rachit.ojas

import android.content.Context
import android.graphics.Matrix
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.audio.DefaultGainProvider
import androidx.media3.common.audio.GainProcessor
import androidx.media3.common.audio.SpeedProvider
import androidx.media3.effect.AlphaScale
import androidx.media3.effect.Brightness
import androidx.media3.effect.Contrast
import androidx.media3.effect.HslAdjustment
import androidx.media3.effect.MatrixTransformation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import java.io.File

@androidx.media3.common.util.ExperimentalApi
object OjasMediaComposition {

    fun build(
        context: Context,
        project: Map<*, *>,
    ): Composition {
        val assets = (project["mediaAssets"] as? List<*>)
            ?.mapNotNull { it as? Map<*, *> }
            .orEmpty()
            .associateBy { it["assetId"]?.toString().orEmpty() }

        val timeline = (project["timeline"] as? List<*>)
            ?.mapNotNull { it as? Map<*, *> }
            .orEmpty()

        val effectLayers = (project["effectLayers"] as? List<*>)
            ?.mapNotNull { it as? Map<*, *> }
            .orEmpty()

        val videoItems = timeline.mapNotNull { clip ->
            buildVideoItem(assets, clip, effectLayers)
        }

        require(videoItems.isNotEmpty()) {
            "The project contains no exportable video or image clips."
        }

        val videoSequence =
            EditedMediaItemSequence.withAudioAndVideoFrom(videoItems)

        val audioItems = buildBackgroundAudioItems(project["audio"])
        val audioSequence = if (audioItems.isEmpty()) {
            null
        } else {
            EditedMediaItemSequence.withAudioFrom(audioItems)
                .buildUpon()
                .setIsLooping(true)
                .build()
        }

        return if (audioSequence == null) {
            Composition.Builder(videoSequence).build()
        } else {
            Composition.Builder(videoSequence, audioSequence).build()
        }
    }

    private fun buildVideoItem(
        assets: Map<String, Map<*, *>>,
        clip: Map<*, *>,
        effectLayers: List<Map<*, *>>,
    ): EditedMediaItem? {
        val sourceId = clip["sourceId"]?.toString().orEmpty()
        val asset = assets[sourceId] ?: return null
        val path = (asset["normalizedUri"]?.toString()?.takeIf { it.isNotBlank() }
            ?: asset["localUri"]?.toString().orEmpty())

        val file = File(path)
        if (!file.exists() || !file.isFile) return null

        val type = asset["type"]?.toString().orEmpty().lowercase()
        val isImage = type == "image"

        val speed = (clip["speed"] as? Number)?.toFloat()?.coerceIn(0.5f, 2.0f) ?: 1f
        val rotation = (clip["rotation"] as? Number)?.toFloat() ?: 0f
        val scale = (clip["scale"] as? Number)?.toFloat()?.coerceIn(0.5f, 2.5f) ?: 1f
        val x = (clip["x"] as? Number)?.toFloat()?.coerceIn(-1f, 1f) ?: 0f
        val y = (clip["y"] as? Number)?.toFloat()?.coerceIn(-1f, 1f) ?: 0f
        val opacity = (clip["opacity"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 1f

        val sourceDurationMs =
            (asset["durationMs"] as? Number)?.toLong()?.takeIf { it > 0 }
                ?: (clip["endMs"] as? Number)?.toLong()?.takeIf { it > 0 }
                ?: 3_000L

        val trimInMs =
            (clip["trimInMs"] as? Number)?.toLong()?.coerceAtLeast(0L) ?: 0L
        val rawTrimOut =
            (clip["trimOutMs"] as? Number)?.toLong()
        val trimOutMs =
            rawTrimOut?.coerceAtMost(sourceDurationMs)?.takeIf { it > trimInMs }
                ?: sourceDurationMs

        val durationMs =
            if (isImage) {
                (trimOutMs - trimInMs).coerceAtLeast(1L)
            } else {
                sourceDurationMs
            }

        val uri = file.toURI().toString()
        val mediaBuilder = MediaItem.Builder().setUri(uri)

        if (isImage) {
            mediaBuilder.setImageDurationMs(durationMs)
        } else {
            mediaBuilder.setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(trimInMs)
                    .setEndPositionMs(trimOutMs)
                    .build()
            )
        }

        val mediaItem = mediaBuilder.build()
        val originalVolume =
            (clip["originalVolume"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 1f
        val removeAudio = !isImage &&
            (originalVolume <= 0.001f || opacity <= 0f)

        val videoEffects = mutableListOf<androidx.media3.common.Effect>()

        if (rotation != 0f || scale != 1f || x != 0f || y != 0f) {
            val transform = MatrixTransformation { _: Long ->
                Matrix().apply {
                    postScale(scale, scale)
                    postRotate(rotation)
                    postTranslate(x, y)
                }
            }
            videoEffects.add(transform)
        }

        if (opacity < 0.999f) {
            videoEffects.add(AlphaScale(opacity))
        }

        val relevantEffects = effectLayers.filter {
            it["assetId"]?.toString() == sourceId
        }
        relevantEffects.forEach { effect ->
            when (effect["type"]?.toString()?.lowercase()) {
                "brightness" -> {
                    val value = (effect["value"] as? Number)?.toFloat()?.coerceIn(-1f, 1f) ?: 0f
                    videoEffects.add(Brightness(value))
                }
                "contrast" -> {
                    val value = (effect["value"] as? Number)?.toFloat()?.coerceIn(-1f, 1f) ?: 0f
                    videoEffects.add(Contrast(value))
                }
                "saturation" -> {
                    val value = (effect["value"] as? Number)?.toFloat()?.coerceIn(-100f, 100f) ?: 0f
                    videoEffects.add(
                        HslAdjustment.Builder()
                            .adjustSaturation(value)
                            .build()
                    )
                }
                "grayscale" -> {
                    videoEffects.add(
                        HslAdjustment.Builder()
                            .adjustSaturation(-100f)
                            .build()
                    )
                }
            }
        }

        val audioProcessors = mutableListOf<androidx.media3.common.audio.AudioProcessor>()

        if (!isImage && !removeAudio && originalVolume < 0.999f) {
            audioProcessors.add(
                GainProcessor(
                    DefaultGainProvider.Builder(originalVolume).build()
                )
            )
        }

        val effects = Effects(audioProcessors, videoEffects)
        val editedBuilder = EditedMediaItem.Builder(mediaItem)
            .setEffects(effects)
            .setFrameRate(30)

        if (!isImage) {
            editedBuilder.setDurationUs(durationMs * 1_000L)
        }

        if (speed != 1f) {
            editedBuilder.setSpeed(
                object : SpeedProvider {
                    override fun getNextSpeedChangeTimeUs(timeUs: Long): Long = C.TIME_UNSET
                    override fun getSpeed(timeUs: Long): Float = speed
                }
            )
        }

        editedBuilder.setRemoveAudio(removeAudio)
        return editedBuilder.build()
    }

    private fun buildBackgroundAudioItems(raw: Any?): List<EditedMediaItem> {
        val audioMaps = (raw as? List<*>)
            ?.mapNotNull { it as? Map<*, *> }
            .orEmpty()

        return audioMaps.mapNotNull { audio ->
            val path = audio["localUri"]?.toString()?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
            val file = File(path)
            if (!file.exists() || !file.isFile) return@mapNotNull null

            val durationMs =
                (audio["durationMs"] as? Number)?.toLong()?.takeIf { it > 0 } ?: 1_000L
            val startMs =
                ((audio["startMs"] as? Number)?.toLong() ?: 0L).coerceAtLeast(0L)
            val volume =
                (audio["volume"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 1f

            val mediaItem = MediaItem.Builder()
                .setUri(file.toURI().toString())
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(startMs)
                        .setEndPositionMs(startMs + durationMs)
                        .build()
                )
                .build()

            val processors = if (volume < 0.999f) {
                listOf(
                    GainProcessor(
                        DefaultGainProvider.Builder(volume).build()
                    )
                )
            } else {
                emptyList()
            }

            EditedMediaItem.Builder(mediaItem)
                .setEffects(Effects(processors, emptyList()))
                .setDurationUs((startMs + durationMs) * 1_000L)
                .build()
        }
    }
}
