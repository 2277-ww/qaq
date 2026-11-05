#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""生成旁白音频与时间轴：逐句合成 -> 拼接整轨 -> 输出 timeline.json
运行： C:\\Users\\paradox\\PYthon\\python.exe build/tts.py
"""
import asyncio
import json
import os
import subprocess
import sys
import wave

import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "audio")
FFMPEG = r"C:\Users\paradox\PYthon\lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe"

LEAD = 0.55      # 场景开始到第一句的留白
GAP = 0.26       # 句间停顿
TAIL = 0.85      # 场景收尾留白
FPS = 25


def ff(args):
    p = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y"] + args,
                       capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr[-800:])
    return p


def wav_dur(path):
    with wave.open(path, "rb") as w:
        return w.getnframes() / float(w.getframerate())


async def synth(text, mp3_path):
    c = edge_tts.Communicate(text, VOICE, rate="+4%")
    await c.save(mp3_path)


async def main():
    global VOICE
    with open(os.path.join(ROOT, "narration.json"), "r", encoding="utf-8") as f:
        spec = json.load(f)
    VOICE = spec.get("voice", "zh-CN-YunxiNeural")
    os.makedirs(AUDIO, exist_ok=True)

    scenes = []
    cursor = 0.0
    for sc in spec["scenes"]:
        lines = []
        t = cursor + LEAD
        for i, text in enumerate(sc["lines"]):
            tag = "%s_%02d" % (sc["id"], i)
            mp3 = os.path.join(AUDIO, tag + ".mp3")
            wav = os.path.join(AUDIO, tag + ".wav")
            if not os.path.exists(wav):
                await synth(text, mp3)
                ff(["-i", mp3, "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", wav])
            d = wav_dur(wav)
            lines.append({"text": text, "wav": wav, "start": round(t, 3),
                          "end": round(t + d, 3), "dur": round(d, 3)})
            t += d + GAP
        spoken = (t - GAP) - cursor
        dur = max(sc["minDur"], spoken + TAIL)
        dur = round(dur * FPS) / FPS  # 对齐帧
        scenes.append({"id": sc["id"], "title": sc["title"], "start": round(cursor, 3),
                       "dur": round(dur, 3), "lines": lines})
        cursor += dur

    total = cursor
    with open(os.path.join(ROOT, "timeline.json"), "w", encoding="utf-8") as f:
        json.dump({"fps": FPS, "duration": round(total, 3), "scenes": scenes}, f,
                  ensure_ascii=False, indent=1)

    # 合成整轨：按绝对时间放置每句
    rate, ch = 44100, 1
    n_total = int(total * rate) + rate // 10
    buf = bytearray(n_total * 2)
    for sc in scenes:
        for ln in sc["lines"]:
            with wave.open(ln["wav"], "rb") as w:
                data = w.readframes(w.getnframes())
            off = int(ln["start"] * rate) * 2
            buf[off:off + len(data)] = data
    mix = os.path.join(AUDIO, "narration.wav")
    with wave.open(mix, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(bytes(buf))
    ff(["-i", mix, "-c:a", "aac", "-b:a", "160k", "-ar", "44100", os.path.join(AUDIO, "narration.m4a")])

    print("total %.2fs  scenes=%d" % (total, len(scenes)))
    for sc in scenes:
        print("  %-9s %6.2fs  lines=%d" % (sc["id"], sc["dur"], len(sc["lines"])))


if __name__ == "__main__":
    asyncio.run(main())
