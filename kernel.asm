[org 0x0000]
[bits 16]

VIDEO_SEG   equ 0xb800
SCREEN_W    equ 80
SCREEN_H    equ 25
COLOR_WHITE equ 0x0f
COLOR_GREEN equ 0x0a
COLOR_RED   equ 0x0c
COLOR_YELLOW equ 0x0e
COLOR_CYAN  equ 0x0b

APP_SEG     equ 0x2000
APP_OFF     equ 0x0000

ROOT_SECTOR equ 66
DATA_SECTOR equ 68
MAX_FILES   equ 64

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

    call load_root_dir

main_loop:
    call print_prompt
    call read_command
    call execute_command
    jmp main_loop

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

dir_buffer times 1024 db 0
temp_buffer times 512 db 0

load_root_dir:
    pusha
    mov ax, 0x1000
    mov es, ax
    mov bx, dir_buffer
    mov ah, 0x02
    mov al, 2
    mov ch, 0
    mov cl, ROOT_SECTOR
    mov dh, 0
    mov dl, 0x00
    int 0x13
    popa
    ret

save_root_dir:
    pusha
    mov ax, 0x1000
    mov es, ax
    mov bx, dir_buffer
    mov ah, 0x03
    mov al, 2
    mov ch, 0
    mov cl, ROOT_SECTOR
    mov dh, 0
    mov dl, 0x00
    int 0x13
    popa
    ret

read_data_sector:
    pusha
    add ax, DATA_SECTOR - 1
    mov cx, ax
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, cl
    mov dh, 0
    mov dl, 0x00
    int 0x13
    popa
    ret

write_data_sector:
    pusha
    add ax, DATA_SECTOR - 1
    mov cx, ax
    mov ah, 0x03
    mov al, 1
    mov ch, 0
    mov cl, cl
    mov dh, 0
    mov dl, 0x00
    int 0x13
    popa
    ret

find_file:
    push si
    push cx
    push dx
    mov di, dir_buffer
    mov cx, MAX_FILES
.search:
    cmp byte [di], 0
    je .next
    push di
    call compare_filename
    pop di
    jc .found
.next:
    add di, 16
    loop .search
    mov di, 0
    jmp .done
.found:
    mov ax, [di+12]
    mov bx, [di+14]
.done:
    pop dx
    pop cx
    pop si
    ret

compare_filename:
    pusha
    mov bx, di
    mov cx, 8
.loop_name:
    lodsb
    cmp al, '.'
    je .name_done
    cmp al, 0
    je .name_done
    cmp al, [bx]
    jne .not_equal
    inc bx
    loop .loop_name
.name_done:
    cmp cx, 0
    je .check_ext
    add bx, cx
.check_ext:
    cmp byte [si], '.'
    jne .no_dot
    inc si
.no_dot:
    mov cx, 3
.loop_ext:
    lodsb
    cmp al, 0
    je .ext_done
    cmp al, [bx]
    jne .not_equal
    inc bx
    loop .loop_ext
.ext_done:
    stc
    jmp .finish
.not_equal:
    clc
.finish:
    popa
    ret

get_free_sector:
    push si
    push cx
    push di
    mov si, dir_buffer
    mov cx, MAX_FILES
    mov bx, 1
.scan:
    cmp byte [si], 0
    je .next
    mov ax, [si+14]
    cmp ax, bx
    jne .no_update
    inc bx
.no_update:
    add si, 16
    loop .scan
    mov ax, bx
    pop di
    pop cx
    pop si
    ret

create_file:
    pusha
    mov di, dir_buffer
    mov cx, MAX_FILES
.find_free:
    cmp byte [di], 0
    je .found_slot
    add di, 16
    loop .find_free
    mov ax, 1
    jmp .error
.found_slot:
    push si
    push di
    mov cx, 8
    xor bx, bx
.copy_name:
    lodsb
    cmp al, 0
    je .fill_name
    cmp al, '.'
    je .fill_name
    mov [di], al
    inc di
    inc bx
    loop .copy_name
.fill_name:
    cmp bx, 8
    je .ext_part
    mov byte [di], ' '
    inc di
    inc bx
    jmp .fill_name
.ext_part:
    mov byte [di], 'c'
    inc di
    mov byte [di], 't'
    inc di
    mov byte [di], 'x'
    inc di
    mov byte [di], 0
    inc di
    mov word [di], 1
    add di, 2
    call get_free_sector
    mov [di], ax
    add di, 2
    pop di
    pop si
    call save_root_dir
    push ax
    mov ax, 0x1000
    mov es, ax
    mov bx, temp_buffer
    push cx
    mov cx, 256
    xor ax, ax
    rep stosw
    pop cx
    pop ax
    call write_data_sector
    mov ax, 0
    jmp .done
.error:
    mov [retval], ax
.done:
    popa
    mov ax, [retval]
    ret

delete_file:
    pusha
    call find_file
    cmp di, 0
    je .not_found
    mov byte [di], 0
    call save_root_dir
    mov ax, 0
    jmp .done
.not_found:
    mov ax, 2
.done:
    mov [retval], ax
    popa
    mov ax, [retval]
    ret

do_ls:
    pusha
    mov si, dir_buffer
    mov cx, MAX_FILES
    mov di, 0
.list:
    cmp byte [si], 0
    je .next
    push cx
    push si
    mov cx, 8
.print_name:
    mov al, [si]
    cmp al, ' '
    je .skip_name
    mov ah, 0x0e
    int 0x10
.skip_name:
    inc si
    loop .print_name
    mov al, '.'
    int 0x10
    mov cx, 3
.print_ext:
    mov al, [si]
    cmp al, ' '
    je .skip_ext
    int 0x10
.skip_ext:
    inc si
    loop .print_ext
    mov al, ' '
    int 0x10
    mov ax, [si+4]
    call print_num
    call newline
    pop si
    pop cx
    inc di
.next:
    add si, 16
    loop .list
    cmp di, 0
    jne .done
    mov si, no_files_msg
    call print_colored
    call newline
.done:
    popa
    ret

do_cat:
    pusha
    call find_file
    cmp di, 0
    je .not_found
    mov ax, [di+14]
    mov cx, [di+12]
.read_next:
    push cx
    push ax
    call read_data_sector
    mov si, temp_buffer
    mov cx, 512
.print_char:
    lodsb
    cmp al, 0
    je .skip_zero
    mov ah, 0x0e
    int 0x10
.skip_zero:
    loop .print_char
    pop ax
    inc ax
    pop cx
    loop .read_next
    call newline
    jmp .done
.not_found:
    mov si, file_not_found_msg
    call print_colored
    call newline
.done:
    popa
    ret

do_run:
    pusha
    call find_file
    cmp di, 0
    je .not_found
    mov ax, APP_SEG
    mov es, ax
    xor bx, bx
    mov ax, [di+14]
    mov cx, [di+12]
.load_next:
    push cx
    push ax
    call read_data_sector
    push si
    push di
    mov si, temp_buffer
    mov di, bx
    mov cx, 256
    rep movsw
    pop di
    pop si
    pop ax
    inc ax
    pop cx
    loop .load_next
    call far [APP_SEG:APP_OFF]
    call clear_screen
    jmp .done
.not_found:
    mov si, file_not_found_msg
    call print_colored
    call newline
.done:
    popa
    ret

do_mkapp:
    pusha
    call create_file
    cmp ax, 0
    jne .error
    call find_file
    mov ax, [di+14]
    mov si, app_template
    mov di, temp_buffer
    mov cx, app_template_len
    rep movsb
    call write_data_sector
    mov si, app_created_msg
    call print_colored
    call newline
    jmp .done
.error:
    mov si, create_error_msg
    call print_colored
    call newline
.done:
    popa
    ret

print_num:
    pusha
    xor cx, cx
    mov bx, 10
.div:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div
.print:
    pop dx
    add dl, '0'
    mov ah, 0x0e
    int 0x10
    loop .print
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
    mov di, str_ls
    call strcmp
    jc .ls
    mov di, str_cat
    call strcmp
    jc .cat
    mov di, str_run
    call strcmp
    jc .run
    mov di, str_create
    call strcmp
    jc .create
    mov di, str_delete
    call strcmp
    jc .delete
    mov di, str_mkapp
    call strcmp
    jc .mkapp
    mov di, str_flappy
    call strcmp
    jc .flappy
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

.ls:
    call do_ls
    jmp .done

.cat:
    add si, 3
    call skip_spaces
    call do_cat
    jmp .done

.run:
    add si, 3
    call skip_spaces
    call do_run
    jmp .done

.create:
    add si, 6
    call skip_spaces
    call create_file
    cmp ax, 0
    je .create_ok
    mov si, create_error_msg
    call print_colored
    call newline
.create_ok:
    jmp .done

.delete:
    add si, 6
    call skip_spaces
    call delete_file
    cmp ax, 0
    je .delete_ok
    mov si, file_not_found_msg
    call print_colored
    call newline
.delete_ok:
    jmp .done

.mkapp:
    add si, 5
    call skip_spaces
    call do_mkapp
    jmp .done

.flappy:
    call flappy_game
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

skip_spaces:
    pusha
.loop:
    lodsb
    cmp al, ' '
    je .loop
    cmp al, 0
    je .end
    dec si
.end:
    popa
    ret

flappy_game:
    pusha
    call clear_screen
    mov byte [bird_y], 12
    mov byte [bird_x], 20
    mov byte [score], 0
    mov word [pipe_x], 79
    mov byte [pipe_gap], 5
    mov byte [pipe_top], 8
    mov byte [velocity], 0
    mov byte [game_over], 0

.game_loop:
    call key_pressed
    cmp al, 0x39
    jne .no_jump
    mov byte [velocity], -4
.no_jump:
    mov al, [velocity]
    add al, 1
    mov [velocity], al
    mov al, [bird_y]
    add al, [velocity]
    mov [bird_y], al
    cmp byte [bird_y], 23
    jg .game_over
    cmp byte [bird_y], 1
    jl .game_over

    dec word [pipe_x]
    cmp word [pipe_x], 0
    jg .no_new_pipe
    mov word [pipe_x], 79
    inc byte [score]
.no_new_pipe:
    mov ax, [pipe_x]
    cmp ax, 20
    jne .no_collision
    mov al, [bird_y]
    cmp al, [pipe_top]
    jl .game_over
    add al, [pipe_gap]
    cmp al, [bird_y]
    jg .game_over
.no_collision:

    call draw_game
    mov cx, 0x0010
.delay:
    loop .delay
    jmp .game_loop

.game_over:
    call clear_screen
    mov si, game_over_msg
    call print_colored
    call newline
    mov si, score_msg
    call print_colored
    mov al, [score]
    add al, '0'
    mov ah, 0x0e
    int 0x10
    call newline
    mov si, press_key_msg
    call print_colored
    call newline
.wait:
    call get_key
    cmp al, 0x1c
    jne .wait
    call clear_screen
    popa
    ret

draw_game:
    pusha
    call clear_screen
    mov ah, COLOR_YELLOW
    mov al, 'P'
    mov dh, [bird_y]
    mov dl, [bird_x]
    call put_char
    mov ah, COLOR_GREEN
    mov cx, [pipe_x]
    mov dl, cl
    mov dh, 0
.draw_top:
    mov al, '#'
    call put_char
    inc dh
    cmp dh, [pipe_top]
    jl .draw_top
    mov dh, [pipe_top]
    add dh, [pipe_gap]
.draw_bottom:
    mov al, '#'
    call put_char
    inc dh
    cmp dh, 24
    jl .draw_bottom
    mov dh, 0
    mov dl, 70
    mov al, 'S'
    call put_char
    inc dl
    mov al, ':'
    call put_char
    inc dl
    mov al, [score]
    add al, '0'
    call put_char
    popa
    ret

put_char:
    pusha
    mov bx, VIDEO_SEG
    mov es, bx
    xor bh, bh
    mov bl, dh
    mov dh, SCREEN_W
    mul dh
    add dl, al
    xor dh, dh
    mov di, dx
    shl di, 1
    mov [es:di], ax
    popa
    ret

key_pressed:
    in al, 0x64
    test al, 0x01
    jz .none
    in al, 0x60
.release:
    in al, 0x64
    test al, 0x01
    jz .release_ok
    in al, 0x60
    jmp .release
.release_ok:
    ret
.none:
    xor al, al
    ret

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
help_msg db 'Commands: help, clear, echo, ls, cat, run, create, delete, mkapp, flappy, shutdown',10,0
shutdown_msg db 'Shutting down...',10,0
no_files_msg db 'No files',10,0
file_not_found_msg db 'File not found',10,0
create_error_msg db 'Error: no free slot or disk full',10,0
app_created_msg db 'App created successfully',10,0
game_over_msg db 'Game Over!',10,0
score_msg db 'Score: ',0
press_key_msg db 'Press Enter to exit',10,0

app_template:
    push cs
    pop ds
    mov si, msg
    call print
    ret
msg db 'Hello from .ctx app!', 13,10,0
print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print
.done:
    ret
app_template_len equ $ - app_template

str_help    db 'help',0
str_clear   db 'clear',0
str_echo    db 'echo',0
str_ls      db 'ls',0
str_cat     db 'cat',0
str_run     db 'run',0
str_create  db 'create',0
str_delete  db 'delete',0
str_mkapp   db 'mkapp',0
str_flappy  db 'flappy',0
str_shutdown db 'shutdown',0

color_default db COLOR_WHITE
cmd_buffer times 64 db 0
retval dw 0
bird_y db 0
bird_x db 0
velocity db 0
pipe_x dw 0
pipe_top db 0
pipe_gap db 5
score db 0
game_over db 0

times 32768-($-$$) db 0
