;-----------------------------------------------------------------------		
;
; ATR2JAC starter for J(atari)Cart with 128 sectors
; (c) 2022 GienekP
;
;-----------------------------------------------------------------------

RAMPROC = $0100

;-----------------------------------------------------------------------

TMP     = $A0

;-----------------------------------------------------------------------

CRITIC  = $42
RAMTOP  = $6A

DMACTLS = $022F
PDVMSK  = $0247
MEMTOP  = $02E5
DVSTAT  = $02EA

DDEVIC  = $0300
DUNIT   = $0301
DCMND   = $0302
DSTATS  = $0303
DBUFA   = $0304
DAUX1	= $030A
DAUX2	= $030B
BASICF  = $03F8
GINTLK  = $03FA

TRIG3   = $D013
IRQEN   = $D20E
IRQST   = $D20E
PORTB   = $D301
DMACTL  = $D400
VCOUNT  = $D40B
NMIEN   = $D40E

WAIT	= $C0DF
RESETWM = $C290
RESETCD = $C2C8
BOOT    = $C58B
JSIOINT = $E459

;-----------------------------------------------------------------------		
; MaxFlash128kB+ CARTRIDGE

		OPT h-f+
		
		ORG $A000

;-----------------------------------------------------------------------		
; SectorMap generated by SectorMap.c

		INS "SectorMap128.dta"
		
;-----------------------------------------------------------------------		
; BANK 0

		ORG $BD00
	
;-----------------------------------------------------------------------		
; CARTRUN ROUTINE
	
BEGIN	jsr IRQDIS
		jsr ROM2RAM
		jsr SETRAM
		jsr OVRDINT
		jsr IRQENB
		jsr RESERVE
		jsr FINAL
		jmp BYEBYE
	
;-----------------------------------------------------------------------		
; IRQ ENABLE

IRQENB	lda #$40
		sta NMIEN
		lda #$F7
		sta IRQST
		lda DMACTLS
		sta DMACTL
		cli
		rts

;-----------------------------------------------------------------------		
; IRQ DISABLE

IRQDIS	sei	
		lda #$00
		sta DMACTL
		sta NMIEN
		sta IRQEN
		sta IRQST
		rts
		
;-----------------------------------------------------------------------		
; COPY ROM TO RAM
	
ROM2RAM	lda #$C0
		sta TMP+1
		ldy #$00
		sty TMP
L3		lda (TMP),Y
		tax 
		lda #$FE
		and PORTB
		sta PORTB
		txa 
		sta (TMP),Y
		lda #$01
		ora PORTB
		sta PORTB
		iny
		bne L3
NOK		inc TMP+1
		clc
		lda TMP+1
		cmp #$D0
		bcc T1
		cmp #$D8
		bcc NOK
T1		cmp #$00
		bne L3
		clc 
		rts
		
;-----------------------------------------------------------------------		
; SET RAM & DISABLE BASIC

SETRAM	lda PORTB
		and #$FE
		ora #$02
		sta PORTB
		lda #$01
		sta BASICF
		rts
		
;-----------------------------------------------------------------------		
; COPY NEW SIOINT PROCEDURE

OVRDINT	lda #<SIOCPY
		sta TMP
		lda #>SIOCPY
		sta TMP+1
		lda JSIOINT+1
		sta TMP+2
		lda JSIOINT+2
		sta TMP+3
			
		ldy #ENDCPY-SIOCPY-1
LPCPY	lda (TMP),Y
		sta (TMP+2),Y
		dey
		bne LPCPY
		lda (TMP),Y
		sta (TMP+2),Y
		
		lda RESETWM+2
		sta RESETWM+5
		lda RESETWM+3
		sta RESETWM+6
		
		lda WAIT+69
		sta WAIT+72
		lda WAIT+70
		sta WAIT+73	
		
		rts
		
;-----------------------------------------------------------------------		
; COPY TO $RAMPROC FOR "KILLERS" PORTB

RESERVE	lda #<ZEROCP
		sta TMP
		lda #>ZEROCP
		sta TMP+1
		lda #<RAMPROC
		sta TMP+2
		lda #>RAMPROC
		sta TMP+3		
		ldy #ZEROEND-ZEROCP-1
RESCPY	lda (TMP),Y
		sta (TMP+2),Y
		dey
		bne RESCPY
		lda (TMP),Y
		sta (TMP+2),Y
		rts

;-----------------------------------------------------------------------		
; FINAL VALUES

FINAL 	lda #$1F
		sta MEMTOP
		lda #$BC
		sta MEMTOP+1
		lda #$C0
		sta RAMTOP
		lda #$01
		sta PDVMSK
VCL1	lda VCOUNT
		cmp #$3
		bne VCL1
TSTMAX	lda VCOUNT
		cmp #$8A
		bne VCL2
		sta RAMPROC+LICNT-ZEROCP+1
VCL2	cmp #$00
		bne TSTMAX
		rts
		
;-----------------------------------------------------------------------		
; LEAVE CART SPACE
		
BYEBYE	jmp RAMPROC+GOBOOT-ZEROCP

;-----------------------------------------------------------------------		
; SIO INTerface

SIOCPY
.local SIOINT,$C933

CRITIC  = $42
DSTATS  = $0303
DUNIT   = $0301
GETLOW  = $C9AF
PDIOR   = $D805
PDVMSK  = $0247
PDVREG  = $D1FF
PDVRS   = $0248
SIO     = $E971

		lda #$01
		sta CRITIC
		lda DUNIT
		pha
		lda PDVMSK
		beq FOUND
		ldx #$08
NEXT 	jsr RAMPROC	; jsr GETLOW
		beq END 	; beq FOUND
		txa
		pha
		jsr PDIOR
		pla
		tax
		bcc NEXT
		lda #$00
		sta PDVRS
		sta PDVREG
		beq END
FOUND 	jsr SIO
END 	pla
		sta DUNIT
		lda #$00
		sta CRITIC
		sty DSTATS
		ldy DSTATS
		rts
		
.end
ENDCPY	; --->>> $C96D

;-----------------------------------------------------------------------		
; RELOC CODE FOR RAMPROC

ZEROCP	lda VCOUNT
LICNT	cmp #$72		; $72->NTSC $8A->PAL
		bne ZEROCP		
		lda #$00		; TurnOn bank 0
		sta $D500
		jmp AROUND
		
		; --->>>CART<<<---

CPYSEC	txa	; $010F
		sta $D500,X
		lda (TMP),Y
		stx $D580	; JatariCart OFF
		sta (TMP+2),Y
		dey
		bpl CPYSEC
		
		ldy #$01
		sty DSTATS	
				
BACK	lda #$FF	; $0123
		sta $D580	; JatariCart OFF
		lda TRIG3
		sta GINTLK
		rts
		
GOBOOT	lda #$FF	; $012F
		sta $D580	; JatariCart OFF
		lda TRIG3
		sta GINTLK
		jsr BOOT
		jmp RESETWM
		
ZEROEND
;-----------------------------------------------------------------------		
; 	CLONE FOR ALL BANKS

		ORG $BF00

;-----------------------------------------------------------------------		
; AROUND SIO INTerface

AROUND	lda DCMND
		cmp #$52
		beq SECREAD
		cmp #$57
		beq STATOK
		cmp #$50
		beq STATOK
		cmp #$53
		bne UNKWCMD
STATOK	ldy #$01
		sty DSTATS
UNKWCMD	jmp RAMPROC+BACK-ZEROCP
SECREAD	ldy #$00
		sty $D500	; Bank 0
		
		lda DAUX1
		asl 
		sta TMP
		lda DAUX2
		rol
		and #$1F
		clc
		adc #$A0
		sta TMP+1
		
		lda (TMP),Y
		sta TMP+2
		iny
		lda (TMP),Y
		sta TMP+3
		
		and #$01
		beq NOHALF
		lda #$80
NOHALF	sta TMP

		lda TMP+3
		lsr
		clc
		adc #$A0
		sta TMP+1

		lda TMP+2	; Bank -> X
		and #$7F
		tax		
		
		lda DBUFA
		sta TMP+2
		lda DBUFA+1
		sta TMP+3	

		ldy #$7F
		jmp RAMPROC+CPYSEC-ZEROCP

;-----------------------------------------------------------------------		

		ORG $BFF6

;-----------------------------------------------------------------------		
; INITCART ROUTINE

INIT	sta $D500
		rts

;-----------------------------------------------------------------------		

		ORG $BFFA
		dta <BEGIN, >BEGIN, $00, $04, <INIT, >INIT

;-----------------------------------------------------------------------		
