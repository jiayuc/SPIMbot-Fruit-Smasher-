# syscall constants
PRINT_STRING  = 4

# spimbot constants
VELOCITY      = 0xffff0010
ANGLE         = 0xffff0014
ANGLE_CONTROL = 0xffff0018
BOT_X         = 0xffff0020
BOT_Y         = 0xffff0024
PRINT_INT     = 0xffff0080
OTHER_BOT_X   = 0xffff00a0
OTHER_BOT_Y   = 0xffff00a4

BONK_MASK     = 0x1000
BONK_ACK      = 0xffff0060

SCAN_X        = 0xffff0050
SCAN_Y        = 0xffff0054
SCAN_RADIUS   = 0xffff0058
SCAN_ADDRESS  = 0xffff005c
SCAN_MASK     = 0x2000
SCAN_ACK      = 0xffff0064

TIMER         = 0xffff001c
TIMER_MASK    = 0x8000
TIMER_ACK     = 0xffff006c

# fruit constants
FRUIT_SCAN	= 0xffff005c
FRUIT_SMASH	= 0xffff0068

SMOOSHED_MASK	= 0x2000
SMOOSHED_ACK	= 0xffff0064

# .text
# main:
# 	# go wild
# 	# the world is your oyster
# 	jr	$ra


# step 1: allocate static memory in the .data section
.align 2
fruit_data: .space 260
num_smooshed: .space 4

.text
main:
	li  $s6, 0
	sw  $s6, num_smooshed 
	# enable interrupts
	li	$t4, TIMER_MASK		# timer interrupt enable bit
	or  $t4, SMOOSHED_MASK # added, enable fruit_smooshed interrupt 

	or	$t4, $t4, BONK_MASK	# bonk interrupt bit
	or	$t4, $t4, 1		# global interrupt enable
	mtc0	$t4, $12		# set interrupt mask (Status register)


	# sub $sp, $sp, 28
	# sw  $s0, 0($sp) # temp val
	# sw  $s1, 4($sp) # x
	# sw  $s2, 8($sp) # y 
	# sw  $s3, 12($sp)# temp2
	# sw  $s4, 16($sp) # fruit_id 
	# sw  $s5, 20($sp) # fruit_x
	# sw  $s6, 24($sp)


# go to bottom mid of screen
go_down:
	li 	$s0, 90
	sw  $s0, ANGLE
	li  $s0, 4
	sw	$s0, VELOCITY
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL
# get the y coordinate
keep_walking:
    lw  $s2, BOT_Y

    li  $s3, 280
    ble $s2, $s3, keep_walking
    j   chase_fruit

chase_fruit:
# step 2: load the address of this memory into register
	la  $t0, fruit_data
# step 3: Write this address to the FRUIT_SCAN memory I/O to tell SPIMbot where the fruit array should be stored
	sw  $t0, FRUIT_SCAN
    lw  $s2, BOT_Y
# check see if num_smooshed > 5, time to smash fruit?
	lw  $s0, num_smooshed
	bge $s0, 5, smash_fruit


	lw  $s4, 0($t0) # fruit id
    beq $s4, $0, chase_fruit
	lw  $s5, 8($t0) # fruit_x
    lw  $s1, BOT_X
    bgt $s5, $s1, turn_to_right # fruit at right
    blt $s5, $s1, turn_to_left
    j   chase_fruit 

smash_fruit: 
# hit the bottom 
	li 	$s0, 90
	sw  $s0, ANGLE
	li  $s0, 10
	sw	$s0, VELOCITY
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL

keep_walking_till_bonk:
    lw  $s0, num_smooshed
	bge $s0, 5, keep_walking_till_bonk
    # walk back to normal routine to catch fruit
go_up:
	li 	$s0, 270
	sw  $s0, ANGLE
	li  $s0, 10
	sw	$s0, VELOCITY
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL
# get the y coordinate
keep_walking_up:
    lw  $s2, BOT_Y
    li  $s3, 295
    bge $s2, $s3, keep_walking
    j   chase_fruit


turn_to_left:
	li 	$s0, 180
	sw  $s0, ANGLE
	li  $s0, 10
	sw	$s0, VELOCITY
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL	

keep_walking2:
    lw  $s1, BOT_X
    blt $s1, $s5, keep_walking2
    j   chase_fruit

turn_to_right:    
	li 	$s0, 0
	sw  $s0, ANGLE
	li  $s0, 10
	sw	$s0, VELOCITY
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL	

keep_walking3:
    lw  $s1, BOT_X
    bgt $s1, $s5, keep_walking3
    j   chase_fruit





.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for two registers
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"


.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers                  
	sw	$a1, 4($k0)		# by storing them to a global variable     

	mfc0 $k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2               
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:			# Interrupt:                             
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts     

	and	$a0, $k0, BONK_MASK	# is there a bonk interrupt?                
	bne	$a0, 0, bonk_interrupt   

	and	$a0, $k0, SMOOSHED_MASK	# is there a fruit_smooshed interrupt?
	bne	$a0, 0, smooshed_interrupt

	and	$a0, $k0, TIMER_MASK	# is there a timer interrupt?
	bne	$a0, 0, timer_interrupt

	# add dispatch for other interrupt types here.

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

smooshed_interrupt:
    sw	$a1, SMOOSHED_ACK	
	lw  $s6, num_smooshed
    add $s6, $s6, 1
	# sw	$zero, VELOCITY		# ???s
    sw  $s6, num_smooshed

 	j	interrupt_dispatch	# see if other interrupts are waiting  

bonk_interrupt:
	sw  $s6, num_smooshed
	beq $s6, $0, acknowledge_bonk
# num_smooshed is not 0, keep smashing
	sw  $s6, FRUIT_SMASH
	add $s6, $s6, -1
	j   bonk_interrupt

acknowledge_bonk:
	sw	$a1, BONK_ACK		# acknowledge interrupt
	sw	$zero, VELOCITY		# to be deleted!!
	j	interrupt_dispatch	# see if other interrupts are waiting

timer_interrupt:
	sw	$a1, TIMER_ACK		# acknowledge interrupt

	li	$t0, 90			# ???
	sw	$t0, ANGLE		# ???
	sw	$zero, ANGLE_CONTROL	# ???

	lw	$v0, TIMER		# current time
	add	$v0, $v0, 50000  
	sw	$v0, TIMER		# request timer in 50000 cycles

	j	interrupt_dispatch	# see if other interrupts are waiting

non_intrpt:				# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret
