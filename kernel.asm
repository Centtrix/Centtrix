[org 0x0000]
[bits 16]

VIDEO_SEG   equ 0xb800
SCREEN_W    equ 80
SCREEN_H    equ 25
COLOR_WHITE equ 0x0f
COLOR_CYAN  equ 0x0b

start_kernel:
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xfff0

    call clear_screen
    mov si, ascii_icon
    call print_colored
    mov si, welcome_msg
    call print_colored
    call newline

main_loop:
    call print_prompt
    call read_command
    call execute_command
    jmp main_loop

; -------------------------------------------------------------------
clear_screen:
    pusha
    mov ax, VIDEO_SEG
    mov es, ax
    xor di, di
    mov cx, SCREEN_W * SCREEN_H
    mov ax, 0x0720
    rep stosw
    popa
    ret

newline:
    pusha
    mov ah, 0x03
    int 0x10
    inc dh
    mov dl, 0
    cmp dh, SCREEN_H
    jl .set
    call scroll_up
    dec dh
.set:
    mov ah, 0x02
    int 0x10
    popa
    ret

scroll_up:
    pusha
    mov ax, VIDEO_SEG
    mov es, ax
    mov ds, ax
    mov si, 0x00A0
    mov di, 0x0000
    mov cx, (SCREEN_H-1) * SCREEN_W / 2
    rep movsw
    mov di, (SCREEN_H-1) * SCREEN_W * 2
    mov cx, SCREEN_W
    mov ax, 0x0720
    rep stosw
    popa
    ret

print_colored:
    pusha
    mov ah, [color_default]
    cmp al, 0
    je .use_default
    mov ah, al
.use_default:
    mov bx, VIDEO_SEG
    mov es, bx
    xor di, di
    mov ah, 0x03
    int 0x10
    mov ax, dx
    mov bl, SCREEN_W
    mul bl
    add ax, cx
    shl ax, 1
    mov di, ax
.next:
    lodsb
    test al, al
    jz .done
    cmp al, 10
    je .newline
    stosw
    jmp .next
.newline:
    mov ax, di
    shr ax, 1
    mov dx, SCREEN_W
    div dl
    mov al, dl
    sub al, ah
    xor ah, ah
    mov cx, ax
    mov al, ' '
    rep stosw
    jmp .next
.done:
    popa
    ret

print_prompt:
    mov si, prompt
    mov al, COLOR_CYAN
    call print_colored
    ret

read_command:
    pusha
    mov di, cmd_buffer
    xor bx, bx
.read_loop:
    call get_key
    cmp al, 0x1c
    je .done
    cmp al, 0x0e
    je .backspace
    cmp bl, 63
    je .read_loop
    mov [di], al
    inc di
    inc bl
    mov ah, 0x0e
    int 0x10
    jmp .read_loop
.backspace:
    cmp bl, 0
    je .read_loop
    dec di
    dec bl
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_loop
.done:
    mov byte [di], 0
    call newline
    popa
    ret

get_key:
    pusha
.wait:
    in al, 0x64
    test al, 0x01
    jz .wait
    in al, 0x60
    mov [key_code], al
    cmp al, 0x1c
    je .enter
    cmp al, 0x0e
    je .back
    mov bx, key_table
    xlatb
    mov [key_ascii], al
.release:
    in al, 0x64
    test al, 0x01
    jz .release_ok
    in al, 0x60
    jmp .release
.release_ok:
    popa
    mov al, [key_ascii]
    ret
.enter:
    mov al, 0x1c
    jmp .release
.back:
    mov al, 0x0e
    jmp .release

key_ascii db 0
key_code  db 0
key_table:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0
    db 'q','w','e','r','t','y','u','i','o','p','[',']',0,0
    db 'a','s','d','f','g','h','j','k','l',';',"'",0,0
    db 'z','x','c','v','b','n','m',',','.','/',0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times 64 db 0

strcmp:
    pusha
.loop:
    lodsb
    mov bl, [di]
    inc di
    cmp al, bl
    jne .not_equal
    test al, al
    jz .equal
    jmp .loop
.not_equal:
    clc
    jmp .finish
.equal:
    stc
.finish:
    popa
    ret

execute_command:
    pusha
    mov si, cmd_buffer
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 0
    je .empty
    dec si

    mov di, str_help
    call strcmp
    jc .help
    mov di, str_clear
    call strcmp
    jc .clear
    mov di, str_echo
    call strcmp
    jc .echo
    mov di, str_shutdown
    call strcmp
    jc .shutdown
    mov si, unknown_msg
    call print_colored
    call newline
    jmp .done

.empty:
    jmp .done

.help:
    mov si, help_msg
    call print_colored
    call newline
    jmp .done

.clear:
    call clear_screen
    jmp .done

.echo:
    add si, 4
    call print_colored
    call newline
    jmp .done

.shutdown:
    mov si, shutdown_msg
    call print_colored
    call newline
    cli
.halt:
    hlt
    jmp .halt

.done:
    popa
    ret

; -------------------------------------------------------------------
ascii_icon db 10
    db '              ++              ',10
    db '            ++++++            ',10
    db '           +++++++++          ',10
    db '         ++++++++++++         ',10
    db '         ++++-++-++++         ',10
    db '        +++-++++++-++=        ',10
    db '        +++++-++-++++         ',10
    db '         ++++++++=+++         ',10
    db '          ++++--+++           ',10
    db '             .++              ',10,0

welcome_msg db 'Welcome to Centtrix OS!',10,0
prompt db 'Centtrix> ',0
unknown_msg db 'Unknown command',10,0
help_msg db 'Commands: help, clear, echo, shutdown',10,0
shutdown_msg db 'Shutting down...',10,0

str_help    db 'help',0
str_clear   db 'clear',0
str_echo    db 'echo',0
str_shutdown db 'shutdown',0

color_default db COLOR_WHITE
cmd_buffer times 64 db 0

; Заполнение до 16 КБ
times 16384-($-$$) db 0