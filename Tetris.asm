TITLE TETRIS; DIBUJAR EL MARCO
.MODEL SMALL
.STACK 100H
.DATA
    ATRIB_DISPLAY   DB 10011100B ; Atributos para el display
    ATRIB_CAMPO     DB 00000000B ; Atributos para el campo
    ATRIB_BLOQUE    DB 00101110B ; Atributos para el bloque
    MORADO          DB 00001101B ; Atributos para el bloque (morado)
    REN             DB 1          ; Posici?n vertical del bloque
    COL             DB 39         ; Posici?n horizontal del bloque (l?mite izq=20, l?mite der=57)


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
    MOV AL, 0
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
    JE FIJA_POSICION_Y_GENERA_NUEVO_BLOQUE ; Verifica si el bloque ha llegado al l?mite

    CALL BORRA_LINEA
    INC REN
    JMP CICLO

FIJA_POSICION_Y_GENERA_NUEVO_BLOQUE:
    ; Fijar la posici?n de la figura en el campo
    ; Aqu? puedes guardar la posici?n actual de la figura en la matriz del campo o en una estructura de datos apropiada

    ; Llama al procedimiento para generar una nueva figura
    CALL GENERAR_FIGURA

    ; Restablece las coordenadas del nuevo bloque
    MOV REN, 1
    MOV COL, 39 ; Puedes ajustar la posici?n inicial seg?n tus necesidades

    JMP CICLO

GENERA_NUEVO_BLOQUE:
    ; Llama al procedimiento para generar una figura aleatoria
    CALL GENERAR_FIGURA

    ; Restablece las coordenadas del nuevo bloque
    MOV REN, 1
    MOV COL, 39 ; Puedes ajustar la posici?n inicial seg?n tus necesidades

    JMP CICLO

FIN:
    ; Terminar el programa
    MOV AH, 4CH
    INT 21H

MAIN ENDP

; Generaci?n aleatoria de la figura
GENERAR_FIGURA PROC
    ; Genera un n?mero aleatorio entre 1 y 3 para seleccionar una figura
    MOV AH, 2
    INT 1AH
    XOR AL, AL
    MOV CX, 3
    DIV CX
    INC AL ; Ajusta el rango a 1-3

    ; Puedes hacer algo diferente seg?n el valor de AL
    CMP AL, 1
    JE DIBUJA_CUADRO
    CMP AL, 2
    JE DIBUJA_BARRA_HORIZONTAL
    CMP AL, 3
    JE DIBUJA_BARRA_VERTICAL

    RET


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
    MOV CX, 18     ; Longitud del cuadro
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
    MOV CX, 18
    MOV BL, 01101110B ; Establecer el atributo a rojo (bits 0-2 en 4)
    INT 10H

    RET
DIBUJA_BARRA_HORIZONTAL ENDP

DIBUJA_BARRA_VERTICAL PROC
    ; Mover el cursor a la posici?n REN y COL
    MOV AH, 2
    MOV DH, REN
    MOV DL, COL ; Agrega esto para ajustar la columna
    MOV BH, 0
    INT 10H

    ; Desplegar el cuadro sin un car?cter

    ; Primer rengl?n del cuadro
    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '   ; Espacio en blanco o cualquier otro car?cter que desees usar
    MOV CX, 4     ; Longitud del cuadro (igual a la anchura actual)
    MOV BL, 01101110B ; Establecer el atributo a rojo (bits 0-2 en 4)
    INT 10H

    ; Siguiente rengl?n del cuadro
    MOV AH, 2
    INC DH ; Mueve a la siguiente fila
    MOV DL, COL ; Ajusta la columna de nuevo
    MOV BH, 0
    INT 10H

    ; Repite para las siguientes l?neas
    MOV AH, 9
    MOV BH, 0
    MOV AL, ' '   ; Espacio en blanco o cualquier otro car?cter que desees usar
    MOV CX, 4     ; Longitud del cuadro (igual a la anchura actual)
    MOV BL, 01101110B ; Establecer el atributo a rojo (bits 0-2 en 4)
    INT 10H

    MOV AH, 2
    INC DH ; Mueve a la siguiente fila
    MOV DL, COL ; Ajusta la columna de nuevo
    MOV BH, 0
    INT 10H
    ; Repite esto para cada l?nea adicional...

    RET
DIBUJA_BARRA_VERTICAL ENDP

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
