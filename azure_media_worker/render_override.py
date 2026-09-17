from __future__ import annotations

from typing import Any

import worker


def _even(value: float, minimum: int = 2) -> int:
    rounded = max(minimum, int(round(value)))
    return rounded if rounded % 2 == 0 else rounded - 1


def _clip_visual_chain(clip: dict[str, Any], metadata: dict[str, Any], label: str, filter_parts: list[str]) -> tuple[str, int]:
    source_width = max(2, int(metadata.get('width') or 2))
    source_height = max(2, int(metadata.get('height') or 2))
    base_width = min(720, source_width)
    base_height = _even(source_height * base_width / source_width)

    trim_in, trim_out, speed, rotation = worker._bounded_clip(clip, int(metadata['durationMs']))
    crop_left = max(0.0, min(0.9, float(clip.get('cropLeft') or 0.0)))
    crop_right = max(0.0, min(0.9, float(clip.get('cropRight') or 0.0)))
    crop_top = max(0.0, min(0.9, float(clip.get('cropTop') or 0.0)))
    crop_bottom = max(0.0, min(0.9, float(clip.get('cropBottom') or 0.0)))
    if crop_left + crop_right >= 1.0 or crop_top + crop_bottom >= 1.0:
        raise ValueError('Edit graph crop leaves no visible video area.')

    scale = max(0.1, min(5.0, float(clip.get('scale') or 1.0)))
    x = max(-1.0, min(1.0, float(clip.get('x') or 0.0)))
    y = max(-1.0, min(1.0, float(clip.get('y') or 0.0)))
    opacity = max(0.0, min(1.0, float(clip.get('opacity') if clip.get('opacity') is not None else 1.0)))

    crop_width = f'trunc(iw*(1-{crop_left:.6f}-{crop_right:.6f})/2)*2'
    crop_height = f'trunc(ih*(1-{crop_top:.6f}-{crop_bottom:.6f})/2)*2'
    crop_x = f'trunc(iw*{crop_left:.6f}/2)*2'
    crop_y = f'trunc(ih*{crop_top:.6f}/2)*2'

    filters = [
        f'trim=start={trim_in / 1000:.3f}:end={trim_out / 1000:.3f}',
        'setpts=PTS-STARTPTS',
        f'setpts=PTS/{speed:.5f}',
        f'crop=w={crop_width}:h={crop_height}:x={crop_x}:y={crop_y}',
    ]
    if rotation == 90:
        filters.append('transpose=1')
    elif rotation == 180:
        filters.extend(['hflip', 'vflip'])
    elif rotation == 270:
        filters.append('transpose=2')

    scaled_width = _even(base_width * scale)
    scaled_height = _even(base_height * scale)
    filters.append(f'scale=w={scaled_width}:h={scaled_height}:force_original_aspect_ratio=decrease')

    if scale <= 1.0:
        pad_x = f'max(0,min(ow-iw,(ow-iw)/2+{x:.6f}*ow/2))'
        pad_y = f'max(0,min(oh-ih,(oh-ih)/2+{y:.6f}*oh/2))'
        filters.append(f"pad={base_width}:{base_height}:x='{pad_x}':y='{pad_y}':color=black")
    else:
        crop_x_position = f'max(0,min(iw-ow,(iw-ow)/2-{x:.6f}*ow/2))'
        crop_y_position = f'max(0,min(ih-oh,(ih-oh)/2-{y:.6f}*oh/2))'
        filters.append(f"crop={base_width}:{base_height}:x='{crop_x_position}':y='{crop_y_position}'")

    if opacity < 0.999:
        filters.extend([
            'format=rgba',
            f'colorchannelmixer=aa={opacity:.4f}',
            'format=yuv420p',
        ])

    filters.append('setsar=1')
    filter_parts.append(f'[0:v]{",".join(filters)}[{label}]')
    return label, round((trim_out - trim_in) / speed)


def render_edit_graph(source: str, output: str, metadata: dict[str, Any], edit_graph: dict[str, Any], audio_files: list[tuple[dict[str, Any], Any]]) -> str:
    raw_timeline = edit_graph.get('timeline')
    if not isinstance(raw_timeline, list) or not raw_timeline:
        raw_timeline = [{'trimInMs': 0, 'trimOutMs': metadata['durationMs'], 'speed': 1.0, 'rotation': 0}]

    clips = [item for item in raw_timeline[:32] if isinstance(item, dict)]
    if not clips:
        clips = [{'trimInMs': 0, 'trimOutMs': metadata['durationMs'], 'speed': 1.0, 'rotation': 0}]

    filter_parts: list[str] = []
    concat_inputs: list[str] = []
    rendered_duration_ms = 0
    has_audio = bool(metadata.get('hasAudio'))

    for index, clip in enumerate(clips):
        video_label = f'v{index}'
        _, clip_duration_ms = _clip_visual_chain(clip, metadata, video_label, filter_parts)
        rendered_duration_ms += clip_duration_ms
        if has_audio:
            audio_label = f'a{index}'
            trim_in, trim_out, speed, _ = worker._bounded_clip(clip, int(metadata['durationMs']))
            filter_parts.append(
                f'[0:a]atrim=start={trim_in / 1000:.3f}:end={trim_out / 1000:.3f},'
                f'asetpts=PTS-STARTPTS,{worker._atempo_chain(speed)}[{audio_label}]'
            )
            concat_inputs.append(f'[{video_label}][{audio_label}]')
        else:
            concat_inputs.append(f'[{video_label}]')

    if len(clips) == 1:
        filter_parts.append('[v0]null[preout]')
        final_video_input = 'preout'
        final_audio = 'a0' if has_audio else None
    elif has_audio:
        filter_parts.append(''.join(concat_inputs) + f'concat=n={len(clips)}:v=1:a=1[basev][basea]')
        final_video_input = 'basev'
        final_audio = 'basea'
    else:
        filter_parts.append(''.join(concat_inputs) + f'concat=n={len(clips)}:v=1:a=0[basev]')
        final_video_input = 'basev'
        final_audio = None

    if audio_files:
        duration_sec = max(0.001, rendered_duration_ms / 1000.0)
        mix_inputs: list[str] = []
        if final_audio:
            mix_inputs.append(final_audio)
        else:
            filter_parts.append(f'anullsrc=r=48000:cl=stereo:d={duration_sec:.3f}[base_silence]')
            mix_inputs.append('base_silence')

        for index, (layer, _) in enumerate(audio_files):
            if layer.get('muted') is True:
                continue
            timing = worker._safe_layer_time(layer, rendered_duration_ms)
            if timing is None:
                continue
            start_ms, end_ms = timing
            clip_duration = max(0.001, (end_ms - start_ms) / 1000.0)
            try:
                volume = max(0.0, min(2.0, float(layer.get('volume') or 1.0)))
            except (TypeError, ValueError):
                volume = 1.0
            input_index = index + 1
            output_label = f'addaudio{index}'
            filter_parts.append(
                f'[{input_index}:a]atrim=start=0:end={clip_duration:.3f},'
                f'asetpts=PTS-STARTPTS,volume={volume:.3f},'
                f'aresample=async=1:first_pts=0,adelay={start_ms}|{start_ms},'
                f'apad=whole_dur={duration_sec:.3f},atrim=end={duration_sec:.3f}[{output_label}]'
            )
            mix_inputs.append(output_label)

        if len(mix_inputs) > 1:
            filter_parts.append(''.join(f'[{value}]' for value in mix_inputs) + f'amix=inputs={len(mix_inputs)}:duration=first:dropout_transition=0,aresample=async=1:first_pts=0[audiomix]')
            final_audio = 'audiomix'
        elif mix_inputs:
            final_audio = mix_inputs[0]

    final_video = worker._append_visual_layers(filter_parts, final_video_input, edit_graph, rendered_duration_ms)
    command = ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', source]
    for _, audio_path in audio_files:
        command.extend(['-i', str(audio_path)])
    command.extend(['-filter_complex', ';'.join(filter_parts), '-map', f'[{final_video}]'])
    if final_audio:
        command.extend(['-map', f'[{final_audio}]', '-c:a', 'aac', '-b:a', '96k'])
    command.extend([
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
        '-maxrate', '2M', '-bufsize', '4M', '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart', output,
    ])
    worker._run(command)
    return 'edit-graph-v5-render'


def apply() -> None:
    worker._render_edit_graph = render_edit_graph
