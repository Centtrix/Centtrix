[org 0x7c00]
[bits 16]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0x00
    int 0x13
    jc load_error

    jmp 0x1000:0x0000

load_error:
    mov si, err_msg
    call print
    cli
    hlt

print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print
.done:
    ret

err_msg db 'Kernel load error!', 0

times 510-($-$$) db 0
dw 0xaa55