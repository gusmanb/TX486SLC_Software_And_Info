IDEAL
P486

MACRO cacheout index, value
        mov al, index
        out 22h, al
        mov al, value
        out 23h, al
ENDM

MACRO print str
        mov dx, offset str
        mov ah, 09h
        int 21h
ENDM

;Check for flag in command line
;Jump to label if not found

MACRO ifnoflag flag_char, target_label
        LOCAL search_loop, check_char, next_char, found, not_found
        push ax
        push cx
        push si

        xor cx, cx
        mov si, 80h
        mov cl, [ds:si]         ;command line size
        jcxz not_found          ;jump if empty

        inc si                  ;args start

search_loop:
        mov al, [si]
        inc si
        cmp al, '/'             ;starts with '/'?
        je check_char
        cmp al, '-'             ;starts with '-'?
        je check_char          
        
next_char:
        dec cx
        jnz search_loop
        jmp not_found

check_char:
        dec cx
        jz not_found            ;nothing after flag start

        mov al, [si]
        inc si
        
        and al, 0DFh            ;uppercase
        mov ah, flag_char
        and ah, 0DFh
        
        cmp al, ah
        je found                ;flag found

        jmp next_char

not_found:
        pop si
        pop cx
        pop ax
        jmp target_label

found:
        pop si
        pop cx
        pop ax

ENDM

MACRO CCR0_SET value
        mov al, [byte ptr CCR0_value]
        OR al, value
        mov [byte ptr CCR0_value], al
ENDM

MACRO CCR1_SET value
        mov al, [byte ptr CCR1_value]
        OR al, value
        mov [byte ptr CCR1_value], al
ENDM


NC0     EQU     00000001b       ; Non-cacheable 1MB boundaries
NC0FLAG EQU     'M'             ; Flag
NC1     EQU     00000010b       ; Non-cacheable upper memory area
NC1FLAG EQU     'U'             ; Flag
A20M    EQU     00000100b       ; Enable /A20M
A20FLAG EQU     'A'             ; Flag
KEN     EQU     00001000b       ; Enable /KEN
KENFLAG EQU     'K'             ; Flag
FLUSH   EQU     00010000b       ; Enable /FLUSH
FLSFLAG EQU     'F'             ; Flag
BARB    EQU     00100000b       ; Enable /BARB
BRBFLAG EQU     'B'             ; Flag
DIRECT  EQU     01000000b       ; Enable direct mode cache
DIRFLAG EQU     'D'             ; Flag
SUS     EQU     10000000b       ; Enable suspend pins
SUSFLAG EQU     'S'             ; Flag
SHADOW  EQU     00100000b       ; Enable caching of shadow
SHDFLAG EQU     'C'             ; Flag

DEFCCR0 EQU     00010100b       ; Default CCR0 (A20M + FLUSH)
DEFCCR1 EQU     00100000b       ; Default CCR1 (Enable cache on ARR2)
DEFFLAG EQU     'Q'             ; Flag

HLPFLAG EQU     'H'             ; Flag

CRLF    EQU 0Dh, 0Ah

SEGMENT CODE USE16
        ASSUME CS:CODE, DS:CODE
        ORG 100h

start:
        print welcome
        ifnoflag HLPFLAG, check_default
        print help_msg
        ret

check_default:
        ifnoflag DEFFLAG, check_nc0
        CCR0_SET DEFCCR0
        CCR1_SET DEFCCR1
        print default_msg
        jmp apply

check_nc0:
        ifnoflag NC0FLAG, check_nc1
        CCR0_SET NC0
        print nc0_msg

check_nc1:
        ifnoflag NC1FLAG, check_a20m
        CCR0_SET NC1
        print nc1_msg

check_a20m:
        ifnoflag A20FLAG, check_ken
        CCR0_SET A20M
        print a20m_msg

check_ken:
        ifnoflag KENFLAG, check_flush
        CCR0_SET KEN
        print ken_msg

check_flush:
        ifnoflag FLSFLAG, check_barb
        CCR0_SET FLUSH
        print flush_msg

check_barb:
        ifnoflag BRBFLAG, check_dir
        CCR0_SET BARB
        print barb_msg

check_dir:
        ifnoflag DIRFLAG, check_sus
        CCR0_SET DIRECT
        print direct_msg

check_sus:
        ifnoflag SUSFLAG, check_shadow
        CCR0_SET SUS
        print sus_msg

check_shadow:
        ifnoflag SHDFLAG, apply
        CCR1_SET SHADOW
        print shadow_msg

apply:

        cli
        mov eax, cr0
        or eax, 40000000h
        mov cr0, eax
        wbinvd

        cacheout 0c0h, <[byte ptr CCR0_value]>
        cacheout 0c1h, <[byte ptr CCR1_value]>

        cacheout 0c4h, 00h
        cacheout 0c5h, 0ah
        cacheout 0c6h, 06h

        cacheout 0c7h, 00h
        cacheout 0c8h, 0ch
        cacheout 0c9h, 07h

        cacheout 0cah, 00h
        cacheout 0cbh, 00h
        cacheout 0cch, 00h

        cacheout 0cdh, 00h
        cacheout 0ceh, 00h
        cacheout 0cfh, 00h

        wbinvd
        mov eax, cr0
        and eax, 0bfffffffh
        mov cr0, eax
        sti

        print ok_msg

        ;MOV dx, OFFSET ok_msg
        ;mov ah, 09h
        ;int 21h
        ret

CCR0_value db 0
CCR1_value db 1

welcome db "TI486 configurator by El Dr. Gusman. Use /H for help.", CRLF, "$"

help_msg db CRLF, "CCR0 settings: ", CRLF,                            \
        " /M: Disable caching of 1MB boundaries (64KB)", CRLF,  \
        " /U: Disable caching of upper memory (640-1MB)", CRLF, \
        " /A: Enable A20M signal", CRLF,                        \
        " /K: Enable KEN signal", CRLF,                         \
        " /F: Enable FLUSH signal", CRLF,                       \
        " /B: Enable BARB (flush cache during hold)", CRLF,     \
        " /D: Set cache to direct mapping", CRLF,               \
        " /S: Enable suspend signals", CRLF, CRLF,              \
        "CCR1 settings: ", CRLF,                                \
        " /C: Enable caching of shadow BIOS area (C0000h)", CRLF, CRLF, \
        "Use /Q for quick settings (A20M + FLUSH + Shadow).", CRLF, "$"

nc0_msg         db "NC0 bit set (disable cache of 1MB boundaries).", CRLF, "$"
nc1_msg         db "NC1 bit set (disable cache of upper memory).", CRLF, "$"
a20m_msg        db "A20M bit set (enable A20M signal).", CRLF, "$"
ken_msg         db "KEN bit set (enable KEN signal).", CRLF, "$"
flush_msg       db "FLUSH bit set (enable FLUSH signal).", CRLF, "$"
barb_msg        db "BARB bit set (enable flush onhold).", CRLF, "$"
direct_msg      db "CO bit set (set cache mode to direct).", CRLF, "$"
sus_msg         db "SUS bit set (enable suspend signals).", CRLF, "$"
shadow_msg      db "Shadow area set as cacheable.", CRLF, "$"
default_msg     db "Set default configuration (A20M + FLUSH + Shadow).", CRLF, "$"

ok_msg db "TI486 cache configured.", CRLF, "$"

ENDS CODE
end start
