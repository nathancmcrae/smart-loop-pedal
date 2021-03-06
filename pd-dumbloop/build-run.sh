#!/usr/bin/env bash
set -euo pipefail

cc -DPD -I "/usr/include/pd" -DUNIX  -fPIC  -Wall -Wextra -Wshadow -Winline -Wstrict-aliasing -O3 -ffast-math -funroll-loops -fomit-frame-pointer -march=core2 -mfpmath=sse -msse -msse2 -msse3 -o midimock.o -c midimock.c
zig build-lib --library c -I . -I "/usr/include/pd" -fno-stack-check -fcompiler-rt -DPD -DUNIX -fPIC -rpath "\$ORIGIN" --main-pkg-path .. zigimock.zig
cc -rdynamic -shared -fPIC -Wl,-rpath,"\$ORIGIN",--enable-new-dtags -o midimock.pd_linux midimock.o libzigimock.a  -lc -lm
pd -alsamidi -midiindev 1 -midioutdev 1 -lib midimock.pd_linux mockingbird-test.pd
