videoseg = 0B800h

init_screen proc
   mov ax, 3
   int 10h
   ret
init_screen endp

draw_field proc
   push es
   mov ax, videoseg
   mov es, ax

   xor si, si
   xor di, di
   mov dh, fsize
draw_loop:
   mov dl, fsize
draw_inner_loop:
   mov cl, byte ptr field[di]
   mov ch, 0fh
   call draw
   inc di
   dec dl
   jnz draw_inner_loop
   add si, 64 * 2
   dec dh
   jnz draw_loop

   pop es
   ret
draw_field endp

draw proc
   push di
   mov bx, cx
   shl bl, 5
   ; if field is hidden, draw a #
   rcl cl, 1
   jc draw_revealed
   mov bx, 0723h
   ; if field is flagged, draw an F
   rcl cl, 1
   jnc display_symbol
   mov bx, 0F46h
   jmp display_symbol
draw_revealed:
   rcl cl, 2 
   jc draw_mine
   ; at this point the value was shifted left twice
   ; so we shift right twice and mask the lower bits
   shr cl, 3
   and cl, 0Fh
   mov bl, 30h
   add bl, cl
   xor ch, ch 
   mov di, cx
   mov bh, byte ptr colors[di]
   jmp display_symbol   
draw_mine:
   mov bx, 4058h

display_symbol:
   mov word ptr es:[si], bx
   inc si
   inc si
   pop di
   ret
draw endp