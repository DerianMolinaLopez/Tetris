TITLE TETRIS; DIBUJAR EL MARCO
.MODEL SMALL
.STACK 100H

.DATA
    ATRIB_DISPLAY   DB 10011100B ; Atributos para el display
    ATRIB_CAMPO     DB 00000000B ; Atributos para el campo
    ATRIB_BLOQUE    DB 00101110B ; Atributos para el bloque
    REN             DB 1          ; Posici?n vertical del bloque
    COL             DB 39         ; Posici?n horizontal del bloque (l?mite izq=20, l?mite der=57)
    GAME_OVER       DB 0          ; Variable para indicar si el juego ha terminado
    LETRERO_OVER    DB '     G A M E    O V E R$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; Configuraci?n del modo de video
    MOV AH, 0
    MOV AL, 3
    INT 10H

    ; Fijar el modo de video 3
    MOV AH, 5
    MOV AL, 0
    INT 10H

    ; Fijar la p?gina activa 0
    MOV AH, 7
    MOV AL, 25
    MOV BH, ATRIB_DISPLAY
    MOV CX, 0
    MOV DX, 184FH
    INT 10H

    ; Dibujar el cuadro alrededor
    MOV AH, 6
    MOV AL, 23
    MOV BH, ATRIB_CAMPO
    MOV CX, 0114H
    MOV DX, 173CH
    INT 10H

    ; Bucle principal del juego
    CICLO:
        CALL DIBUJA_BARRA_HORIZONTAL 
        CALL ESPERA
        CMP REN, 22
        JE FIN
        CALL BORRA_LINEA
        INC REN
        JMP CICLO

    FIN:
    ; Terminar el programa
    MOV AH, 4CH
    INT 21H

MAIN ENDP
DIBUJA_CUADRO PROC
    ; Mover el cursor a la posici?n REN y COL
    MOV AH, 2
    MOV DH, REN
    MOV DL, COL
    MOV BH, 0
    INT 10H

    ; Desplegar el cuadro sin un car?cter

    ; Primer rengl?n del cuadro
    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '   ; Espacio en blanco o cualquier otro car?cter que desees usar
    MOV CX, 4     ; Longitud del cuadro
    MOV BL, ATRIB_BLOQUE
    INT 10H

    ; Segundo rengl?n del cuadro
    MOV AH, 2
    MOV DH, REN
    INC DH
    MOV DL, COL
    MOV BH, 0
    INT 10H

    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '   ; Espacio en blanco o cualquier otro car?cter que desees usar
    MOV CX, 4
    MOV BL, ATRIB_BLOQUE
    INT 10H

    RET
DIBUJA_CUADRO ENDP
;PARA DIBUAR LA BARRA HORIZONTAL
DIBUJA_BARRA_HORIZONTAL PROC
    ; Mover el cursor a la posici?n REN y COL
    MOV AH, 2
    MOV DH, REN
    MOV DL, COL
    MOV BH, 0
    INT 10H

    ; Desplegar el cuadro sin un car?cter

    ; Primer rengl?n del cuadro
    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '   ; Espacio en blanco o cualquier otro car?cter que desees usar
    MOV CX, 4     ; Longitud del cuadro
    MOV BL, 01101110B ; Establecer el atributo a rojo (bits 0-2 en 4)
    INT 10H

    ; Segundo rengl?n del cuadro
    MOV AH, 2
    MOV DH, REN
    INC DH
    MOV DL, COL
    MOV BH, 0
    INT 10H

    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '   ; Espacio en blanco o cualquier otro car?cter que desees usar
    MOV CX, 4
    MOV BL, 01101110B ; Establecer el atributo a rojo (bits 0-2 en 4)
    INT 10H

    RET
DIBUJA_BARRA_HORIZONTAL ENDP


BORRA_LINEA PROC
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
    MOV CX, 4
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
    MOV CX, 4
    MOV BL, ATRIB_CAMPO
    INT 10H

    RET

BORRA_LINEA ENDP

ESPERA PROC
    PUSH CX
    MOV CX, 0FFFFH

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
        LOOP CICLO_ESPERA

    POP CX

    RET

ESPERA ENDP

END MAIN
