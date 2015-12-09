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

ENERGY_OUT_MASK = 0x4000
ENERGY_OUT_ACK  = 0xffff00c4

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

REQUEST_MASK = 0x800
REQUEST_ACK  = 0xffff00d8

REQUEST_WORD    = 0xffff00dc
REQUEST_PUZZLE = 0xffff00d0

SUBMIT_SOLUTION = 0xffff00d4
GET_ENERGY	= 0xffff00c8

# step 1: allocate static memory in the .data section
.data

num_rows: .space 4 
num_cols: .space 4

directions:
	.word -1  0
	.word  0  1
	.word  1  0
	.word  0 -1

.align 2
fruit_data: .space 260
# num_smooshed: .space 4

.align 2
puzzle_space:  .space 8192

.align 2
word_space:  .space 128

.align 2
node_space: .space 4096


NODE_SIZE = 12

# Stores the address for the next node to allocate
new_node_address: .word node_memory
# Don't put anything below this just in case they malloc more than 4096
node_memory: .space 4096


#---------------------FRUIT------------------------------
 .text
main:
	li  $t6, 1  #flag is 0 when solving puzzle, once 1 we should request new puzzle
	li  $s6, 0
	# sw  $s6, num_smooshed 
	# enable interrupts
	# li	$t4, TIMER_MASK		# timer interrupt enable bit
	or  $t4, SMOOSHED_MASK  # added, enable fruit_smooshed interrupt 

	# or  $t4, $t4, ENERGY_OUT_MASK
	or  $t4, $t4, REQUEST_MASK
	or	$t4, $t4, BONK_MASK	# bonk interrupt bit
	or	$t4, $t4, 1		# global interrupt enable
	mtc0	$t4, $12		# set interrupt mask (Status register)

# go to bottom mid of screen
# go_down:
# 	li 	$s0, 90
# 	sw  $s0, ANGLE
# 	li  $s0, 1
# 	sw	$s0, ANGLE_CONTROL
# 	li  $s0, 4
# 	sw	$s0, VELOCITY

# # get the y coordinate
# keep_walking:
#     lw  $s2, BOT_Y
#     li  $s3, 200
#     ble $s2, $s3, keep_walking

#     j   chase_fruit

regenerate:
# step 2: load the address of this memory into register
	la  $s7, puzzle_space
# step 3: Write this address to the FRUIT_SCAN memory I/O to tell SPIMbot where the fruit array should be stored
	sw  $s7, REQUEST_PUZZLE
	li  $t6, 0 #stop requesting puzzle
	j   chase_fruit_cont

chase_fruit:
	lw  $t1, GET_ENERGY
	bgt $t1, 100, chase_fruit_cont
	beq $t6, 1, regenerate # when t6 is 1, request new puzzle!

	
chase_fruit_cont:
# step 2: load the address of this memory into register
	la  $t0, fruit_data
# step 3: Write this address to the FRUIT_SCAN memory I/O to tell SPIMbot where the fruit array should be stored
	sw  $t0, FRUIT_SCAN
    lw  $s2, BOT_Y
# check see if num_smooshed > 5, time to smash fruit?
	# lw  $s0, num_smooshed
	bge $s6, 5, smash_fruit

	lw  $s4, 0($t0) # fruit id
    beq $s4, $0, chase_fruit

     
    lw  $s1  BOT_Y

    lw	$t1	 12($t0) #1_fruit_y
    ble $s1  $t1 second
	lw  $s5, 8($t0) # fruit_x
	j gogogo
second:
    lw	$t1	 28($t0) #2_fruit_y
    ble $s1  $t1 third
	lw  $s5, 24($t0) # fruit_x
	j gogogo
third:
    lw	$t1	 44($t0) #3_fruit_y
    ble $s1  $t1 chase_fruit
	lw  $s5, 40($t0) # fruit_x
	j gogogo
fourth:
    lw	$t1	 60($t0) #4_fruit_y
    ble $s1  $t1 fifth
	lw  $s5, 56($t0) # fruit_x
	j gogogo
fifth:
	lw  $t1, 76($t0) #5_fruit_y
    ble $s1  $t1 chase_fruit
	j gogogo


gogogo:
    lw  $s1, BOT_X
    bgt $s5, $s1, turn_to_right # fruit at right
    blt $s5, $s1, turn_to_left
    j   chase_fruit 

turn_to_left:
	li 	$s0, 180
	sw  $s0, ANGLE
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL	
	li  $s0, 10
	sw	$s0, VELOCITY

    j   chase_fruit

turn_to_right:    
	li 	$s0, 0
	sw  $s0, ANGLE
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL	
	li  $s0, 10
	sw	$s0, VELOCITY

    j   chase_fruit

smash_fruit: 
# hit the bottom 
	li 	$s0, 90
	sw  $s0, ANGLE
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL
	li  $s0, 10
	sw	$s0, VELOCITY

keep_walking_till_bonk:
    # lw  $s0, num_smooshed
	bge $s6, 5, keep_walking_till_bonk
    # walk back to normal routine to catch fruit
go_up:
	li 	$s0, 270
	sw  $s0, ANGLE
	li  $s0, 1
	sw	$s0, ANGLE_CONTROL
	li  $s0, 10
	sw	$s0, VELOCITY

# get the y coordinate
    li  $s3, 270
keep_walking_up:
    lw  $s2, BOT_Y
    bge $s2, $s3, keep_walking_up
   	li  $s0, 0
	sw	$s0, VELOCITY
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

	and	$a0, $k0, REQUEST_MASK	# is there a request_puzzle interrupt?
	bne	$a0, 0, request_interrupt

	# and	$a0, $k0, ENERGY_OUT_MASK	# is there a emergy out interrupt?
	# bne	$a0, 0, energy_interrupt

	# add dispatch for other interrupt types here.

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

smooshed_interrupt:
    sw	$a1, SMOOSHED_ACK	
	# lw  $s6, num_smooshed
    add $s6, $s6, 1
	# sw	$zero, VELOCITY		# ???s
    # sw  $s6, num_smooshed

 	j	interrupt_dispatch	# see if other interrupts are waiting  

bonk_interrupt:
	li $k0 BOT_X
	li $a0 294
	li $a1 5
	beq $a0 $k0 acknowledge_bonk
	beq $a1 $k0 acknowledge_bonk
	# sw  $s6, num_smooshed
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

	# li	$t0, 90			# ???
	# sw	$t0, ANGLE		# ???
	# sw	$zero, ANGLE_CONTROL	# ???

	lw	$v0, TIMER		# current time
	add	$v0, $v0, 50000  
	sw	$v0, TIMER		# request timer in 50000 cycles

	j	interrupt_dispatch	# see if other interrupts are waiting

request_interrupt:
	sw	$a1, REQUEST_ACK		# acknowledge interrupt

	# sw	$a1, REQUEST_ACK		# acknowledge interrupt
#request the word
	la $a1 word_space
	sw $a1 REQUEST_WORD

	la $t0 num_rows
	la $t1 num_cols

	la $t5 puzzle_space
	lw $t2 0($t5)		#read num_row
	lw $t3 4($t5)		#read num_col

	sw $t2 num_rows	    # put num_row into global variable num_rows
	sw $t3 num_cols		# put num_col into global variable num_cols

	# la $a0 8($t5)	
	add $a0, $t5, 8	

	li	$v0, 0			# Set $v0 to 0 to confirm actually returned non-zero
	li	$a2, 1
	li	$a3, 0
	jal	solve_puzzle ##char *puzzle, const char *word, int row, int col)
	sw  $v0, SUBMIT_SOLUTION

	#change new_node_address's value to node_memory's address
	la  $t0, node_memory
	sw  $t0, new_node_address
	 
	sw	$a1, REQUEST_ACK
	li  $t6, 1 # enable new request puzzle
	j interrupt_dispatch


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
###solve_puzzle##########################################

solve_puzzle:
	# Your code goes here :)
	sub		$sp,$sp,36	#allocate stack memory
	sw		$ra,0($sp)	
	sw		$s0,4($sp)	#exist
	sw		$s1,8($sp) 	#*puzzle
	sw		$s2,12($sp)	#word
	sw		$s3,16($sp)	#row	
	sw		$s4,20($sp)	#num_row
	sw		$s5,24($sp)	#col
	sw		$s6,28($sp)	#num_cols
	sw		$s7,32($sp)	#current_char
	
	
	move 	$s1,$a0		#puzzle
	move	$s2,$a1		#word
	li		$s3,0		#row
	lw		$s4,num_rows	#load num_row
	
	lw		$s6,num_cols	#load num_col
	
	lb		$t0,0($s2)	#word[0]

puzzle_firstif:
	bne		$t0,$0,not_if	#branch if !=0
	j		return_true	#return ra

not_if:
	bge		$s3,$s4,return_false #branch if!(row<num_rows)
	li		$s5,0		#col
	j		second_for

second_for:
	bge		$s5,$s6,not_secondfor	#branch if!(col<col_rows)
	move	$a0,$s1 	#puzzle
	move	$a1,$s3		#row 
	move	$a2,$s5		#col
	jal		get_char
	move	$s7,$v0		#current_char=get_char
	lb		$t1,0($s2)		#target_char=word[0]
	beq		$s7,$t1,second_if		#branch if current_char=target_char
	add		$s5,$s5,1	#col++
	j		second_for
not_secondfor:
	add		$s3,$s3,1	#row++
	j		not_if
	
	
second_if:
	move	$a0,$s1		#set_char(puzzle, row, col, '*');
	move	$a1,$s3
	move	$a2,$s5
	li		$a3,'*'
	jal		set_char
	
	move	$a0,$s1		#search_neighbors(puzzle, word + 1, row, col);
	add		$a1,$s2,1	#word+1
	move	$a2,$s3
	move	$a3,$s5
	jal		search_neighbors
	move	$s0,$v0		
	
	move	$a0,$s1				#set_char(puzzle, row, col, word[0]);
	move	$a1,$s3
	move	$a2,$s5
	move	$a3,$s2	#word[0]
	jal		set_char
	
	bne		$s0,$0,return_true 	#branch if exist==1
	add		$s5,$s5,1	#col++
	j		second_for
	
return_false:
	li	$v0,0
	j	puzzle_done

return_true:
	move	$a0,$s3		
	move	$a1,$s5
	move	$a2,$s0 
	jal		set_node						 # return set_node(row, col, node1);
	j	puzzle_done

puzzle_done:
	lw		$ra,0($sp)	
	lw		$s0,4($sp)	#exist
	lw		$s1,8($sp) 	#*puzzle
	lw		$s2,12($sp)	#word
	lw		$s3,16($sp)	#row	
	lw		$s4,20($sp)	#num_row
	lw		$s5,24($sp)	#col
	lw		$s6,28($sp)	#num_cols
	lw		$s7,32($sp)	#current_char
	add		$sp,$sp,36
	jr		$ra



#search_neighbors--------------------------
## Node *
## search_neighbors(char *puzzle, const char *word, int row, int col) {
##     if (word == NULL) {
##         return NULL;
##     }
##     for (int i = 0; i < 4; i++) {
##         int next_row = row + directions[i][0];
##         int next_col = col + directions[i][1];
##         // boundary check
##         if ((next_row > -1) && (next_row < num_rows) && (next_col > -1) &&
##             (next_col < num_cols)) {
##             if (puzzle[next_row * num_cols + next_col] == *word) {
##                 if (*(word + 1) == '\0') {
##                     return set_node(next_row, next_col, NULL);
##                 }
##                 // mark the spot on puzzle as visited
##                 puzzle[next_row * num_cols + next_col] = '*';
##                 // search for next char in the word
##                 Node *next_node =
##                     search_neighbors(puzzle, word + 1, next_row, next_col);
##                 // unmark
##                 puzzle[next_row * num_cols + next_col] = *word;
##                 // if there is a valid neighbor, return the linked list
##                 if (next_node) {
##                     return set_node(next_row, next_col, next_node);
##                 }
##             }
##         }
##     }
##     return NULL;
## }

search_neighbors:
	bne	$a1, 0, sn_main		# !(word == NULL)
	li	$v0, 0			# return NULL (data flow)
	jr	$ra			# return NULL (control flow)

sn_main:
	sub	$sp, $sp, 36
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)

	move	$s0, $a0		# puzzle
	move	$s1, $a1		# word
	move	$s2, $a2		# row
	move	$s3, $a3		# col
	li	$s4, 0			# i


sn_loop:
	mul	$t0, $s4, 8		# i * 8
	lw	$t1, directions($t0)	# directions[i][0]
	add	$s5, $s2, $t1		# next_row
	lw	$t1, directions+4($t0)	# directions[i][1]
	add	$s6, $s3, $t1		# next_col


##    if(next_row == num_rows)
##                next_row = 0;
##            if ( next_row == -1 )
##                next_row = num_rows - 1;
                
##            if(next_col == num_cols)
##                next_col = 0;
##            if ( next_col == -1 )
##                next_col = num_cols - 1;     
added:
	    lw    $t3, num_rows
	    lw    $t4,num_cols
	    beq   $s5,$t3,row_zero
	    beq   $s5,-1,row_num_rows
	    beq    $s6,$t4,col_zero
	    beq    $s6,-1,col_num_cols
	    j     sn_loop1
	    
	    
	row_zero:
	    move $s5,$0
	    j sn_loop1
	row_num_rows:
	    lw    $t2,num_rows
	    sub $t2,$t2,1
	    move    $s5,$t2
	    j sn_loop1
	col_zero:
	    move $s6,$0
	    j sn_loop1
	col_num_cols:
	    lw    $t2,num_cols
	    sub $t2,$t2,1
	    move $s6,$t2
	    j sn_loop1

sn_loop1:
	ble	$s5, -1, sn_next	# !(next_row > -1)
	lw	$t0, num_rows
	bge	$s5, $t0, sn_next	# !(next_row < num_rows)
	ble	$s6, -1, sn_next	# !(next_col > -1)
	lw	$t0, num_cols
	bge	$s6, $t0, sn_next	# !(next_col < num_cols)

	mul	$t0, $s5, $t0		# next_row * num_cols
	add	$t0, $t0, $s6		# next_row * num_cols + next_col
	add	$s7, $s0, $t0		# &puzzle[next_row * num_cols + next_col]
	lb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col]
	lb	$t1, 0($s1)		# *word
	bne	$t0, $t1, sn_next	# !(puzzle[next_row * num_cols + next_col] == *word)

	lb	$t0, 1($s1)		# *(word + 1)
	bne	$t0, 0, sn_search	# !(*(word + 1) == '\0')
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	li	$a2, 0			# NULL
	jal	set_node		# $v0 will contain return value
	j	sn_return

sn_search:
	li	$t0, '*'
	sb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col] = '*'
	move	$a0, $s0		# puzzle
	add	$a1, $s1, 1		# word + 1
	move	$a2, $s5		# next_row
	move	$a3, $s6		# next_col
	jal	search_neighbors
	lb	$t0, 0($s1)		# *word
	sb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col] = *word
	beq	$v0, 0, sn_next		# !next_node
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	move	$a2, $v0		# next_node
	jal	set_node
	j	sn_return

sn_next:
	add	$s4, $s4, 1		    # i++
	blt	$s4, 4, sn_loop		# i < 4
	li	$v0, 0			# return NULL (data flow)

sn_return:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	lw	$s7, 32($sp)
	add	$sp, $sp, 36
	jr	$ra


# Node *
# set_node(int row, int col, Node *next) {
#     // Call allocate_new_node() instead (see node_main.s)
#     Node *node = new Node();
#     node->row = row;
#     node->col = col;
#     node->next = next;
#     return node;
# }


# Gets char from a 2D array
# Arguments:
#	$a0: pointer to beginning of 2D array
#	$a1: row
#	$a2: col
# Returns: char at that location
.globl get_char
get_char:
	lw	$v0, num_cols
	mul	$v0, $a1, $v0	# row * num_cols
	add	$v0, $v0, $a2	# row * num_cols + col
	add	$v0, $a0, $v0	# &array[row * num_cols + col]
	lb	$v0, 0($v0)	# array[row * num_cols + col]
	jr	$ra

# Sets a char in a 2D array
# Arguments:
#	$a0: pointer to beginning of 2D array
#	$a1: row
#	$a2: col
#	$a3: char to store into array
# Returns: nothing
.globl set_char
set_char:
	lw	$v0, num_cols
	mul	$v0, $a1, $v0	# row * num_cols
	add	$v0, $v0, $a2	# row * num_cols + col
	add	$v0, $a0, $v0	# &array[row * num_cols + col]
	sb	$a3, 0($v0)	# array[row * num_cols + col] = c
	jr	$ra







.globl set_node
set_node:
	# Your code goes here :)
	sub $sp, $sp, 16
	sw	$ra, 0($sp)

	sw  $a0, 4($sp)
	sw  $a1, 8($sp)
	sw  $a2, 12($sp)

	jal  allocate_new_node
	
	lw  $a0, 4($sp)
	lw  $a1, 8($sp)
	lw  $a2, 12($sp)

	sw	 $a0, 0($v0)
	sw 	 $a1, 4($v0)
	sw	 $a2, 8($v0)

	lw	$ra, 0($sp)	
	add $sp, $sp, 16
	jr  $ra


# Allocates "memory" for a new node using the space in node_memory.
# Arguments: none
# Returns: pointer to new node
.globl allocate_new_node
allocate_new_node:
	lw	$v0, new_node_address
	add	$t0, $v0, NODE_SIZE
	sw	$t0, new_node_address
	jr	$ra
