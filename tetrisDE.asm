TITLE TETRIS; DIBUJAR EL MARCO
.MODEL SMALL
.STACK 100H
.DATA
    ATRIB_DISPLAY   DB 80h ; Atributos para el display
    ATRIB_CAMPO     DB 70h ; Atributos para el campo
    ATRIB_BLOQUE    DB 80h ; Atributos para el bloque
    REN             DB 2          ; Posici?n vertical del bloque
    COL             DB 25        ; Posici?n horizontal del bloque (l?mite izq=25, l?mite der=57)
    ren2            db 2
    sizeb           dw 2 ; tama?o del bloque
.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; Configuracion del modo de video
    MOV AH, 0
    MOV AL, 3
    INT 10H

    ; Fijar el modo de video 3
    MOV AH, 5
    MOV AL, 0
    INT 10H

    ; Fijar la p?gina activa 0
    MOV AH, 7
    MOV AL, 0
    MOV BH, ATRIB_DISPLAY
    MOV CX, 0
    MOV DX, 184FH
    INT 10H

    ; Dibujar el cuadro alrededor
    MOV AH, 6
    MOV AL, 23
    MOV BH, ATRIB_CAMPO
    MOV CX, 0105H
    MOV DX, 1730H
    INT 10H
juego: ;ciclo de juego
    
    inc ren2
    MOV AH, 2
    MOV DH, REN2
    MOV DL, COL
    MOV BH, 0
    INT 10H
    MOV AH,8
    MOV BH,0
    INT 10H
    dec ren2
    cmp ah, ATRIB_BLOQUE
    je fin 
   
    ; ciclo que hace que caiga la pieza
CICLO:
    CALL DIBUJA_CUADRO
    call comparacion_bloque
    CALL ESPERA
    CALL BORRA_LINEA
    INC REN
    inc ren2
    JMP CICLO
    sigue:
        mov ren , 2
        mov ren2, 2
        mov col, 25
        call cambiasize
jmp juego
fin:
    ; Terminar el programa
    MOV AH, 4CH
    INT 21H

MAIN ENDP
comparacion_bloque proc
    MOV AH, 2
    inc ren2
    MOV DH, REN2
    MOV DL, COL
    MOV BH, 0
    INT 10H
    MOV AH,8
    MOV BH,0
    INT 10H
    dec ren2
    CMP Ah,ATRIB_CAMPO
    jne sigue;
    cmp ah, ATRIB_BLOQUE
    je sigue
    
    MOV AH, 2
    inc ren2
    add col, 2
    MOV DH, REN2
    MOV DL, COL
    MOV BH, 0
    INT 10H
    MOV AH,8
    MOV BH,0
    INT 10H
    sub col, 2
    dec ren2
    CMP Ah,ATRIB_CAMPO
    jne sigue;
    cmp ah, ATRIB_BLOQUE
    je sigue
comparacion_bloque endp 

DIBUJA_CUADRO PROC
    ;MOVER el cursor
    MOV AH, 2
    MOV DH, REN
    MOV DL, COL
    MOV BH, 0
    INT 10H
   
    ;DIBUJA EL CUADRO
    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '
    MOV CX, SIZEb    
    MOV BL, ATRIB_BLOQUE
    INT 10H
    
    
    RET
DIBUJA_CUADRO ENDP




BORRA_LINEA PROC ; ESTO ES PARA QUE BORREMOS LA L?NEA QUE IR? DEJANDO A MEDIDA QUE SIGA AVANZANDO LA FIGURA
    MOV AH, 2
    MOV DH, REN
    MOV DL, COL
    MOV BH, 0
    INT 10H

    ; Desplegar cuadro

    ; Primer rengl?n del cuadro
    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '
    MOV CX, 18
    MOV BL, ATRIB_CAMPO
    INT 10H

    MOV AH, 2
    MOV DH, REN
    INC DH
    MOV DL, COL
    MOV BH, 0
    INT 10H

    ; Segundo rengl?n del cuadro
    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '
    MOV CX, 18
    MOV BL, ATRIB_CAMPO
    INT 10H
    
    

    RET

BORRA_LINEA ENDP

ESPERA PROC
    PUSH CX
    MOV CX, 00FFFH

    CICLO_ESPERA:
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        LOOP CICLO_ESPERA

    POP CX
    RET

ESPERA ENDP
cambiasize proc
    cmp sizeb, 8
    je cambia
    add sizeb, 6 ; Incrementa en 6 para la figura de 8x2
    jmp saltaaa
cambia:
    mov sizeb, 2 ; Reinicia en 2 para la figura de 2x2
saltaaa:
    ret
cambiasize endp

END MAIN
