#!/bin/bash
# Lossless masters (1920×1080, 30 fps, from render.js) → README files
#   sumuk-intro.mp4 : H.264 1080p, CRF 18, faststart — under GitHub's 10 MB video attachment limit
#   sumuk-intro.gif : 880 px, 15 fps, one global palette, loops forever. It starts at 4.4 s (the finished
#                     title card) so that a viewer who sees only the first frame still gets the title;
#                     the loop is seamless because the video's last frame equals its first.
# Usage: ./encode.sh [textured master] [plain-paper master] [out dir]
set -euo pipefail
TEX=${1:-../master.mkv}
FLAT=${2:-../master_flat.mkv}
OUT=${3:-..}
START=132        # frame index of t = 4.4 s at 30 fps
FPS=15; W=880
PAL=$(mktemp -t sumuk-palXXXX).png
ffmpeg -y -loglevel error -i "$TEX" -c:v libx264 -preset slow -crf 18 -tune animation -pix_fmt yuv420p \
  -movflags +faststart -an "$OUT/sumuk-intro.mp4"
ROT="[0:v]trim=start_frame=$START,setpts=PTS-STARTPTS[a];[0:v]trim=end_frame=$START,setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1[r]"
ffmpeg -y -loglevel error -i "$FLAT" -filter_complex "$ROT;[r]fps=$FPS,scale=$W:-1:flags=lanczos,palettegen=max_colors=256:stats_mode=diff" "$PAL"
ffmpeg -y -loglevel error -i "$FLAT" -i "$PAL" -filter_complex \
  "$ROT;[r]fps=$FPS,scale=$W:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
  -loop 0 "$OUT/sumuk-intro.gif"
rm -f "$PAL"
ls -lh "$OUT/sumuk-intro.mp4" "$OUT/sumuk-intro.gif"
