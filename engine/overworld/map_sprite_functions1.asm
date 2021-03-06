_UpdateSprites:
	ld h, $c1
	inc h		; h = $c2
	ld a, $e    ; wSpriteStateData2 + $0e

; 各スプライトの更新処理
; $c2XeのXの値でどのスプライトを処理しているかわかる(0 <= X < 16)
.spriteLoop
	ld l, a		; hl = $c2Xe = (wSpriteStateData2 + $Xe)
	sub $e
	ld c, a
	ld [H_CURRENTSPRITEOFFSET], a

	; $c2Xeが0ならスプライトの更新をスキップ
	ld a, [hl]
	and a
	jr z, .skipSprite

	; レジスタを退避してスプライトの更新処理
	push hl
	push de
	push bc
	call .updateCurrentSprite
	; レジスタを復帰
	pop bc
	pop de
	pop hl

; スプライトの更新をスキップ
.skipSprite
	ld a, l
	add $10             ; 16バイト足して次のスプライトのデータを指すようにする
	; すべてのスプライトの更新処理が終わればオーバーフローして$0eに戻っている
	cp $e               
	jr nz, .spriteLoop
	ret

; スプライトの更新処理
.updateCurrentSprite
	; 主人公は常にc2Xeが1
	cp $1
	jp nz, UpdateNonPlayerSprite
	jp UpdatePlayerSprite

; **UpdateNonPlayerSprite**
;  
; NPCスプライトの移動処理を行う関数  
; a: $c2Xeの値
UpdateNonPlayerSprite:
	; UpdateSpriteImageで利用するためにスプライト番号を$ff93に保存
	dec a
	swap a
	ld [$ff93], a  ; $10 * sprite#

	; 更新対象のスプライトが"Scripted NPC"かで更新処理を分岐
	ld a, [wNPCMovementScriptSpriteOffset]
	ld b, a
	ld a, [H_CURRENTSPRITEOFFSET]			 
	cp b
	jr nz, .unequal
	jp DoScriptedNPCMovement				; Scripted NPCのとき
.unequal
	jp UpdateNPCSprite

; 現在処理中のスプライトが他のスプライトと衝突することになるかどうか他のスプライトを1つ1つ見ていくことで確認する  
; 現在処理中のスプライトのオフセットはiでラベル付けされる(e.g. $c1i0)  
; 1つ1つ確認しているスプライトのオフセットはj(e.g. $c1j0)  
;
; スプライトのY座標([$c1k4])はスプライトがgridにすっぽりおさまるように配置されているときには$fc, $0c, $1c, $2c, ... $7cの
; どれかの値になることに注意  
; Y座標から4を引くのは、比較を容易にするために、$10の倍数に合わせて調整するため
DetectCollisionBetweenSprites:
	nop

	; hl = $c1i0
	ld h, wSpriteStateData1 / $100
	ld a, [H_CURRENTSPRITEOFFSET]
	add wSpriteStateData1 % $100
	ld l, a

	; オフセットiのスプライトが有効でないなら戻る
	ld a, [hl] ; a = [$c1i0] (picture) (0 if slot is unused)
	and a ; is this sprite slot slot used?
	ret z ; return if not used

	; hl = $c1i3
	ld a, l
	add 3
	ld l, a

	ld a, [hli] ; a = [$c1i3] (delta Y) (-1, 0, or 1)
	call SetSpriteCollisionValues

	; a = Y座標
	ld a, [hli] ; a = [$C1i4] (Y screen coordinate)
	add 4 ; グリッドに合わせる

	; 次の3行のコードで南に移動するならaレジスタに+7 北に移動するならaレジスタから-7している
	add b
	and $f0
	or c

	ld [$ff90], a ; store Y coordinate adjusted for direction of movement

	; 次はX方向
	ld a, [hli] ; a = [$c1i5] (delta X) (-1, 0, or 1)
	call SetSpriteCollisionValues
	ld a, [hl] ; a = [$C1i6] (X screen coordinate)

	; 次の3行のコードで東に移動するならaレジスタに+7 西に移動するならaレジスタから-7している
	add b
	and $f0
	or c

	ld [$ff91], a ; store X coordinate adjusted for direction of movement

	; hl = $C1id
	ld a, l
	add 7
	ld l, a

	xor a
	ld [hld], a ; [$c1id] = 0
	ld [hld], a ; [$c1ic] = 0 (directions in which collisions occurred)

	; [$ff91] = [$c1id] = adjusted X coordinate
	ld a, [$ff91]
	ld [hld], a
	; [$ff90] = [$c1ia] = adjusted Y coordinate
	ld a, [$ff90]
	ld [hl], a

	xor a ; zero the loop counter

.loop
	ld [$ff8f], a ; store loop counter
	swap a
	ld e, a
	ld a, [H_CURRENTSPRITEOFFSET]
	cp e ; does the loop sprite match the current sprite?
	jp z, .next ; go to the next sprite if they match

	ld d, h
	ld a, [de] ; a = [$c1j0] (picture) (0 if slot is unused)
	and a ; is this sprite slot slot used?
	jp z, .next ; go the next sprite if not used

	inc e
	inc e
	ld a, [de] ; a = [$c1j2] ($ff means the sprite is offscreen)
	inc a
	jp z, .next ; go the next sprite if offscreen

	ld a, [H_CURRENTSPRITEOFFSET]
	add 10
	ld l, a

	inc e
	ld a, [de] ; a = [$c1j3] (delta Y)
	call SetSpriteCollisionValues

	inc e
	ld a, [de] ; a = [$C1j4] (Y screen coordinate)
	add 4 ; align with multiple of $10

; The effect of the following 3 lines is to
; add 7 to a if moving south or
; subtract 7 from a if moving north.
	add b
	and $f0
	or c

	sub [hl] ; subtract the adjusted Y coordinate of sprite i ([$c1ia]) from that of sprite j

; calculate the absolute value of the difference to get the distance
	jr nc, .noCarry1
	cpl
	inc a
.noCarry1
	ld [$ff90], a ; store the distance between the two sprites' adjusted Y values

; Use the carry flag set by the above subtraction to determine which sprite's
; Y coordinate is larger. This information is used later to set [$c1ic],
; which stores which direction the collision occurred in.
; The following 5 lines set the lowest 2 bits of c, which are later shifted left by 2.
; If sprite i's Y is larger, set lowest 2 bits of c to 10.
; If sprite j's Y is larger or both are equal, set lowest 2 bits of c to 01.
	push af
	rl c
	pop af
	ccf
	rl c

; If sprite i's delta Y is 0, then b = 7, else b = 9.
	ld b, 7
	ld a, [hl] ; a = [$c1ia] (adjusted Y coordinate)
	and $f
	jr z, .next1
	ld b, 9

.next1
	ld a, [$ff90] ; a = distance between adjusted Y coordinates
	sub b
	ld [$ff92], a ; store distance adjusted using sprite i's direction
	ld a, b
	ld [$ff90], a ; store 7 or 9 depending on sprite i's delta Y
	jr c, .checkXDistance

; If sprite j's delta Y is 0, then b = 7, else b = 9.
	ld b, 7
	dec e
	ld a, [de] ; a = [$c1j3] (delta Y)
	inc e
	and a
	jr z, .next2
	ld b, 9

.next2
	ld a, [$ff92] ; a = distance adjusted using sprite i's direction
	sub b ; adjust distance using sprite j's direction
	jr z, .checkXDistance
	jr nc, .next ; go to next sprite if distance is still positive after both adjustments

.checkXDistance
	inc e
	inc l
	ld a, [de] ; a = [$c1j5] (delta X)

	push bc

	call SetSpriteCollisionValues
	inc e
	ld a, [de] ; a = [$c1j6] (X screen coordinate)

; The effect of the following 3 lines is to
; add 7 to a if moving east or
; subtract 7 from a if moving west.
	add b
	and $f0
	or c

	pop bc

	sub [hl] ; subtract the adjusted X coordinate of sprite i ([$c1ib]) from that of sprite j

; calculate the absolute value of the difference to get the distance
	jr nc, .noCarry2
	cpl
	inc a
.noCarry2
	ld [$ff91], a ; store the distance between the two sprites' adjusted X values

; Use the carry flag set by the above subtraction to determine which sprite's
; X coordinate is larger. This information is used later to set [$c1ic],
; which stores which direction the collision occurred in.
; The following 5 lines set the lowest 2 bits of c.
; If sprite i's X is larger, set lowest 2 bits of c to 10.
; If sprite j's X is larger or both are equal, set lowest 2 bits of c to 01.
	push af
	rl c
	pop af
	ccf
	rl c

; If sprite i's delta X is 0, then b = 7, else b = 9.
	ld b, 7
	ld a, [hl] ; a = [$c1ib] (adjusted X coordinate)
	and $f
	jr z, .next3
	ld b, 9

.next3
	ld a, [$ff91] ; a = distance between adjusted X coordinates
	sub b
	ld [$ff92], a ; store distance adjusted using sprite i's direction
	ld a, b
	ld [$ff91], a ; store 7 or 9 depending on sprite i's delta X
	jr c, .collision

; If sprite j's delta X is 0, then b = 7, else b = 9.
	ld b, 7
	dec e
	ld a, [de] ; a = [$c1j5] (delta X)
	inc e
	and a
	jr z, .next4
	ld b, 9

.next4
	ld a, [$ff92] ; a = distance adjusted using sprite i's direction
	sub b ; adjust distance using sprite j's direction
	jr z, .collision
	jr nc, .next ; go to next sprite if distance is still positive after both adjustments

.collision
	ld a, [$ff91] ; a = 7 or 9 depending on sprite i's delta X
	ld b, a
	ld a, [$ff90] ; a = 7 or 9 depending on sprite i's delta Y
	inc l

; If delta X isn't 0 and delta Y is 0, then b = %0011, else b = %1100.
; (note that normally if delta X isn't 0, then delta Y must be 0 and vice versa)
	cp b
	jr c, .next5
	ld b, %1100
	jr .next6
.next5
	ld b, %0011

.next6
	ld a, c ; c has 2 bits set (one of bits 0-1 is set for the X axis and one of bits 2-3 for the Y axis)
	and b ; we select either the bit in bits 0-1 or bits 2-3 based on the calculation immediately above
	or [hl] ; or with existing collision direction bits in [$c1ic]
	ld [hl], a ; store new value
	ld a, c ; useless code because a is overwritten before being used again

; set bit in [$c1ie] or [$c1if] to indicate which sprite the collision occurred with
	inc l
	inc l
	ld a, [$ff8f] ; a = loop counter
	ld de, SpriteCollisionBitTable
	add a
	add e
	ld e, a
	jr nc, .noCarry3
	inc d
.noCarry3
	ld a, [de]
	or [hl]
	ld [hli], a
	inc de
	ld a, [de]
	or [hl]
	ld [hl], a

.next
	ld a, [$ff8f] ; a = loop counter
	inc a
	cp $10
	jp nz, .loop
	ret

; aレジスタのXかYの座標変化量(delta X/Y)を見てbとcに値を格納
; 
; b = delta X/Y  
; c = 0 if (delta X/Y == 0)  
; c = 7 if (delta X/Y == 1)  
; c = 9 if (delta X/Y == -1)  
SetSpriteCollisionValues:
	; delta X/Yが0
	and a
	ld b, 0
	ld c, 0
	jr z, .done ; aが0なら.done
	; delta X/Yが-1
	ld c, 9
	cp -1
	jr z, .ok
	; delta X/Yが1
	ld c, 7
	ld a, 0
.ok
	ld b, a
.done
	ret

SpriteCollisionBitTable:
	db %00000000,%00000001
	db %00000000,%00000010
	db %00000000,%00000100
	db %00000000,%00001000
	db %00000000,%00010000
	db %00000000,%00100000
	db %00000000,%01000000
	db %00000000,%10000000
	db %00000001,%00000000
	db %00000010,%00000000
	db %00000100,%00000000
	db %00001000,%00000000
	db %00010000,%00000000
	db %00100000,%00000000
	db %01000000,%00000000
	db %10000000,%00000000
