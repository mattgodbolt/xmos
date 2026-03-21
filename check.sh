#!/bin/bash
set -e
beebasm -i xmos.asm -o build.rom
if cmp -s original.rom build.rom; then
    echo "MATCH: build.rom is identical to original.rom"
else
    echo "MISMATCH: build.rom differs from original.rom"
    cmp -l original.rom build.rom | head -20
    exit 1
fi
