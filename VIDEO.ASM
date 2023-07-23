videoseg = 0A000h
romseg = 0F000h
chargen = 0FA6Eh

init_screen proc
   mov ax, 13h
   int 10h
   ret
init_screen endp

draw_field proc
    push es
    mov ax, videoseg
    mov es, ax

    mov dx, 00h
    call clear

    mov di, 0FFh
    mov ah, 10h
draw_loop:
    mov al, 10h
draw_inner_loop:
    mov bx, ax
    shl bl, 3
    shl bh, 3
    call draw_cell
    dec di
    dec al
    jnz draw_inner_loop
    dec ah
    jnz draw_loop

    pop es
    ret
draw_field endp

draw_cell proc
    push ax
    ; draw background
    xor ax, ax
    mov al, bh
    mov si, 320
    mul si
    xor bh, bh
    add ax, bx
    mov si, ax
    mov dh, field[di]
    rcl dh, 1
    jnc hidden
    mov dl, 1Ah ; light grey when revealed
    jmp draw_bg
hidden:
    mov dl, 15h ; dark grey when hidden
draw_bg: 
    mov ch, 8
bg_loop:
    mov cl, 8
bg_inner_loop:
    mov byte ptr es:[si], dl
    inc si
    dec cl
    jnz bg_inner_loop
    add si, 312
    dec ch
    jnz bg_loop

draw_border:
    mov dl, 12h
    mov si, ax
    mov bx, ax
    mov ch, 8
border_loop:
    mov byte ptr es:[si], dl
    mov byte ptr es:[bx], dl
    inc si
    add bx, 320
    dec ch
    jnz border_loop
    
    mov dh, field[di]
    rcl dh, 1
    jnc draw_cell_end
draw_content:
    rcl dh, 1   ; flagged
    jnc draw_revealed
    ; draw flag
    jmp draw_cell_end
draw_revealed:
    rcl dh, 1   ; mine
    jc draw_mine
    shr dh, 3
    jz draw_cell_end
    mov dl, dh
    xor bx, bx
    mov bl, dl
    add dl, 30h
    mov dh, colors[bx]
    jmp draw_call
draw_mine:
    mov dh, 00h
    mov dl, 58h
draw_call:
    mov si, ax
    call draw_char
draw_cell_end:
    pop ax
    ret
draw_cell endp

; si = top left draw corner
; dx = color:character
draw_char proc
    push ds
    push dx
    push ax
    mov ax, romseg
    mov ds, ax
    
    xor bx, bx
    mov bl, dl
    shl bx, 3
    mov ch, 0
char_loop:
    mov cl, 0
    mov al, byte ptr chargen[bx]
    inc bx
inner_char_loop:
    rcl al, 1
    jnc char_loop_end
    mov byte ptr es:[si+321], dh
char_loop_end:
    inc si
    inc cl
    cmp cl, 8
    jne inner_char_loop
    add si, 312
    inc ch
    cmp ch, 8
    jne char_loop

    pop ax
    pop dx
    pop ds
    ret
draw_char endp

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