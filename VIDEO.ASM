videoseg = 0A000h

init_screen proc
   mov ax, 13h
   int 10h
   ret
init_screen endp

draw_field proc
    push es
    mov ax, videoseg
    mov es, ax

    mov dx, 25h
    call clear

    pop es
    ret
draw_field endp

clear proc
    xor si, si
    mov cx, 320*200
clear_loop:
    mov byte ptr es:[si], dl
    inc si
    dec cx
    jnz clear_loop
    ret
clear endp

draw proc
    mov byte ptr es:[si], dl
    ret
draw endp