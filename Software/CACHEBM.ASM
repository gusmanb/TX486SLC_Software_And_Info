; ============================================================
; CACHEBM.ASM - Cache Benchmark para TI486SLC
; ============================================================
; Muestra el efecto de la cache interna con barras visuales
; Usa lecturas de 32 bits (LODSD) para medir ancho de banda
; real de la cache interna (32 bits) vs bus externo (16 bits)
;
; Ensamblar:  TASM CACHEBM.ASM
;             TLINK /t CACHEBM.OBJ
; Ejecutar:   CACHEBM.COM
; ============================================================

        .MODEL TINY
        .386
        .CODE
        ORG 100h

; --- Constantes ---
NUM_SIZES   EQU 9
REPEATS     EQU 4               ; repeticiones por test (precision)
TOTAL_HI    EQU 001Ch           ; Total dwords = 0x1C0000 = 1835008
TOTAL_LO    EQU 0000h           ;   = ~7MB por pasada (1835008 * 4)
BAR_W       EQU 40              ; ancho maximo de barra
BUF_OFF     EQU 2000h           ; offset del buffer de lectura

; ============================================================
start:
        cld                             ; LODSD incrementa SI

        ; --- Titulo ---
        mov     dx, OFFSET msg_title
        mov     ah, 09h
        int     21h

        ; ============================================
        ; Fase 1: Ejecutar benchmarks para cada tamano
        ; ============================================
        xor     di, di                  ; DI = indice del test (0..8)

next_size:
        ; Obtener tamano del bloque en bytes
        mov     si, di
        shl     si, 1                   ; SI = DI * 2 (indice en words)
        mov     bx, sizes[si]           ; BX = tamano bloque

        ; dword_count = tamano / 4
        mov     ax, bx
        shr     ax, 2
        mov     dcount, ax

        ; iterations = TOTAL_DWORDS / dword_count
        mov     dx, TOTAL_HI
        mov     ax, TOTAL_LO
        div     dcount                  ; AX = iteraciones
        mov     iters, ax

        ; Indicador de progreso
        mov     dl, '.'
        mov     ah, 02h
        int     21h

        ; Acumulador de ticks para REPEATS pasadas
        mov     WORD PTR accum, 0
        mov     cl, REPEATS

rep_loop:
        push    cx

        ; Sincronizar al borde del tick del timer
        mov     ah, 00h
        int     1Ah                     ; DX = tick actual
        mov     bx, dx
sync_tick:
        mov     ah, 00h
        int     1Ah
        cmp     dx, bx
        je      sync_tick               ; esperar cambio de tick
        mov     tstart, dx              ; guardar tick inicial

        ; >>> BENCHMARK: leer bloque N veces (32 bits) <<<
        mov     bx, iters
bench_outer:
        mov     si, BUF_OFF             ; puntero al buffer
        mov     cx, dcount              ; dwords a leer
        rep     lodsd                   ; leer secuencialmente (32 bits)
        dec     bx
        jnz     bench_outer

        ; Leer tick final
        mov     ah, 00h
        int     1Ah
        sub     dx, tstart              ; DX = ticks transcurridos
        add     accum, dx               ; acumular

        pop     cx
        dec     cl
        jnz     rep_loop

        ; Guardar resultado (minimo 1 tick)
        mov     si, di
        shl     si, 1
        mov     ax, accum
        test    ax, ax
        jnz     store_ok
        inc     ax
store_ok:
        mov     results[si], ax

        ; Siguiente tamano
        inc     di
        cmp     di, NUM_SIZES
        jb      next_size

        ; ============================================
        ; Fase 2: Encontrar el minimo (mas rapido)
        ; ============================================
        mov     cx, NUM_SIZES
        xor     si, si
        mov     ax, 0FFFFh
find_min:
        cmp     results[si], ax
        jae     not_min
        mov     ax, results[si]
not_min:
        add     si, 2
        loop    find_min
        test    ax, ax                  ; asegurar minimo >= 1
        jnz     min_ready
        inc     ax
min_ready:
        mov     min_t, ax

        ; ============================================
        ; Fase 3: Mostrar resultados con barras
        ; ============================================
        mov     dx, OFFSET msg_hdr
        mov     ah, 09h
        int     21h

        xor     di, di                  ; indice del test

show_loop:
        ; Imprimir etiqueta de tamano (7 bytes por entrada)
        mov     ax, di
        mov     bl, 7
        mul     bl                      ; AX = DI * 7
        add     ax, OFFSET labels
        mov     dx, ax
        mov     ah, 09h
        int     21h

        ; Separador vertical izquierdo
        mov     dl, 0B3h                ; caracter |
        mov     ah, 02h
        int     21h

        ; Calcular longitud de barra = BAR_W * min_t / resultado
        mov     si, di
        shl     si, 1
        mov     ax, BAR_W
        mul     min_t                   ; DX:AX = BAR_W * min_t
        div     WORD PTR results[si]    ; AX = longitud barra
        mov     cx, ax                  ; CX = chars llenos

        ; Imprimir parte llena (bloque solido)
        push    cx
        jcxz    skip_fill
do_fill:
        mov     dl, 0DBh                ; caracter solido
        mov     ah, 02h
        int     21h
        loop    do_fill
skip_fill:

        ; Imprimir parte vacia (sombra)
        pop     ax
        mov     cx, BAR_W
        sub     cx, ax
        jcxz    skip_empty
do_empty:
        mov     dl, 0B0h                ; caracter sombra
        mov     ah, 02h
        int     21h
        loop    do_empty
skip_empty:

        ; Separador vertical derecho
        mov     dl, 0B3h
        mov     ah, 02h
        int     21h

        ; Imprimir ticks (justificado derecha, 4 chars)
        mov     si, di
        shl     si, 1
        mov     ax, results[si]
        call    print_num4

        ; Nueva linea
        mov     dx, OFFSET str_crlf
        mov     ah, 09h
        int     21h

        ; Siguiente
        inc     di
        cmp     di, NUM_SIZES
        jb      show_loop

        ; --- Pie ---
        mov     dx, OFFSET msg_foot
        mov     ah, 09h
        int     21h

        ; --- Salir ---
        mov     ax, 4C00h
        int     21h

; ============================================================
; print_num4 - Imprime AX en decimal, justificado derecha en 4 chars
; ============================================================
print_num4 PROC NEAR
        push    bx
        push    cx
        push    dx

        mov     bx, 10
        xor     cx, cx                  ; contador de digitos

pn_divide:
        xor     dx, dx
        div     bx                      ; AX = cociente, DX = resto
        push    dx                      ; apilar digito
        inc     cx
        test    ax, ax
        jnz     pn_divide

        ; Espacios iniciales para justificar
        mov     ax, 4
        sub     ax, cx
        jle     pn_print                ; no necesita espacios
        push    cx
        mov     cx, ax
pn_space:
        mov     dl, ' '
        mov     ah, 02h
        int     21h
        loop    pn_space
        pop     cx

pn_print:
        pop     dx                      ; recuperar digito
        add     dl, '0'
        mov     ah, 02h
        int     21h
        loop    pn_print

        pop     dx
        pop     cx
        pop     bx
        ret
print_num4 ENDP

; ============================================================
; Datos
; ============================================================

; Tamanos de bloque a testear (bytes)
sizes   DW      128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768

; Etiquetas (6 chars + $ = 7 bytes cada una)
labels  DB      '  128B$'
        DB      '  256B$'
        DB      '  512B$'
        DB      '   1KB$'
        DB      '   2KB$'
        DB      '   4KB$'
        DB      '   8KB$'
        DB      '  16KB$'
        DB      '  32KB$'

; --- Mensajes ---
msg_title:
        DB      13,10
        DB      ' Cache Benchmark v1.1 - TI486SLC',13,10
        DB      ' ================================',13,10,13,10
        DB      ' Midiendo velocidad de lectura (32 bits)',13,10,'$'

msg_hdr:
        DB      13,10,13,10
        DB      ' Size ',0B3h
        DB      '         mas largo = mas rapido         ',0B3h
        DB      '   T',13,10,' '
        DB      5 DUP(0C4h)
        DB      0C5h
        DB      40 DUP(0C4h)
        DB      0C5h
        DB      4 DUP(0C4h)
        DB      13,10,'$'

str_crlf:
        DB      13,10,'$'

msg_foot:
        DB      ' '
        DB      5 DUP(0C4h)
        DB      0C1h
        DB      40 DUP(0C4h)
        DB      0C1h
        DB      4 DUP(0C4h)
        DB      13,10,13,10
        DB      ' T = ticks del timer (menor = mas rapido)',13,10
        DB      ' El salto marca el limite de la cache interna',13,10
        DB      '$'

; --- Variables ---
dcount  DW      0                       ; dwords por pasada interna
iters   DW      0                       ; iteraciones externas
tstart  DW      0                       ; tick inicial
accum   DW      0                       ; acumulador de ticks
min_t   DW      0                       ; ticks minimos (mas rapido)
results DW      NUM_SIZES DUP(0)        ; resultados por tamano

        END     start
