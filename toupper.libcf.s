#PURPOSE:	This program converts an input file to an output file with all letters
#		converted to uppercase.
#
#PROCESSING:	1) Open the input file
#		2) Open the output file
#		4) While we're not at the end of the input file
#		 a) read a part of file into memory buffer
#		 b) go through each byte of memory
#			if the byte is a lower-case letter convert to uppercase
#		 c) write the memory buffer to output file
#
#USES LIBC functions to open, read, write and close the files.
#
#USAGE	./toupper <input_file_name> <output_file_name>

.section .data
##CONSTANTS##

 #system call numbers
 .equ SYS_OPEN, 5
 .equ SYS_WRITE, 4
 .equ SYS_READ, 3
 .equ SYS_CLOSE, 6
 .equ SYS_EXIT, 1

 #options for open
 #(Look at /usr/include/asm/fcntl.h for various values.
 #You can combine them by adding them or ORing them)
 #This is discussed at greater length in "Counting Like a Computer"
 .equ O_RDONLY, 0
 .equ O_CREAT_WRONLY_TRUNC, 03101

 #standard file descriptors
 .equ STDIN, 0
 .equ STDOUT, 1
 .equ STDERR, 2

 #system call interrupt
 .equ LINUX_SYSCALL, 0x80

 .equ END_OF_FILE, 0 #This is the return value of read, which means we've hit the end of the file

 .equ NUMBER_ARGUMENTS, 2	#Number of arguments expected by the program

 #fopen modes
fopen_r:
 .ascii "r/0"

fopen_w:
 .ascii "w/0"


.section .bss
#Buffer - This is where the data is loaded into from the data file
#	  and written into the output file. This should never exceed
#	  16,000 for various reasons.
.equ BUFFER_SIZE, 500
.lcomm BUFFER_DATA, BUFFER_SIZE


.section .text

#STACK POSITIONS
#Offset from ebp where we expect the listed data to be.
 .equ ST_STACK_RESERVE, 8
 .equ ST_FD_IN, -4
 .equ ST_FD_OUT, -8
 .equ ST_ARGC, 0		#Number of argmuments
 .equ ST_ARGV_0, 4	#Name of the program
 .equ ST_ARGV_1, 8	#Input file name
 .equ ST_ARGV_2, 12	#Output file name


.globl _start
_start:
###INITIALIZE PROGRAM###
#save the stack pointer
 movl	%esp, %ebp

#Allocate space for file descriptors on the stack
 subl	$ST_STACK_RESERVE, %esp

open_files:
open_fd_in:
 ###OPEN INPUT FILE###
# FILE *fopen(const char *pathname, const char *mode);
 pushl	$fopen_r
 pushl	ST_ARGV_1(%ebp)
 call	fopen
 addl	$8, %esp
 #File * is returned in %eax

store_fd_in:
 movl %eax, ST_FD_IN(%ebp)	#save the given file descriptor in the stack

open_fd_out:
 ###OPEN OUTPUT FILE###
# FILE *fopen(const char *pathname, const char *mode);
 pushl $fopen_w             # mode_t or permissions
 pushl ST_ARGV_2(%ebp)
 call	fopen
 addl	$8, %esp

store_fd_out:
 movl %eax, ST_FD_OUT(%ebp)	#save the FILE * to the stack

###MAIN LOOP###
read_loop_begin:
 #Read in a block from the input file#
# char *fgets(char *s, int size, FILE *stream);
 pushl	ST_FD_IN(%ebp)
 pushl	$BUFFER_SIZE
 pushl	$BUFFER_DATA
 call   fgets           #Returns File * if okay or NULL
 addl	$12, %esp

 #Exit if we've reached the end#
 cmpl $END_OF_FILE, %eax    # END_OF_FILE is 0x00	
 jle  end_loop			#if found or error, go to the end

continue_read_loop:
 #Convert the block to upper case#
 pushl $BUFFER_DATA		#location of buffer
 pushl $BUFFER_SIZE			#size of the buffer
 call  convert_to_upper
 addl  $8, %esp			#restore %esp

 #write the block out to the output file#
 #int fputs(const char *s, FILE *stream);

 pushl	ST_FD_OUT(%ebp)
 pushl	$BUFFER_DATA		#location of the buffer
 call	fputs
 addl	$8, %esp

 #Continue the loop#
 jmp	read_loop_begin

end_loop:
 #Close the files#
 #Note:	we don't need to do error checking on these, becaues error conditions
 #	don't signify anything special here
 # int fclose(FILE *stream);
 pushl	ST_FD_IN(%ebp)
 call	fclose
 addl	$4, %esp

 pushl	ST_FD_OUT(%ebp)
 call	fclose
 addl	$4, %esp

 #EXIT#
 movl	$SYS_EXIT, %eax
 movl	$0, %ebx		#exit code
 int	$LINUX_SYSCALL


#PURPOSE:	This functino converts the chars in the block to upper case.
#
#INPUT:		First parameter: location of the block memory to convert
#		Second parameter: Length of that buffer (block)
#
#OUTPUT:	This function overwrites the current buffer with the upper-casified version.
#
#VARIABLES:
#		%eax - beginning of buffer
#		%ebx - length of buffer
#		%edi - current buffer offset
#		%cl  - current byte being examined (lower 8 bits of %ecx)

#CONSTANTS#
.equ LOWERCASE_A, 'a'		#the lower boundary of our search
.equ LOWERCASE_Z, 'z'		#the upper boundary of our search
.equ UPPER_CONVERSION, 'A' - 'a'	#Conversion between upper and lower case

#STACK STUFF#
.equ ST_BUFFER_LEN, 8		#length of buffer
.equ ST_BUFFER, 12		#address of buffer

convert_to_upper:
 pushl	%ebp			#stack initialization
 movl	%esp, %ebp

 #VARIABLE SET UP#
 movl	ST_BUFFER(%ebp), %eax
 movl	ST_BUFFER_LEN(%ebp), %ebx
 xor	%edi, %edi		#zero the buffer offset

 #if a buffer with zero length was given, leave
 cmpl	$0, %ebx
 je	end_convert_loop

convert_loop:
 movb	(%eax, %edi, 1), %cl	#get the current byte

 #go to the next byte unless %cl is between 'a' and 'z'
 cmpb	$LOWERCASE_A, %cl
 jl	next_byte
 cmpb	$LOWERCASE_Z, %cl
 jg	next_byte

 #otherwise convert the byte to uppercase
 addb	$UPPER_CONVERSION, %cl
 movb	%cl, (%eax, %edi, 1)	#store it back to the buffer

next_byte:
 incl	%edi
 cmpl	%edi, %ebx	#continue unless we've reached the end
 jne	convert_loop

end_convert_loop:
 #no return value, just leave
  movl	%ebp, %esp
  popl	%ebp
  ret
