	ORG $8000

SCR_PALRAM	EQU $3800
CHR_PALRAM	EQU $38C0
HPOS_LOW	EQU $3B08
HPOS_HIGH	EQU $3B09
VPOS_LOW	EQU $3B0A
VPOS_HIGH	EQU $3B0B
OKOUT		EQU $3C00
BANK		EQU $3E00
FLIP		EQU $3D00
JOY1		EQU $3001
JOY2		EQU $3002
CRC			EQU $3005

CHR			EQU $2000
CHR_ATT		EQU $2400
SCR			EQU $2800
SCR_ATT		EQU $2C00

FLIPVAR		EQU $1010

PAL_DONE	EQU $0

RESET: 
	ORCC #$10
	LDS	#$1E00-1
	LDA #$18
	TFR A,DP
	CLRA
	STA	BANK
	LDA #0
	STA FLIP
	CLRA
	STA FLIPVAR
	CLRA
	STA HPOS_LOW
	STA HPOS_HIGH
	STA VPOS_LOW
	STA VPOS_HIGH

	LDX #$1E00
	LDA #$FF
	LDB #$FF
@L:
	STD ,X++
	CMPX #$2000
	BLT @L

	LDA #$A0
	LDX #$1E00
	STA ,X+
	LDA #$B0
	STA ,X+
	LDD #$C0D0
	STD ,X++
	LDD #$A7B7
	LDX #$1F7C
	STD ,X++
	LDD #$C7D7
	STD ,X++

	BSR SETUP_PAL
FIN:
	BRA FIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SETUP_PAL:
	; primero la paleta
	LDA #1
	STA >PAL_DONE	; FLAG
	ANDCC #$EF
@PAL:
	LDA >PAL_DONE
	CMPA #1
	BEQ @PAL
	RTS

CHAR_PALETTE:
	; Characters. 16 palettes
	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

; Scroll. 8 palettes
SCROLL_PALETTE:
	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones

	FDB $F000,$A000,$5000,$0000	; Red   tones
	FDB $0F00,$0A00,$0500,$0000	; Green tones
	FDB $00F0,$00A0,$0050,$0000	; Blue  tones
	FDB $FFF0,$AAA0,$5550,$0000	; Gray  tones
OBJECT_PALETTE:

IRQSERVICE:
	; ORCC #$10
	; fill palette
	; RG mem test
	CLRA	; Is the palette already filled?
	CMPA >PAL_DONE
	;BNE @DOWORK
	CLR OKOUT
	RTI
@DOWORK:
	LDX #CHR_PALRAM
	LDY #CHAR_PALETTE	
@L:	LDD ,Y++
	STA ,X
	STB $100,X
	LEAX 1,X
	CMPY #SCROLL_PALETTE
	BNE @L

	LDX #SCR_PALRAM
	LDY #SCROLL_PALETTE	
@L2:
	LDD ,Y++
	STA ,X
	STB $100,X
	LEAX 1,X
	CMPY #OBJECT_PALETTE
	BNE @L2

	CLR >PAL_DONE
	RTI

	FILL $FF,$FFF8-*

	ORG $FFF8
	.DW IRQSERVICE
	FILL $FF,$FFFE-*
	ORG $FFFE
	.DW	RESET	; Reset vector