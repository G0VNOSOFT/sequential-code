; engine.inc — рантайм-библиотека для .seqc
; Предполагается, что ORG уже задан компилятором.

; ----------------------------------------------------------
; set_cursor: DH=row, DL=col  (BIOS int 10h, ah=02h)
; ----------------------------------------------------------
set_cursor:
    pusha
    mov ah, 0x02
    xor bh, bh          ; страница 0
    int 0x10
    popa
    ret

; ----------------------------------------------------------
; clear_screen: залить весь экран пробелами (int 10h, ah=06h)
; ----------------------------------------------------------
clear_screen:
    pusha
    mov ax, 0x0600      ; ah=06, al=0 (очистить всё окно)
    xor cx, cx          ; верх-лево = (0,0)
    mov dx, 0x184F      ; низ-право  = (24,79)
    mov bh, 0x07        ; атрибут: чёрный фон, серый текст
    int 0x10
    xor dx, dx
    call set_cursor
    popa
    ret

; ----------------------------------------------------------
; print_string: SI = zero-terminated
; ----------------------------------------------------------
print_string:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    xor bx, bx
    int 0x10
    jmp .loop
.done:
    popa
    ret

; ----------------------------------------------------------
; print_hex_word: AX = число, печатает 4 hex-цифры
; ----------------------------------------------------------
print_hex_word:
    pusha
    mov cx, 4
    mov bx, ax
.next:
    rol bx, 4
    mov ax, bx
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .ok
    add al, 7
.ok:
    mov ah, 0x0E
    int 0x10
    loop .next
    popa
    ret

; ----------------------------------------------------------
; ----------------------------------------------------------
; wait_ms: CX = миллисекунды (tick-based через BIOS 40:6C)
; ----------------------------------------------------------
wait_ms:
    pusha
    push es
    mov ax, cx
    xor dx, dx
    mov bx, 55
    div bx
    test dx, dx
    jz .r
    inc ax
.r:
    test ax, ax
    jnz .ok
    mov ax, 1
.ok:
    mov di, ax
    mov ax, 0x0040
    mov es, ax
    mov bx, [es:0x6C]
.l:
    mov ax, [es:0x6C]
    sub ax, bx
    cmp ax, di
    jb .l
    pop es
    popa
    ret
wait_seconds:
    pusha
    mov cx, 1000
    mul cx              ; DX:AX = sec * 1000
    mov cx, ax
    call wait_ms
    popa
    ret

; ----------------------------------------------------------
; read_key_blocking
; ----------------------------------------------------------
read_key_blocking:
    xor ah, ah
    int 0x16
    ret

; ----------------------------------------------------------
; key_pressed? → CF=1, AX=scancode/ascii если есть
; ----------------------------------------------------------
key_pressed:
    mov ah, 0x01
    int 0x16
    ret

; ----------------------------------------------------------
; reboot: тройной сбой — самый надёжный способ
; ----------------------------------------------------------
reboot:
    cli
    lidt [.null_idt]
    int 0x00
    jmp $
.null_idt:
    dw 0
    dd 0

; ----------------------------------------------------------
; shutdown: QEMU (ACPI PM1a), затем fallback на hlt
; ----------------------------------------------------------
shutdown:
    ; QEMU: out 0x604, 0x2000 (ACPI S5)
    mov ax, 0x2000
    mov dx, 0x604
    out dx, ax
    ; если не QEMU — попробуем ACPI через port 0xB004
    mov ax, 0x3400
    mov dx, 0xB004
    out dx, ax
    ; не вышло — остановимся
    cli
    hlt
    jmp $

; ----------------------------------------------------------
; Простой hex-дамп: SI=данные, CX=длина
; ----------------------------------------------------------
dump_hex:
    pusha
.loop:
    mov al, [si]
    xor ah, ah
    call print_hex_byte
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    inc si
    loop .loop
    popa
    ret
print_hex_byte:
    push ax
    shr al, 4
    call .nib
    pop ax
    and al, 0x0F
.nib:
    add al, '0'
    cmp al, '9'
    jbe .out
    add al, 7
.out:
    mov ah, 0x0E
    int 0x10
    ret
; ============================================================

; ============================================================
; Layer 1: print_char, print_newline, print_dec_word
; (print_hex_word уже определён выше)
; ============================================================

print_char:
    pusha
    mov ah, 0x0E
    xor bx, bx
    int 0x10
    popa
    ret

print_newline:
    pusha
    mov al, 13
    call print_char
    mov al, 10
    call print_char
    popa
    ret

print_dec_word:
    pusha
    test ax, ax
    jnz .start
    mov al, '0'
    mov ah, 0x0E
    int 0x10
    jmp .done
.start:
    xor cx, cx
    mov bx, 10
.dv:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .dv
.po:
    pop dx
    mov al, dl
    add al, '0'
    mov ah, 0x0E
    int 0x10
    loop .po
.done:
    popa
    ret

