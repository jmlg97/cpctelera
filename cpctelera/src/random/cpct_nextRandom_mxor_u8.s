;;-----------------------------LICENSE NOTICE------------------------------------
;;  This file is part of CPCtelera: An Amstrad CPC Game Engine 
;;  Copyright (C) 2015 ronaldo / Fremos / Cheesetea / ByteRealms (@FranGallegoBR)
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;-------------------------------------------------------------------------------
.module cpct_random

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Function: cpct_nextRandom_mxor_u8
;;
;;    Calculates next 32-bits state for a Marsaglia's XOR-Shift pseudo-random 
;; 8-bits generator. 
;;
;; C Definition:
;;    <u32> <cpct_nextRandom_mxor_u8> (<u32> *seed*) __z88dk_fastcall;
;;
;; Input Parameters (4 bytes):
;;    (4B DE:HL) *state* - Previous state that the XOR-Shift algorithm will use 
;; to calculate its follower in the sequence.
;;
;; Assembly call (Input parameter on DE:HL):
;;    > call cpct_nextRandom_mxor_u8_asm
;;
;; Return value:
;;    <u32> - Next internal state of the pseudo-random generator. The 8 Least Significant
;; bits of this state are the 8 pseudo-random bits generated by this call.
;;
;; Parameter Restrictions:
;;    * *state* could be any 32-bits number *except 0*. A 0 as input will always produce
;; another 0 as output.
;;
;; Important details:
;;    * This function calculates next state in a 32-bits sequence that goes over all 32-bits
;; possible states except 0. Therefore, it has a repeating period of (2^32)-1. The walk this 
;; function does has a high pseudo-random quality, measured using <Dieharder tests at
;; https://en.wikipedia.org/wiki/Diehard_tests>: (94 passed, 9 weak, 11 failed). Giving
;; 3 points per passed test and 1 point per weak result, the algorithm gets 291 out of 342
;; points (85.09%).
;;
;; Details:
;;   This function implements a sequence of 32-bits states with period (2^32)-1. For each 
;; produced state, a random sequence of 8-bits is returned. This means that it produces 
;; consecutive 8-bits values that do not repeat until 4.294.967.295 numbers have been 
;; generated. To do this, the function receives a 32-bit state as parameter (that
;; should be different from 0) and returns the next 32-bit value in the sequence. In
;; each returned state, the 8 Least Significant bits are the 8 pseudo-random bits
;; produced.
;;
;;   The sequence calculated by this function is based on a modified version of 
;; <Marsaglia's XOR-shift generator at http://www.jstatsoft.org/article/view/v008i14/xorshift.pdf> 
;; using the tuple (1, 1, 3) for 8-bit values. This tuple is implemented really fast 
;; on a Z80 (as <originally showed by Patrik Rak at http://www.worldofspectrum.org/forums/discussion/23070/redirect/p1>). 
;; Assuming that the 32-bits state s is composed of 4 8-bits numbers s=(x, z, y, w), 
;; this algorithm produces a new state s'=(x',z',y',w') doing these operations:
;; (start code)
;;   x' = y;
;;   y' = z;
;;   z' = w;
;;   t  = x ^ (x >> 1);
;;   t' = t ^ (t << 1);
;;   w' = w ^ (w << 3) ^ t';
;; (end code)
;;
;;   This operations are performed in an optimized fashion. 
;;
;; Destroyed Register values: 
;;      AF, BC, DE, HL
;;
;; Required memory:
;;      17 bytes
;;
;; Time Measures:
;; (start code)
;;    Case     | microSecs (us) | CPU Cycles
;; -----------------------------------------
;;    Any      |      19        |    76
;; -----------------------------------------
;; (end code)
;;
;; Random quality measures:
;;  * Dieharder tests rank: (94 Pass, 9 Weak, 11 Failed) (291/342 = 85.09%)
;;  * Pseudo-random bit stream velocity: 2,375 us / bit. (8 bits produced in 19 us)
;;
;; Credits:
;;   * Original <XOR-shifting algorithm published by George Marsaglia at 
;; http://www.jstatsoft.org/article/view/v008i14/xorshift.pdf>
;;   * Initial code for this 8-bits version from Patrik Rak 
;; (<World of Spectrum forums at http://www.worldofspectrum.org/forums/discussion/23070/redirect/p1>)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_cpct_nextRandom_mxor_u8::
cpct_nextRandom_mxor_u8_asm::
   ;; INPUT:
   ;;  DE:HL == xz yw  (32 bits state)
   ;;  xz yw -> yw zt ==> x'z' = yw, y' = z, w' = t
   ;;  
   ;; OUTPUT:
   ;;  DE:HL == x'z' y'w' (new 32 bits state, L = w' = 8 random bits generated) 

   ;; Move old bytes of the state. DE:HL is now xz yw
   ;; Interchanging it makes DE:HL be yw xz, leaving x' and z' in DE 
   ex  de, hl  ;; [1]  x' = y, z' = w

   ;; First calculate w ^ (w << 3) as it is 
   ;; and independent operation and does not require 
   ;; carry to be resetted first
   ld   a, e   ;; [1] A = w
   add  a      ;; [1]
   add  a      ;; [1]
   add  a      ;; [1] A = (w << 3)
   xor  e      ;; [1] A = w ^ (w << 3)
   ld   c, a   ;; [1] C = w ^ (w << 3) (Saved for later use)

   ;; Thanks to previous operation, Carry is now resetted, and
   ;; We are now able to calculate t = x ^ (x >> 1) and 
   ;; t' = t ^ (t << b) easier
   
   ;; Calculate t = x ^ (x >> 1)
   ld   a, h   ;; [1] A = x
   rra         ;; [1] A = (x >> 1)
   xor  h      ;; [1] A = t = x ^ (x >> 1)
   ld   h, a   ;; [1] H = t
   
   ;; Calculate t = t ^ (t << 1)
   add  a      ;; [1] A = (t << 1)  (A already contained t)
   xor  h      ;; [1] A = t' = t ^ (t << 1)

   ;; Finally calculate w' easily 
   xor  c      ;; [1] A = w' = w ^ (w << c) ^ t'

   ;; Store y' and w' and return
   ld   h, l   ;; [1] H = y' = z
   ld   l, a   ;; [1] L = w'

   ret         ;; [3] New state is returned in DE:HL, being L the 8 random bits generated
