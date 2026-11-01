; ============================================================
; .seqc IDE v0.1 - MBR program editor & compiler
; License: 2019-<current> G0VNOSOFTWARE
; ============================================================
format PE console
entry start
include 'win32a.inc'

STD_INPUT_HANDLE  = -10
STD_OUTPUT_HANDLE = -11

GENERIC_READ    = 0x80000000
GENERIC_WRITE   = 0x40000000
FILE_SHARE_READ = 1
OPEN_EXISTING   = 3
CREATE_ALWAYS   = 2
INVALID_HANDLE_VALUE = -1

VK_F1     = 0x70
VK_F2     = 0x71
VK_F3     = 0x72
VK_F4     = 0x73
VK_F10    = 0x79
VK_ESC    = 0x1B
VK_BACK   = 0x08
VK_RETURN = 0x0D
VK_UP     = 0x26
VK_DOWN   = 0x28
VK_LEFT   = 0x25
VK_RIGHT  = 0x27
VK_DELETE = 0x2E
VK_HOME   = 0x24
VK_END    = 0x23

struc COORD
{
    .X dw ?
    .Y dw ?
}
struc SMALL_RECT
{
    .Left   dw ?
    .Top    dw ?
    .Right  dw ?
    .Bottom dw ?
}
struc CONSOLE_SCREEN_BUFFER_INFO
{
    .dwSize              COORD
    .dwCursorPosition    COORD
    .wAttributes         dw ?
    .srWindow            SMALL_RECT
    .dwMaximumWindowSize COORD
}
struc KEY_EVENT_RECORD
{
    .bKeyDown          dd ?
    .wRepeatCount      dw ?
    .wVirtualKeyCode   dw ?
    .wVirtualScanCode  dw ?
    .uChar             dw ?
    .dwControlKeyState dd ?
}
struc INPUT_RECORD
{
    .EventType dw ?
    ._pad      dw ?
    .KeyEvent  KEY_EVENT_RECORD
}
struc STARTUPINFOA
{
    .cb              dd ?
    .lpReserved      dd ?
    .lpDesktop       dd ?
    .lpTitle         dd ?
    .dwX             dd ?
    .dwY             dd ?
    .dwXSize         dd ?
    .dwYSize         dd ?
    .dwXCountChars   dd ?
    .dwYCountChars   dd ?
    .dwFillAttribute dd ?
    .dwFlags         dd ?
    .wShowWindow     dw ?
    .cbReserved2     dw ?
    .lpReserved2     dd ?
    .hStdInput       dd ?
    .hStdOutput      dd ?
    .hStdError       dd ?
}
struc PROCESS_INFORMATION
{
    .hProcess    dd ?
    .hThread     dd ?
    .dwProcessId dd ?
    .dwThreadId  dd ?
}
struc SYSTEMTIME
{
    .wYear         dw ?
    .wMonth        dw ?
    .wDayOfWeek    dw ?
    .wDay          dw ?
    .wHour         dw ?
    .wMinute       dw ?
    .wSecond       dw ?
    .wMilliseconds dw ?
}

section '.data' data readable writeable
    hIn       dd ?
    hOut      dd ?
    hFile     dd ?
    got       dd ?

    buf_len   dd 0
    cur       dd 0
    code_sz   dd 0
    free_b    dd 0
    status    db 0

    key_code  dd 0
    key_ascii dd 0

    csbi      CONSOLE_SCREEN_BUFFER_INFO
    rec       INPUT_RECORD
    procinfo  PROCESS_INFORMATION
    startinfo STARTUPINFOA
    systime   SYSTEMTIME

    fname_default db 'program.seqc',0
    path_asm      db 'build\out.asm',0
    path_bin      db 'build\out.bin',0
    dir_build     db 'build',0
    cmd_fasm      db 'fasm.exe build\out.asm build\out.bin',0
    cmd_qemu      db 'qemu-system-i386.exe -drive format=raw,file=build\out.bin',0

    t_title      db ' .seqc IDE v0.1',0
    t_title_len = $ - t_title
    t_hot        db 'F1 Help  F2 Save  F3 Compile  F4 Build+Run  ESC Menu  F10 Quit  ',0
    t_hot_len = $ - t_hot
    t_menu_title db '=== .seqc IDE v0.1 ===',0
    t_menu_title_len = $ - t_menu_title
    t_lic1       db 'License: 2019-',0
    t_lic1_len = $ - t_lic1
    t_lic2       db ' G0VNOSOFTWARE',0
    t_lic2_len = $ - t_lic2
    t_menu_1     db '[N] New file',0
    t_menu_1_len = $ - t_menu_1
    t_menu_2     db '[O] Open existing',0
    t_menu_2_len = $ - t_menu_2
    t_menu_3     db '[Q] Quit',0
    t_menu_3_len = $ - t_menu_3
    t_menu_hint  db 'Press N, O or Q...',0
    t_menu_hint_len = $ - t_menu_hint
    t_ask_name   db 'File name (empty = program.seqc): ',0
    t_ask_name_len = $ - t_ask_name
    t_help_1     db '--- HELP ---',0
    t_help_1_len = $ - t_help_1
    t_help_2     db 'Arrows   : move cursor',0
    t_help_2_len = $ - t_help_2
    t_help_3     db 'Enter    : new line',0
    t_help_3_len = $ - t_help_3
    t_help_4     db 'BkSpc/Del: delete chars',0
    t_help_4_len = $ - t_help_4
    t_help_5     db 'F2 Save  F3 Compile  F4 Run in QEMU',0
    t_help_5_len = $ - t_help_5
    t_help_6     db 'ESC returns to main menu.  Press any key...',0
    t_help_6_len = $ - t_help_6
    t_size_lbl   db ' size:',0
    t_size_lbl_len = $ - t_size_lbl
    t_free_lbl   db ' free:',0
    t_free_lbl_len = $ - t_free_lbl
    t_ok_lbl     db ' OK',0
    t_ok_lbl_len = $ - t_ok_lbl
    t_err_lbl    db ' ERROR',0
    t_err_lbl_len = $ - t_err_lbl

    space_char db ' '
    char_buf   db 0,0

    str_prologue db 'format binary',13,10
                 db 'org 0x7C00',13,10
                 db 'start:',13,10
                 db '    cli',13,10
                 db '    xor ax, ax',13,10
                 db '    mov ds, ax',13,10
                 db '    mov es, ax',13,10
                 db '    mov ss, ax',13,10
                 db '    mov sp, 0x7C00',13,10
                 db '    sti',13,10
    str_prologue_len = $ - str_prologue

    str_epilogue db 13,10,'    jmp $',13,10
                 db 'include ''..\engine.inc''',13,10
                 db 'times 510-($-$$) db 0',13,10
                 db 'dw 0xAA55',13,10
    str_epilogue_len = $ - str_epilogue

    line_start   dd 0
    line_len     dd 0
    msg_count    dd 0
    str_off      dd 0

    s_cls        db '    call clear_screen',13,10
    s_cls_len = $ - s_cls
    s_print      db '    call print_string',13,10
    s_print_len = $ - s_print
    s_setsi      db '    mov si, msg_'
    s_setsi_len = $ - s_setsi
    s_waitms1    db '    mov cx, '
    s_waitms1_len = $ - s_waitms1
    s_waitms2    db 13,10,'    call wait_ms',13,10
    s_waitms2_len = $ - s_waitms2
    s_waits1     db '    mov ax, '
    s_waits1_len = $ - s_waits1
    s_waits2     db 13,10,'    call wait_seconds',13,10
    s_waits2_len = $ - s_waits2
    s_reboot     db '    jmp reboot',13,10
    s_reboot_len = $ - s_reboot
    s_shutdown   db '    jmp shutdown',13,10
    s_shutdown_len = $ - s_shutdown
    s_readkey    db '    call read_key_blocking',13,10
    s_readkey_len = $ - s_readkey
    s_line_pos1    db '    mov dh, '
    s_line_pos1_len = $ - s_line_pos1
    s_line_pos2    db 13,10,'    xor dl, dl',13,10,'    call set_cursor',13,10
    s_line_pos2_len = $ - s_line_pos2

    s_mov_ax     db '    mov ax, '
    s_mov_ax_len = $ - s_mov_ax
    s_mov_al     db '    mov al, '
    s_mov_al_len = $ - s_mov_al
    s_mov_dh     db '    mov dh, '
    s_mov_dh_len = $ - s_mov_dh
    s_mov_dl     db 13,10,'    mov dl, '
    s_mov_dl_len = $ - s_mov_dl
    s_call_hex   db 13,10,'    call print_hex_word',13,10
    s_call_hex_len = $ - s_call_hex
    s_call_dec   db 13,10,'    call print_dec_word',13,10
    s_call_dec_len = $ - s_call_dec
    s_call_char  db 13,10,'    call print_char',13,10
    s_call_char_len = $ - s_call_char
    s_call_setcur db 13,10,'    call set_cursor',13,10
    s_call_setcur_len = $ - s_call_setcur
    s_call_nl    db '    call print_newline',13,10
    s_call_nl_len = $ - s_call_nl
    s_jmp        db '    jmp '
    s_jmp_len = $ - s_jmp
    s_read_jmp   db '    jmp skip_rd_'
    s_read_jmp_len = $ - s_read_jmp
    s_read_lbl   db 13,10,'RD_'
    s_read_lbl_len = $ - s_read_lbl
    s_file_prefix db '    file ''..', 92
    s_file_prefix_len = $ - s_file_prefix
    s_mov_cx     db '    mov cx, '
    s_mov_cx_len = $ - s_mov_cx
    s_call_dump  db 13,10,'    call dump_hex',13,10
    s_call_dump_len = $ - s_call_dump
    s_exec_jmp   db '    jmp L_'
    s_exec_jmp_len = $ - s_exec_jmp
    s_exec_jmp_rd db '    jmp '
    s_exec_jmp_rd_len = $ - s_exec_jmp_rd
    s_if_head    db '    mov ah, 0x01',13,10,'    int 0x16',13,10,'    jz .nokey_'
    s_if_head_len = $ - s_if_head
    s_if_cmp     db 13,10,'    cmp ah, '
    s_if_cmp_len = $ - s_if_cmp
    s_if_jne     db 13,10,'    jne .nokey_'
    s_if_jne_len = $ - s_if_jne
    s_if_consume db 13,10,'    xor ah, ah',13,10,'    int 0x16',13,10,'    jmp L_'
    s_if_consume_len = $ - s_if_consume
    s_nokey_dot  db 13,10,'.nokey_'
    s_nokey_dot_len = $ - s_nokey_dot
    s_colon_crlf db ':',13,10
    s_colon_crlf_len = $ - s_colon_crlf

section '.bss' data readable writeable
    buf        rb 65536
    fname      rb 260
    input_buf  rb 260
    line_len2  dd 0
    asm_buf    rb 65536
    asm_len    dd 0
    str_pool   rb 16384
    tmp_pos_row dd 0
    tmp_pos_col dd 0
    if_key_count dd 0
    read_count dd 0

section '.text' code readable executable

start:
    invoke GetStdHandle, STD_INPUT_HANDLE
    mov [hIn], eax
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov [hOut], eax
    mov [startinfo.cb], 68
    invoke GetLocalTime, systime

.menu:
    call show_menu
    call wait_key
    mov eax, [key_code]
    cmp eax, 'N'
    je .new
    cmp eax, 'n'
    je .new
    cmp eax, 'O'
    je .open
    cmp eax, 'o'
    je .open
    cmp eax, 'Q'
    je .quit
    cmp eax, 'q'
    je .quit
    jmp .menu

.new:
    call do_new_file
    cmp eax, 1
    jne .menu
    jmp .editor

.open:
    invoke CreateFileA, fname_default, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0
    cmp eax, INVALID_HANDLE_VALUE
    je .menu
    mov [hFile], eax
    invoke ReadFile, [hFile], buf, 65535, buf_len, 0
    invoke CloseHandle, [hFile]
    mov eax, [buf_len]
    mov byte [buf + eax], 0
    mov [cur], dword 0
    jmp .editor

.editor:
    call render
    call wait_key
    mov eax, [key_code]
    cmp eax, VK_F10
    je .quit
    cmp eax, VK_ESC
    je .menu
    cmp eax, VK_F1
    je .ed_help
    cmp eax, VK_F2
    je .ed_save
    cmp eax, VK_F3
    je .ed_compile
    cmp eax, VK_F4
    je .ed_run
    call handle_editor_key
    jmp .editor
.ed_help:
    call show_help
    jmp .editor
.ed_save:
    call save_file
    mov [status], byte 1
    jmp .editor
.ed_compile:
    call compile_seqc
    jmp .editor
.ed_run:
    call compile_seqc
    call run_qemu
    jmp .editor
.quit:
    invoke ExitProcess, 0

show_menu:
    pusha
    call clear_screen
    mov dh, 2
    mov dl, 28
    call goto_xy
    invoke WriteConsoleA, [hOut], t_menu_title, t_menu_title_len, got, 0
    mov dh, 4
    mov dl, 22
    call goto_xy
    invoke WriteConsoleA, [hOut], t_lic1, t_lic1_len, got, 0
    movzx eax, [systime.wYear]
    call write_dec
    invoke WriteConsoleA, [hOut], t_lic2, t_lic2_len, got, 0
    mov dh, 8
    mov dl, 30
    call goto_xy
    invoke WriteConsoleA, [hOut], t_menu_1, t_menu_1_len, got, 0
    mov dh, 9
    mov dl, 30
    call goto_xy
    invoke WriteConsoleA, [hOut], t_menu_2, t_menu_2_len, got, 0
    mov dh, 10
    mov dl, 30
    call goto_xy
    invoke WriteConsoleA, [hOut], t_menu_3, t_menu_3_len, got, 0
    mov dh, 14
    mov dl, 28
    call goto_xy
    invoke WriteConsoleA, [hOut], t_menu_hint, t_menu_hint_len, got, 0
    popa
    ret

do_new_file:
    pusha
    call clear_screen
    mov dh, 2
    mov dl, 3
    call goto_xy
    invoke WriteConsoleA, [hOut], t_ask_name, t_ask_name_len, got, 0
    call read_line
    mov [line_len2], eax
    test eax, eax
    jnz .has_name
    mov esi, fname_default
    jmp .copy
.has_name:
    mov esi, input_buf
.copy:
    mov edi, fname
.cp:
    lodsb
    stosb
    test al, al
    jnz .cp
    invoke CreateFileA, fname, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, 0, 0
    cmp eax, INVALID_HANDLE_VALUE
    je .fail
    mov [hFile], eax
    invoke CloseHandle, [hFile]
    mov [buf_len], dword 0
    mov [cur], dword 0
    mov [status], byte 0
    popa
    mov eax, 1
    ret
.fail:
    popa
    xor eax, eax
    ret

read_line:
    pushad
    xor ebx, ebx
.rd:
    invoke ReadConsoleInputA, [hIn], rec, 1, got
    cmp [rec.EventType], 1
    jne .rd
    cmp [rec.KeyEvent.bKeyDown], 0
    je .rd
    movzx eax, [rec.KeyEvent.wVirtualKeyCode]
    cmp eax, VK_RETURN
    je .done
    cmp eax, VK_BACK
    je .bs
    movzx eax, [rec.KeyEvent.uChar]
    test eax, eax
    jz .rd
    cmp ebx, 250
    jae .rd
    mov [input_buf + ebx], al
    inc ebx
    mov [char_buf], al
    invoke WriteConsoleA, [hOut], char_buf, 1, got, 0
    jmp .rd
.bs:
    test ebx, ebx
    jz .rd
    dec ebx
    mov dh, 2
    mov dl, 3
    add dl, t_ask_name_len
    add dl, bl
    call goto_xy
    invoke WriteConsoleA, [hOut], space_char, 1, got, 0
    mov dh, 2
    mov dl, 3
    add dl, t_ask_name_len
    add dl, bl
    call goto_xy
    jmp .rd
.done:
    mov byte [input_buf + ebx], 0
    mov [line_len2], ebx
    popad
    mov eax, [line_len2]
    ret

show_help:
    pusha
    call clear_screen
    mov dh, 3
    mov dl, 5
    call goto_xy
    invoke WriteConsoleA, [hOut], t_help_1, t_help_1_len, got, 0
    mov dh, 5
    mov dl, 5
    call goto_xy
    invoke WriteConsoleA, [hOut], t_help_2, t_help_2_len, got, 0
    mov dh, 6
    mov dl, 5
    call goto_xy
    invoke WriteConsoleA, [hOut], t_help_3, t_help_3_len, got, 0
    mov dh, 7
    mov dl, 5
    call goto_xy
    invoke WriteConsoleA, [hOut], t_help_4, t_help_4_len, got, 0
    mov dh, 9
    mov dl, 5
    call goto_xy
    invoke WriteConsoleA, [hOut], t_help_5, t_help_5_len, got, 0
    mov dh, 11
    mov dl, 5
    call goto_xy
    invoke WriteConsoleA, [hOut], t_help_6, t_help_6_len, got, 0
    call wait_key
    popa
    ret

render:
    pusha
    call clear_screen
    mov dh, 0
    xor dl, dl
    call goto_xy
    invoke SetConsoleTextAttribute, [hOut], 0x70
    invoke WriteConsoleA, [hOut], t_title, t_title_len, got, 0
    mov ecx, 80
    sub ecx, t_title_len
    call pad_spaces
    invoke SetConsoleTextAttribute, [hOut], 0x07
    call render_text
    mov dh, 22
    xor dl, dl
    call goto_xy
    invoke SetConsoleTextAttribute, [hOut], 0x17
    call render_status
    mov ecx, 80
    call pad_spaces
    invoke SetConsoleTextAttribute, [hOut], 0x07
    mov dh, 23
    xor dl, dl
    call goto_xy
    invoke SetConsoleTextAttribute, [hOut], 0x70
    invoke WriteConsoleA, [hOut], t_hot, t_hot_len, got, 0
    mov ecx, 80
    sub ecx, t_hot_len
    call pad_spaces
    invoke SetConsoleTextAttribute, [hOut], 0x07
    call place_cursor
    popa
    ret

render_text:
    pushad
    mov dh, 1
    xor dl, dl
    call goto_xy
    mov ecx, [buf_len]
    test ecx, ecx
    jz .done
    cmp ecx, 1680
    jbe .ok
    mov ecx, 1680
.ok:
    invoke WriteConsoleA, [hOut], buf, ecx, got, 0
.done:
    popad
    ret

render_status:
    pushad
    mov esi, fname
    xor ecx, ecx
.flen:
    cmp byte [esi + ecx], 0
    je .flen_done
    inc ecx
    cmp ecx, 200
    jb .flen
.flen_done:
    test ecx, ecx
    jz .skipname
    invoke WriteConsoleA, [hOut], fname, ecx, got, 0
.skipname:
    invoke WriteConsoleA, [hOut], t_size_lbl, t_size_lbl_len, got, 0
    mov eax, [code_sz]
    call write_dec
    invoke WriteConsoleA, [hOut], t_free_lbl, t_free_lbl_len, got, 0
    mov eax, [free_b]
    call write_dec
    cmp [status], byte 1
    je .ok
    cmp [status], byte 2
    je .err
    jmp .done
.ok:
    invoke WriteConsoleA, [hOut], t_ok_lbl, t_ok_lbl_len, got, 0
    jmp .done
.err:
    invoke WriteConsoleA, [hOut], t_err_lbl, t_err_lbl_len, got, 0
.done:
    popad
    ret

wait_key:
    pusha
.w:
    invoke ReadConsoleInputA, [hIn], rec, 1, got
    cmp [rec.EventType], 1
    jne .w
    cmp [rec.KeyEvent.bKeyDown], 0
    je .w
    movzx eax, [rec.KeyEvent.wVirtualKeyCode]
    mov [key_code], eax
    movzx eax, [rec.KeyEvent.uChar]
    mov [key_ascii], eax
    popa
    ret

handle_editor_key:
    pusha
    mov eax, [key_code]
    cmp eax, VK_BACK
    je .back
    cmp eax, VK_DELETE
    je .del
    cmp eax, VK_RETURN
    je .enter
    cmp eax, VK_LEFT
    je .left
    cmp eax, VK_RIGHT
    je .right
    cmp eax, VK_UP
    je .up
    cmp eax, VK_DOWN
    je .down
    cmp eax, VK_HOME
    je .home
    cmp eax, VK_END
    je .end
    mov eax, [key_ascii]
    test eax, eax
    jz .done
    call insert_char_at
    jmp .done
.back:
    cmp [cur], dword 0
    je .done
    dec [cur]
    call delete_char_at
    jmp .done
.del:
    mov eax, [buf_len]
    cmp [cur], eax
    jae .done
    call delete_char_at
    jmp .done
.enter:
    mov al, 13
    call insert_char_at
    mov al, 10
    call insert_char_at
    jmp .done
.left:
    cmp [cur], dword 0
    je .done
    dec [cur]
    jmp .done
.right:
    mov eax, [buf_len]
    cmp [cur], eax
    jae .done
    inc [cur]
    jmp .done
.up:
    call cur_up
    jmp .done
.down:
    call cur_down
    jmp .done
.home:
    call cur_home
    jmp .done
.end:
    call cur_end
.done:
    popa
    ret

insert_char_at:
    pushad
    movzx eax, al
    mov ebx, [cur]
    mov ecx, [buf_len]
    cmp ecx, 65000
    jae .done
    std
    lea esi, [buf + ecx - 1]
    lea edi, [buf + ecx]
    sub ecx, ebx
    test ecx, ecx
    jz .no_shift
    rep movsb
.no_shift:
    cld
    mov [buf + ebx], al
    inc dword [buf_len]
    inc dword [cur]
.done:
    popad
    ret

delete_char_at:
    pushad
    mov ebx, [cur]
    mov ecx, [buf_len]
    cmp ebx, ecx
    jae .done
    lea esi, [buf + ebx + 1]
    lea edi, [buf + ebx]
    sub ecx, ebx
    dec ecx
    test ecx, ecx
    jz .no
    cld
    rep movsb
.no:
    dec dword [buf_len]
.done:
    popad
    ret

cur_up:
    pushad
    mov eax, [cur]
    mov ebx, eax
.sb:
    test ebx, ebx
    jz .done
    dec ebx
    cmp byte [buf + ebx], 10
    je .found
    jmp .sb
.found:
    mov edx, eax
    sub edx, ebx
    dec edx
    test ebx, ebx
    jz .done
    dec ebx
.pb:
    test ebx, ebx
    jz .prev0
    dec ebx
    cmp byte [buf + ebx], 10
    je .prev1
    jmp .pb
.prev0:
    mov ebx, 0
    jmp .setc
.prev1:
    inc ebx
.setc:
    mov ecx, ebx
.eol:
    cmp ecx, [buf_len]
    jae .set
    cmp byte [buf + ecx], 10
    je .set
    inc ecx
    jmp .eol
.set:
    mov eax, ecx
    sub eax, ebx
    cmp edx, eax
    jbe .ok
    mov edx, eax
.ok:
    add ebx, edx
    mov [cur], ebx
.done:
    popad
    ret

cur_down:
    pushad
    mov eax, [cur]
    mov ebx, eax
.sb:
    cmp ebx, [buf_len]
    jae .done
    cmp byte [buf + ebx], 10
    je .fe
    inc ebx
    jmp .sb
.fe:
    mov ecx, eax
.cs:
    test ecx, ecx
    jz .c0
    dec ecx
    cmp byte [buf + ecx], 10
    je .c1
    jmp .cs
.c0:
    mov ecx, 0
    jmp .col
.c1:
    inc ecx
.col:
    mov edx, eax
    sub edx, ecx
    inc ebx
    cmp ebx, [buf_len]
    jae .done
    mov ecx, ebx
.neol:
    cmp ecx, [buf_len]
    jae .set
    cmp byte [buf + ecx], 10
    je .set
    inc ecx
    jmp .neol
.set:
    mov eax, ecx
    sub eax, ebx
    cmp edx, eax
    jbe .ok
    mov edx, eax
.ok:
    add ebx, edx
    mov [cur], ebx
.done:
    popad
    ret

cur_home:
    pushad
    mov eax, [cur]
.sb:
    test eax, eax
    jz .set0
    dec eax
    cmp byte [buf + eax], 10
    je .found
    jmp .sb
.found:
    inc eax
    jmp .set
.set0:
    mov eax, 0
.set:
    mov [cur], eax
    popad
    ret

cur_end:
    pushad
    mov eax, [cur]
.ef:
    cmp eax, [buf_len]
    jae .done
    cmp byte [buf + eax], 10
    je .done
    inc eax
    jmp .ef
.done:
    mov [cur], eax
    popad
    ret

save_file:
    invoke CreateFileA, fname, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, 0, 0
    cmp eax, INVALID_HANDLE_VALUE
    je .fail
    mov [hFile], eax
    invoke WriteFile, [hFile], buf, [buf_len], got, 0
    invoke CloseHandle, [hFile]
.fail:
    ret

compile_seqc:
    pusha
    mov [status], byte 0
    mov [asm_len], dword 0
    mov [msg_count], dword 0
    mov [str_off], dword 0
    mov [if_key_count], dword 0
    mov [read_count], dword 0
    invoke CreateDirectoryA, dir_build, 0
    mov esi, str_prologue
    mov ecx, str_prologue_len
    call emit_bytes
    call emit_body
    mov esi, str_epilogue
    mov ecx, str_epilogue_len
    call emit_bytes
    invoke CreateFileA, path_asm, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, 0, 0
    cmp eax, INVALID_HANDLE_VALUE
    je .fail
    mov [hFile], eax
    invoke WriteFile, [hFile], asm_buf, [asm_len], got, 0
    invoke CloseHandle, [hFile]
    invoke CreateProcessA, 0, cmd_fasm, 0, 0, 0, 0, 0, 0, startinfo, procinfo
    test eax, eax
    jz .fail
    invoke WaitForSingleObject, [procinfo.hProcess], -1
    invoke CloseHandle, [procinfo.hProcess]
    invoke CloseHandle, [procinfo.hThread]
    call check_bin_size
    cmp [code_sz], dword 0
    je .fail
    mov [status], byte 1
    popa
    ret
.fail:
    mov [status], byte 2
    popa
    ret

emit_bytes:
    pushad
    mov edi, asm_buf
    add edi, [asm_len]
    add [asm_len], ecx
    cld
    rep movsb
    popad
    ret

emit_dec:
    pushad
    mov ebx, 10
    xor ecx, ecx
.dv:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .dv
.po:
    pop eax
    add al, '0'
    mov edi, asm_buf
    add edi, [asm_len]
    stosb
    inc dword [asm_len]
    loop .po
    popad
    ret

emit_raw_byte:
    pushad
    movzx eax, al
    mov edi, asm_buf
    add edi, [asm_len]
    stosb
    inc dword [asm_len]
    popad
    ret

emit_bytes_raw:
    ; ESI=src, ECX=len; копирует в asm_buf (без сохранения регистров)
    push edi
    mov edi, asm_buf
    add edi, [asm_len]
    add [asm_len], ecx
    cld
    rep movsb
    pop edi
    ret

emit_crlf:
    pushad
    mov edi, [asm_len]
    mov byte [asm_buf + edi], 13
    inc edi
    mov byte [asm_buf + edi], 10
    inc edi
    mov [asm_len], edi
    popad
    ret

emit_body:
    pushad
    mov esi, buf
    mov edi, [buf_len]
.line_loop:
    test edi, edi
    jz .done
    xor ecx, ecx
.eol:
    cmp ecx, edi
    jae .got_eol
    mov al, [esi + ecx]
    cmp al, 13
    je .got_eol
    cmp al, 10
    je .got_eol
    inc ecx
    jmp .eol
.got_eol:
    mov [line_start], esi
    mov [line_len], ecx
    call process_line
    mov esi, [line_start]
    add esi, [line_len]
    mov ecx, [line_len]
    sub edi, ecx
    test edi, edi
    jz .done
    cmp byte [esi], 13
    jne .skip_lf
    inc esi
    dec edi
    jz .done
.skip_lf:
    cmp byte [esi], 10
    jne .line_loop
    inc esi
    dec edi
    jmp .line_loop
.done:
    popad
    ret

process_line:
    pushad
    mov esi, [line_start]
    mov ecx, [line_len]
    xor ebx, ebx
.sw:
    cmp ebx, ecx
    jae .done
    mov al, [esi + ebx]
    cmp al, ' '
    je .swi
    cmp al, 9
    jne .check
.swi:
    inc ebx
    jmp .sw
.check:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    test ecx, ecx
    jz .done
    ; CLS
    cmp ecx, 3
    jb .try_newline
    cmp byte [esi], 'C'
    jne .try_newline
    cmp byte [esi+1], 'L'
    jne .try_newline
    cmp byte [esi+2], 'S'
    jne .try_newline
    mov esi, s_cls
    mov ecx, s_cls_len
    call emit_bytes
    jmp .done
.try_newline:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 7
    jb .try_pos
    cmp byte [esi], 'N'
    jne .try_pos
    cmp byte [esi+1], 'E'
    jne .try_pos
    cmp byte [esi+2], 'W'
    jne .try_pos
    cmp byte [esi+3], 'L'
    jne .try_pos
    cmp byte [esi+4], 'I'
    jne .try_pos
    cmp byte [esi+5], 'N'
    jne .try_pos
    cmp byte [esi+6], 'E'
    jne .try_pos
    mov esi, s_call_nl
    mov ecx, s_call_nl_len
    call emit_bytes
    jmp .done

.try_pos:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 4
    jb .try_out_hex
    cmp byte [esi], 'P'
    jne .try_out_hex
    cmp byte [esi+1], 'O'
    jne .try_out_hex
    cmp byte [esi+2], 'S'
    jne .try_out_hex
    cmp byte [esi+3], '('
    jne .try_out_hex
    add esi, 4
    sub ecx, 4
    xor eax, eax
.pos_row_loop:
    test ecx, ecx
    jz .done
    mov dl, [esi]
    cmp dl, '0'
    jb .pos_row_done
    cmp dl, '9'
    ja .pos_row_done
    imul eax, eax, 10
    sub dl, '0'
    movzx edx, dl
    add eax, edx
    inc esi
    dec ecx
    jmp .pos_row_loop
.pos_row_done:
    mov [tmp_pos_row], eax
    test ecx, ecx
    jz .done
    cmp byte [esi], ','
    jne .done
    inc esi
    dec ecx
.pos_skip_sp:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .pos_col_init
    inc esi
    dec ecx
    jmp .pos_skip_sp
.pos_col_init:
    xor eax, eax
.pos_col_loop:
    test ecx, ecx
    jz .pos_col_done
    mov dl, [esi]
    cmp dl, '0'
    jb .pos_col_done
    cmp dl, '9'
    ja .pos_col_done
    imul eax, eax, 10
    sub dl, '0'
    movzx edx, dl
    add eax, edx
    inc esi
    dec ecx
    jmp .pos_col_loop
.pos_col_done:
    mov [tmp_pos_col], eax
    mov esi, s_mov_dh
    mov ecx, s_mov_dh_len
    call emit_bytes
    mov eax, [tmp_pos_row]
    call emit_dec
    mov esi, s_mov_dl
    mov ecx, s_mov_dl_len
    call emit_bytes
    mov eax, [tmp_pos_col]
    call emit_dec
    mov esi, s_call_setcur
    mov ecx, s_call_setcur_len
    call emit_bytes
    jmp .done

.try_out_hex:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 8
    jb .try_out_dec
    cmp byte [esi], 'O'
    jne .try_out_dec
    cmp byte [esi+1], 'U'
    jne .try_out_dec
    cmp byte [esi+2], 'T'
    jne .try_out_dec
    cmp byte [esi+3], '_'
    jne .try_out_dec
    cmp byte [esi+4], 'H'
    jne .try_out_dec
    cmp byte [esi+5], 'E'
    jne .try_out_dec
    cmp byte [esi+6], 'X'
    jne .try_out_dec
    cmp byte [esi+7], ' '
    jne .try_out_dec
    mov esi, s_mov_ax
    mov ecx, s_mov_ax_len
    call emit_bytes
    mov esi, [line_start]
    add esi, ebx
    add esi, 8
    mov ecx, [line_len]
    sub ecx, ebx
    sub ecx, 8
    call emit_trimmed
    mov esi, s_call_hex
    mov ecx, s_call_hex_len
    call emit_bytes
    jmp .done

.try_out_dec:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 8
    jb .try_out_char
    cmp byte [esi], 'O'
    jne .try_out_char
    cmp byte [esi+1], 'U'
    jne .try_out_char
    cmp byte [esi+2], 'T'
    jne .try_out_char
    cmp byte [esi+3], '_'
    jne .try_out_char
    cmp byte [esi+4], 'D'
    jne .try_out_char
    cmp byte [esi+5], 'E'
    jne .try_out_char
    cmp byte [esi+6], 'C'
    jne .try_out_char
    cmp byte [esi+7], ' '
    jne .try_out_char
    mov esi, s_mov_ax
    mov ecx, s_mov_ax_len
    call emit_bytes
    mov esi, [line_start]
    add esi, ebx
    add esi, 8
    mov ecx, [line_len]
    sub ecx, ebx
    sub ecx, 8
    call emit_trimmed
    mov esi, s_call_dec
    mov ecx, s_call_dec_len
    call emit_bytes
    jmp .done

.try_out_char:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 9
    jb .try_out
    cmp byte [esi], 'O'
    jne .try_out
    cmp byte [esi+1], 'U'
    jne .try_out
    cmp byte [esi+2], 'T'
    jne .try_out
    cmp byte [esi+3], '_'
    jne .try_out
    cmp byte [esi+4], 'C'
    jne .try_out
    cmp byte [esi+5], 'H'
    jne .try_out
    cmp byte [esi+6], 'A'
    jne .try_out
    cmp byte [esi+7], 'R'
    jne .try_out
    cmp byte [esi+8], ' '
    jne .try_out
    mov esi, s_mov_al
    mov ecx, s_mov_al_len
    call emit_bytes
    mov esi, [line_start]
    add esi, ebx
    add esi, 9
    mov ecx, [line_len]
    sub ecx, ebx
    sub ecx, 9
    call emit_trimmed
    mov esi, s_call_char
    mov ecx, s_call_char_len
    call emit_bytes
    jmp .done

.try_out:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 3
    jb .try_line
    cmp byte [esi], 'O'
    jne .try_line
    cmp byte [esi+1], 'U'
    jne .try_line
    cmp byte [esi+2], 'T'
    jne .try_line
    call find_quote
    test eax, eax
    jz .done
    add esi, eax
    inc esi
    mov ecx, [line_len]
    sub ecx, ebx
    sub ecx, eax
    dec ecx
    call emit_string_then_print
    jmp .done
.try_line:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 4
    jb .try_waitms
    cmp byte [esi], 'L'
    jne .try_waitms
    cmp byte [esi+1], 'I'
    jne .try_waitms
    cmp byte [esi+2], 'N'
    jne .try_waitms
    cmp byte [esi+3], 'E'
    jne .try_waitms
    add esi, 4
    sub ecx, 4
    cmp byte [esi], '('
    jne .done
    inc esi
    dec ecx
    xor eax, eax
.num1:
    test ecx, ecx
    jz .num1_done
    mov dl, [esi]
    cmp dl, '0'
    jb .num1_done
    cmp dl, '9'
    ja .num1_done
    imul eax, eax, 10
    sub dl, '0'
    movzx edx, dl
    add eax, edx
    inc esi
    dec ecx
    jmp .num1
.num1_done:
    push esi
    push ecx
    push eax
    mov esi, s_line_pos1
    mov ecx, s_line_pos1_len
    call emit_bytes
    pop eax
    call emit_dec
    mov esi, s_line_pos2
    mov ecx, s_line_pos2_len
    call emit_bytes
    pop ecx
    pop esi
.find_out:
    cmp ecx, 3
    jb .done
    cmp byte [esi], 'O'
    jne .skip1
    cmp byte [esi+1], 'U'
    jne .skip1
    cmp byte [esi+2], 'T'
    jne .skip1
    jmp .find_quote2
.skip1:
    inc esi
    dec ecx
    jmp .find_out
.find_quote2:
    cmp ecx, 3
    jb .done
    add esi, 3
    sub ecx, 3
.skp:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .not_space
    inc esi
    dec ecx
    jmp .skp
.not_space:
    cmp byte [esi], 34
    jne .done
    inc esi
    dec ecx
    call emit_string_then_print
    jmp .done
.try_waitms:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 6
    jb .try_waits
    cmp byte [esi], 'W'
    jne .try_waits
    cmp byte [esi+1], 'A'
    jne .try_waits
    cmp byte [esi+2], 'I'
    jne .try_waits
    cmp byte [esi+3], 'T'
    jne .try_waits
    cmp byte [esi+4], '('
    jne .try_waits
    cmp byte [esi+5], 'M'
    jne .try_waits
.fp:
    test ecx, ecx
    jz .done
    cmp byte [esi], ')'
    je .got_p
    inc esi
    dec ecx
    jmp .fp
.got_p:
    inc esi
    dec ecx
.sw2:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .num2
    inc esi
    dec ecx
    jmp .sw2
.num2:
    xor eax, eax
.n2l:
    test ecx, ecx
    jz .n2d
    mov dl, [esi]
    cmp dl, '0'
    jb .n2d
    cmp dl, '9'
    ja .n2d
    imul eax, eax, 10
    sub dl, '0'
    movzx edx, dl
    add eax, edx
    inc esi
    dec ecx
    jmp .n2l
.n2d:
    push eax
    mov esi, s_waitms1
    mov ecx, s_waitms1_len
    call emit_bytes
    pop eax
    call emit_dec
    mov esi, s_waitms2
    mov ecx, s_waitms2_len
    call emit_bytes
    jmp .done
.try_waits:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 7
    jb .try_reboot
    cmp byte [esi], 'W'
    jne .try_reboot
    cmp byte [esi+1], 'A'
    jne .try_reboot
    cmp byte [esi+2], 'I'
    jne .try_reboot
    cmp byte [esi+3], 'T'
    jne .try_reboot
    cmp byte [esi+4], '('
    jne .try_reboot
    cmp byte [esi+5], 'S'
    jne .try_reboot
    cmp byte [esi+6], ')'
    jne .try_reboot
    add esi, 7
    sub ecx, 7
.sw3:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .num3
    inc esi
    dec ecx
    jmp .sw3
.num3:
    xor eax, eax
.n3l:
    test ecx, ecx
    jz .n3d
    mov dl, [esi]
    cmp dl, '0'
    jb .n3d
    cmp dl, '9'
    ja .n3d
    imul eax, eax, 10
    sub dl, '0'
    movzx edx, dl
    add eax, edx
    inc esi
    dec ecx
    jmp .n3l
.n3d:
    push eax
    mov esi, s_waits1
    mov ecx, s_waits1_len
    call emit_bytes
    pop eax
    call emit_dec
    mov esi, s_waits2
    mov ecx, s_waits2_len
    call emit_bytes
    jmp .done
.try_reboot:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 6
    jb .try_shutdown
    cmp byte [esi], 'R'
    jne .try_shutdown
    cmp byte [esi+1], 'E'
    jne .try_shutdown
    cmp byte [esi+2], 'B'
    jne .try_shutdown
    cmp byte [esi+3], 'O'
    jne .try_shutdown
    cmp byte [esi+4], 'O'
    jne .try_shutdown
    cmp byte [esi+5], 'T'
    jne .try_shutdown
    mov esi, s_reboot
    mov ecx, s_reboot_len
    call emit_bytes
    jmp .done
.try_shutdown:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 8
    jb .try_readkey
    cmp byte [esi], 'S'
    jne .try_readkey
    cmp byte [esi+1], 'H'
    jne .try_readkey
    cmp byte [esi+2], 'U'
    jne .try_readkey
    cmp byte [esi+3], 'T'
    jne .try_readkey
    cmp byte [esi+4], 'D'
    jne .try_readkey
    cmp byte [esi+5], 'O'
    jne .try_readkey
    cmp byte [esi+6], 'W'
    jne .try_readkey
    cmp byte [esi+7], 'N'
    jne .try_readkey
    mov esi, s_shutdown
    mov ecx, s_shutdown_len
    call emit_bytes
    jmp .done
.try_readkey:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 8
    jb .try_label
    cmp byte [esi], 'R'
    jne .try_label
    cmp byte [esi+1], 'E'
    jne .try_label
    cmp byte [esi+2], 'A'
    jne .try_label
    cmp byte [esi+3], 'D'
    jne .try_label
    cmp byte [esi+4], '_'
    jne .try_label
    cmp byte [esi+5], 'K'
    jne .try_label
    cmp byte [esi+6], 'E'
    jne .try_label
    cmp byte [esi+7], 'Y'
    jne .try_label
    mov esi, s_readkey
    mov ecx, s_readkey_len
    call emit_bytes
    jmp .done

.try_label:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 6
    jb .try_goto
    cmp byte [esi], 'L'
    jne .try_goto
    cmp byte [esi+1], 'A'
    jne .try_goto
    cmp byte [esi+2], 'B'
    jne .try_goto
    cmp byte [esi+3], 'E'
    jne .try_goto
    cmp byte [esi+4], 'L'
    jne .try_goto
    cmp byte [esi+5], ' '
    jne .try_goto
    add esi, 6
    sub ecx, 6
.label_trim:
    test ecx, ecx
    jz .done
    mov al, [esi + ecx - 1]
    cmp al, ' '
    je .label_dec
    cmp al, ','
    je .label_dec
    cmp al, 13
    je .label_dec
    cmp al, 10
    je .label_dec
    jmp .label_emit
.label_dec:
    dec ecx
    jmp .label_trim
.label_emit:
    ; emit "L_"
    mov al, 'L'
    call emit_raw_byte
    mov al, '_'
    call emit_raw_byte
    cmp byte [esi + ecx - 1], ':'
    je .label_with_colon
    push ecx
    mov edi, asm_buf
    add edi, [asm_len]
    add [asm_len], ecx
    cld
    rep movsb
    pop ecx
    mov al, ':'
    call emit_raw_byte
    call emit_crlf
    jmp .done
.label_with_colon:
    mov edi, asm_buf
    add edi, [asm_len]
    add [asm_len], ecx
    cld
    rep movsb
    call emit_crlf
    jmp .done

.try_goto:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 5
    jb .try_read
    cmp byte [esi], 'G'
    jne .try_read
    cmp byte [esi+1], 'O'
    jne .try_read
    cmp byte [esi+2], 'T'
    jne .try_read
    cmp byte [esi+3], 'O'
    jne .try_read
    cmp byte [esi+4], ' '
    jne .try_read
    push esi
    push ecx
    mov esi, s_jmp
    mov ecx, s_jmp_len
    call emit_bytes
    pop ecx
    pop esi
    add esi, 5
    sub ecx, 5
    mov al, 'L'
    call emit_raw_byte
    mov al, '_'
    call emit_raw_byte
    call emit_trimmed
    call emit_crlf
    jmp .done

.try_read:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 5
    jb .try_dump
    cmp byte [esi], 'R'
    jne .try_dump
    cmp byte [esi+1], 'E'
    jne .try_dump
    cmp byte [esi+2], 'A'
    jne .try_dump
    cmp byte [esi+3], 'D'
    jne .try_dump
    cmp byte [esi+4], ' '
    jne .try_dump
    add esi, 5
    sub ecx, 5
.rd_skip_sp:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .rd_parse
    inc esi
    dec ecx
    jmp .rd_skip_sp
.rd_parse:
    xor edi, edi
.rd_scan:
    cmp edi, ecx
    jae .rd_scan_done
    mov al, [esi + edi]
    cmp al, ' '
    je .rd_scan_done
    cmp al, ','
    je .rd_scan_done
    cmp al, 9
    je .rd_scan_done
    cmp al, 13
    je .rd_scan_done
    cmp al, 10
    je .rd_scan_done
    inc edi
    jmp .rd_scan
.rd_scan_done:
    test edi, edi
    jz .done
    mov [tmp_pos_row], edi
    mov [tmp_pos_col], esi

    mov esi, s_read_jmp
    mov ecx, s_read_jmp_len
    call emit_bytes
    mov eax, [read_count]
    call emit_dec
    call emit_crlf

    mov esi, s_read_lbl
    mov ecx, s_read_lbl_len
    call emit_bytes
    mov esi, [tmp_pos_col]
    mov ecx, [tmp_pos_row]
.rd_sanitize:
    test ecx, ecx
    jz .rd_san_done
    mov al, [esi]
    cmp al, '.'
    jne .rd_san1
    mov al, '_'
    jmp .rd_san_ok
.rd_san1:
    cmp al, '/'
    jne .rd_san2
    mov al, '_'
    jmp .rd_san_ok
.rd_san2:
    cmp al, ''
    jne .rd_san3
    mov al, '_'
    jmp .rd_san_ok
.rd_san3:
    cmp al, '-'
    jne .rd_san_ok
    mov al, '_'
.rd_san_ok:
    call emit_raw_byte
    inc esi
    dec ecx
    jmp .rd_sanitize
.rd_san_done:
    mov al, ':'
    call emit_raw_byte
    call emit_crlf


    mov esi, s_file_prefix
    mov ecx, s_file_prefix_len
    call emit_bytes

    mov esi, [tmp_pos_col]
    mov ecx, [tmp_pos_row]
.rd_copy_fn:
    test ecx, ecx
    jz .rd_copy_done
    mov al, [esi]
    call emit_raw_byte
    inc esi
    dec ecx
    jmp .rd_copy_fn
.rd_copy_done:
    mov al, 39
    call emit_raw_byte
    call emit_crlf

    mov al, 's'
    call emit_raw_byte
    mov al, 'k'
    call emit_raw_byte
    mov al, 'i'
    call emit_raw_byte
    mov al, 'p'
    call emit_raw_byte
    mov al, '_'
    call emit_raw_byte
    mov al, 'r'
    call emit_raw_byte
    mov al, 'd'
    call emit_raw_byte
    mov al, '_'
    call emit_raw_byte
    mov eax, [read_count]
    call emit_dec
    mov al, ':'
    call emit_raw_byte
    call emit_crlf

    inc [read_count]
    jmp .done

.try_dump:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 6
    jb .try_asm
    cmp byte [esi], 'D'
    jne .try_asm
    cmp byte [esi+1], 'U'
    jne .try_asm
    cmp byte [esi+2], 'M'
    jne .try_asm
    cmp byte [esi+3], 'P'
    jne .try_asm
    cmp byte [esi+4], ' '
    jne .try_asm
    add esi, 5
    sub ecx, 5
.dump_skip_sp:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .dump_label
    inc esi
    dec ecx
    jmp .dump_skip_sp
.dump_label:
    xor edi, edi
.dump_lbl_scan:
    cmp edi, ecx
    jae .dump_lbl_done
    mov al, [esi + edi]
    cmp al, ' '
    je .dump_lbl_done
    cmp al, ','
    je .dump_lbl_done
    cmp al, 13
    je .dump_lbl_done
    cmp al, 10
    je .dump_lbl_done
    inc edi
    jmp .dump_lbl_scan
.dump_lbl_done:
    test edi, edi
    jz .done
    mov [tmp_pos_row], edi
    mov [tmp_pos_col], esi
.dump_skip_after:
    add esi, edi
    sub ecx, edi
    cmp ecx, 0
    je .done
    cmp byte [esi], ','
    jne .dump_skip_sp2
    inc esi
    dec ecx
.dump_skip_sp2:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .dump_count
    inc esi
    dec ecx
    jmp .dump_skip_sp2
.dump_count:
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, 'm'
    call emit_raw_byte
    mov al, 'o'
    call emit_raw_byte
    mov al, 'v'
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, 's'
    call emit_raw_byte
    mov al, 'i'
    call emit_raw_byte
    mov al, ','
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov esi, [tmp_pos_col]
    mov ecx, [tmp_pos_row]
.dump_cp_lbl:
    test ecx, ecx
    jz .dump_cp_done
    mov al, [esi]
    call emit_raw_byte
    inc esi
    dec ecx
    jmp .dump_cp_lbl
.dump_cp_done:
    call emit_crlf
    mov esi, s_mov_cx
    mov ecx, s_mov_cx_len
    call emit_bytes
    mov esi, [tmp_pos_col]
    mov ecx, [tmp_pos_row]
    add esi, ecx
    mov ecx, 0
.dump_find_comma:
    cmp byte [esi+ecx], 0
    je .dump_after_comma
    cmp byte [esi+ecx], ','
    je .dump_after_comma
    inc ecx
    cmp ecx, 64
    jb .dump_find_comma
.dump_after_comma:
    add esi, ecx
    inc esi
    add ecx, 1
.dump_skip2:
    cmp byte [esi], ' '
    jne .dump_num
    inc esi
    jmp .dump_skip2
.dump_num:
    cmp byte [esi], 0
    je .dump_num_done
    cmp byte [esi], 13
    je .dump_num_done
    cmp byte [esi], 10
    je .dump_num_done
    mov al, [esi]
    call emit_raw_byte
    inc esi
    jmp .dump_num
.dump_num_done:
    call emit_crlf
    mov esi, s_call_dump
    mov ecx, s_call_dump_len
    call emit_bytes
    jmp .done

.try_asm:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 4
    jb .try_exec
    cmp byte [esi], 'A'
    jne .try_exec
    cmp byte [esi+1], 'S'
    jne .try_exec
    cmp byte [esi+2], 'M'
    jne .try_exec
    cmp byte [esi+3], ' '
    jne .try_exec
    add esi, 4
    sub ecx, 4
.asm_trim_lead:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .asm_trim_trail
    inc esi
    dec ecx
    jmp .asm_trim_lead
.asm_trim_trail:
    test ecx, ecx
    jz .done
    mov al, [esi + ecx - 1]
    cmp al, ' '
    je .asm_trim_t_dec
    cmp al, 13
    je .asm_trim_t_dec
    cmp al, 10
    je .asm_trim_t_dec
    jmp .asm_emit
.asm_trim_t_dec:
    dec ecx
    jmp .asm_trim_trail
.asm_emit:
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    call emit_bytes_raw
    call emit_crlf
    jmp .done

.try_exec:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 5
    jb .try_if_key
    cmp byte [esi], 'E'
    jne .try_if_key
    cmp byte [esi+1], 'X'
    jne .try_if_key
    cmp byte [esi+2], 'E'
    jne .try_if_key
    cmp byte [esi+3], 'C'
    jne .try_if_key
    cmp byte [esi+4], ' '
    jne .try_if_key
    add esi, 5
    sub ecx, 5
.exec_skip_sp:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .exec_check_rd
    inc esi
    dec ecx
    jmp .exec_skip_sp
.exec_check_rd:
    ; если начинается с "RD_" — это вшитый файл, jmp RD_xxx
    cmp ecx, 3
    jb .exec_plain
    cmp byte [esi], 'R'
    jne .exec_plain
    cmp byte [esi+1], 'D'
    jne .exec_plain
    cmp byte [esi+2], '_'
    jne .exec_plain
    push esi
    push ecx
    mov esi, s_exec_jmp_rd
    mov ecx, s_exec_jmp_rd_len
    call emit_bytes
    pop ecx
    pop esi
    call emit_trimmed
    call emit_crlf
    jmp .done
.exec_plain:
    push esi
    push ecx
    mov esi, s_exec_jmp
    mov ecx, s_exec_jmp_len
    call emit_bytes
    pop ecx
    pop esi
    call emit_trimmed
    call emit_crlf
    jmp .done

.try_if_key:
    mov esi, [line_start]
    add esi, ebx
    mov ecx, [line_len]
    sub ecx, ebx
    cmp ecx, 7
    jb .done
    cmp byte [esi], 'I'
    jne .done
    cmp byte [esi+1], 'F'
    jne .done
    cmp byte [esi+2], '_'
    jne .done
    cmp byte [esi+3], 'K'
    jne .done
    cmp byte [esi+4], 'E'
    jne .done
    cmp byte [esi+5], 'Y'
    jne .done
    cmp byte [esi+6], ' '
    jne .done
    add esi, 7
    sub ecx, 7
    xor edi, edi
.if_scan:
    cmp edi, ecx
    jae .done
    cmp byte [esi+edi], ' '
    je .if_scan_done
    inc edi
    jmp .if_scan
.if_scan_done:
    mov [tmp_pos_row], edi
    add esi, edi
    sub ecx, edi
.if_skip_sp:
    test ecx, ecx
    jz .done
    cmp byte [esi], ' '
    jne .if_check_goto
    inc esi
    dec ecx
    jmp .if_skip_sp
.if_check_goto:
    cmp ecx, 5
    jb .done
    cmp byte [esi], 'G'
    jne .done
    cmp byte [esi+1], 'O'
    jne .done
    cmp byte [esi+2], 'T'
    jne .done
    cmp byte [esi+3], 'O'
    jne .done
    cmp byte [esi+4], ' '
    jne .done
    add esi, 5
    sub ecx, 5
    mov ebp, esi
    mov [tmp_pos_col], ecx
    mov esi, s_if_head
    mov ecx, s_if_head_len
    call emit_bytes
    mov eax, [if_key_count]
    call emit_dec
    mov esi, s_if_cmp
    mov ecx, s_if_cmp_len
    call emit_bytes
    mov ecx, [tmp_pos_row]
    mov esi, [line_start]
    add esi, ebx
    add esi, 7
.if_sc_copy:
    test ecx, ecx
    jz .if_sc_done
    mov al, [esi]
    call emit_raw_byte
    inc esi
    dec ecx
    jmp .if_sc_copy
.if_sc_done:
    mov esi, s_if_jne
    mov ecx, s_if_jne_len
    call emit_bytes
    mov eax, [if_key_count]
    call emit_dec
    mov esi, s_if_consume
    mov ecx, s_if_consume_len
    call emit_bytes
    mov esi, ebp
    mov ecx, [tmp_pos_col]
    call emit_trimmed
    mov esi, s_nokey_dot
    mov ecx, s_nokey_dot_len
    call emit_bytes
    mov eax, [if_key_count]
    call emit_dec
    mov esi, s_colon_crlf
    mov ecx, s_colon_crlf_len
    call emit_bytes
    inc [if_key_count]
.done:
    popad
    ret

find_quote:
    push ecx
    push esi
    xor eax, eax
.l:
    cmp eax, ecx
    jae .none
    cmp byte [esi + eax], 34
    je .found
    inc eax
    jmp .l
.found:
    pop esi
    pop ecx
    ret
.none:
    pop esi
    pop ecx
    xor eax, eax
    ret

emit_trimmed:
    pushad
.trim_trail:
    test ecx, ecx
    jz .empty
    mov al, [esi + ecx - 1]
    cmp al, ','
    je .dec_ecx
    cmp al, ' '
    je .dec_ecx
    cmp al, 13
    je .dec_ecx
    cmp al, 10
    je .dec_ecx
    jmp .skip_lead
.dec_ecx:
    dec ecx
    jmp .trim_trail
.skip_lead:
    test ecx, ecx
    jz .empty
    cmp byte [esi], ' '
    jne .go
    inc esi
    dec ecx
    jmp .skip_lead
.go:
    mov eax, ecx
    mov edi, asm_buf
    add edi, [asm_len]
    add [asm_len], eax
    cld
    rep movsb
.empty:
    popad
    ret

emit_string_then_print:
    pushad
    mov ebp, esi
    xor ebx, ebx
.sl:
    cmp ebx, ecx
    jae .end_str
    cmp byte [esi + ebx], 34
    je .end_str
    inc ebx
    jmp .sl
.end_str:
.trim:
    test ebx, ebx
    jz .copy
    mov al, [esi + ebx - 1]
    cmp al, ','
    je .dec1
    cmp al, ' '
    jne .copy
.dec1:
    dec ebx
    jmp .trim
.copy:
    mov esi, ebp
    mov edi, str_pool
    add edi, [str_off]
    mov ecx, ebx
    cld
    rep movsb
    mov byte [edi], 0
    add [str_off], ebx
    inc dword [str_off]
    ; "    mov si, msg_N"
    mov esi, s_setsi
    mov ecx, s_setsi_len
    call emit_bytes
    mov eax, [msg_count]
    call emit_dec
    call emit_crlf
    ; "    call print_string"
    mov esi, s_print
    mov ecx, s_print_len
    call emit_bytes
    ; "    jmp skip_N"
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, 'j'
    call emit_raw_byte
    mov al, 'm'
    call emit_raw_byte
    mov al, 'p'
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, 's'
    call emit_raw_byte
    mov al, 'k'
    call emit_raw_byte
    mov al, 'i'
    call emit_raw_byte
    mov al, 'p'
    call emit_raw_byte
    mov al, '_'
    call emit_raw_byte
    mov eax, [msg_count]
    call emit_dec
    call emit_crlf
    ; "msg_N: db 'text',0"
    mov al, 'm'
    call emit_raw_byte
    mov al, 's'
    call emit_raw_byte
    mov al, 'g'
    call emit_raw_byte
    mov al, '_'
    call emit_raw_byte
    mov eax, [msg_count]
    call emit_dec
    mov al, ':'
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, 'd'
    call emit_raw_byte
    mov al, 'b'
    call emit_raw_byte
    mov al, ' '
    call emit_raw_byte
    mov al, 39
    call emit_raw_byte
    mov esi, ebp
    mov ecx, ebx
.cp:
    test ecx, ecx
    jz .cp_done
    mov al, [esi]
    call emit_raw_byte
    inc esi
    dec ecx
    jmp .cp
.cp_done:
    mov al, 39
    call emit_raw_byte
    mov al, ','
    call emit_raw_byte
    mov al, '0'
    call emit_raw_byte
    call emit_crlf
    ; "skip_N:"
    mov al, 's'
    call emit_raw_byte
    mov al, 'k'
    call emit_raw_byte
    mov al, 'i'
    call emit_raw_byte
    mov al, 'p'
    call emit_raw_byte
    mov al, '_'
    call emit_raw_byte
    mov eax, [msg_count]
    call emit_dec
    mov al, ':'
    call emit_raw_byte
    call emit_crlf
    inc [msg_count]
    popad
    ret

check_bin_size:
    invoke CreateFileA, path_bin, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, 0, 0
    cmp eax, INVALID_HANDLE_VALUE
    je .err
    mov [hFile], eax
    invoke GetFileSize, [hFile], 0
    mov [code_sz], eax
    mov ecx, 446
    sub ecx, eax
    jns .pos
    xor ecx, ecx
.pos:
    mov [free_b], ecx
    invoke CloseHandle, [hFile]
    ret
.err:
    mov [code_sz], dword 0
    mov [free_b], dword 0
    ret

run_qemu:
    invoke CreateProcessA, 0, cmd_qemu, 0, 0, 0, 0, 0, 0, startinfo, procinfo
    test eax, eax
    jz .done
    invoke CloseHandle, [procinfo.hProcess]
    invoke CloseHandle, [procinfo.hThread]
.done:
    ret

goto_xy:
    movzx eax, dh
    shl eax, 16
    movzx ebx, dl
    or eax, ebx
    push eax
    push dword [hOut]
    call [SetConsoleCursorPosition]
    ret

clear_screen:
    invoke FillConsoleOutputCharacterA, [hOut], ' ', 2000, 0, got
    invoke FillConsoleOutputAttribute, [hOut], 0x07, 2000, 0, got
    ret

pad_spaces:
    push ebx
    mov ebx, ecx
.p:
    test ebx, ebx
    jz .done
    invoke WriteConsoleA, [hOut], space_char, 1, got, 0
    dec ebx
    jmp .p
.done:
    pop ebx
    ret

place_cursor:
    pushad
    xor ecx, ecx
    xor ebx, ebx
    xor edx, edx
    mov edi, [cur]
.lp:
    cmp ecx, edi
    jae .done
    mov al, [buf + ecx]
    inc ecx
    cmp al, 10
    je .nl
    cmp al, 13
    je .lp
    inc edx
    cmp edx, 80
    jb .lp
    xor edx, edx
    inc ebx
    jmp .lp
.nl:
    xor edx, edx
    inc ebx
    jmp .lp
.done:
    cmp ebx, 21
    jbe .ok
    mov ebx, 20
.ok:
    inc ebx
    mov dh, bl
    call goto_xy
    popad
    ret

write_dec:
    pushad
    mov ebx, 10
    xor ecx, ecx
.dv:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .dv
    mov esi, ecx
.po:
    pop eax
    add al, '0'
    mov [char_buf], al
    invoke WriteConsoleA, [hOut], char_buf, 1, got, 0
    dec esi
    jnz .po
    popad
    ret

section '.idata' import data readable writeable
    library kernel32, 'kernel32.dll'
    import kernel32, \
        GetStdHandle, 'GetStdHandle', \
        WriteConsoleA, 'WriteConsoleA', \
        ReadConsoleInputA, 'ReadConsoleInputA', \
        SetConsoleCursorPosition, 'SetConsoleCursorPosition', \
        SetConsoleTextAttribute, 'SetConsoleTextAttribute', \
        FillConsoleOutputCharacterA, 'FillConsoleOutputCharacterA', \
        FillConsoleOutputAttribute, 'FillConsoleOutputAttribute', \
        CreateFileA, 'CreateFileA', \
        ReadFile, 'ReadFile', \
        WriteFile, 'WriteFile', \
        CloseHandle, 'CloseHandle', \
        GetFileSize, 'GetFileSize', \
        CreateDirectoryA, 'CreateDirectoryA', \
        CreateProcessA, 'CreateProcessA', \
        WaitForSingleObject, 'WaitForSingleObject', \
        GetLocalTime, 'GetLocalTime', \
        ExitProcess, 'ExitProcess'
