@echo off
tasm /m TI_CACHE.asm
tasm /m CACHEBM.ASM
tlink /t TI_CACHE.obj
tlink /t CACHEBM.ASM