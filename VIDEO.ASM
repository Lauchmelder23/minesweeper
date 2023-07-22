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

    xor si, si
    mov dx, 25h
    mov cx, 320*200
draw_loop:
    call draw
    inc si
    dec cx
    jnz draw_loop

    pop es
    ret
draw_field endp

draw proc
    mov byte ptr es:[si], dl
    ret
draw endp