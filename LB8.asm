.model tiny   
.code
org 100h   ;com-programm

start: 
jmp installer                       ;switch to installer
       
int15_old_offset dw ?         ;old offset  interrupt handler
int15_old_segment dw ?        ;old segment  interrupt handler
open_file_flag db 1           ;can open flag
open_error_flag db 0          ;cannot open file
screen_message_offset equ 120 + 160  ;offset for string on screen   (120+160(2-d string))
screen_offset equ 156 + 160        ;offset for scan code      (156 + 160) (2-d string)
file_name db 70 dup('$')      ;file name
id dw ?                       ;file id
key_buffer db 2 dup ('$')     ;buff for scan code  
screen_mode_message db "YOU PRESSED:",'$'
open_message db "File was opened",'$'              
close_message db 0Ah,0Dh,"File was closed",'$'                
error_message db "Fail during working with files..",'$'  
empty_cmd_message db "cmd is empty...Nothing to handle",'$'   
too_many_message db "Too many args were entered",'$'    
new_line db 13,10,'$'   
to_char equ 30h     
del_hex equ 10h    
x_scan_code_push equ 38h
y_scan_code_push equ 3Ah
letter_char equ 7h
 
SPACE db ' '         


int15_new_handler proc far     
   
    pushf             ;push flags
    pusha             ;push all
    push ds           
    push cs
    pop ds;ds=cs        ;setting ds on the data of the resident program
    push es                 
     
   ;get needed scan code      
   
   mov ah, 4Fh        ;int 15h DOS 4Fh keyboard intercept
    ;al = scan code ~xy
     
    xor ah,ah
    mov bl,del_hex
    div bl        ; al = al/bl   => al = xy; bl = 10h; => al = X; ah = Y(remainder)
    
    add al,to_char    ;character translation
    add ah,to_char    ;character translation 
    
    cmp al,x_scan_code_push  ;scan code = XY; X(push code) - X(release code) = 8   ; 8 +30h = 38 h
    jl to_ah           ;if less  its the needed X scan-code
    jmp int15_end      ;its release cod
                                        
    to_ah:                   ;check ah
    cmp ah,y_scan_code_push           
    jl to_key_buffer        ;if less   its number 0-9
    add ah,letter_char               ;add for ascii-code needed symbol ('A'= 41h ah = 3Ah;) 3Ah + 7h = 41h  
    
    to_key_buffer:
    mov key_buffer[0],al    ;scan-code X
    mov key_buffer[1],ah    ;scan-code Y
    
    
    cmp open_error_flag, 1
    je open_error
    
    cmp open_file_flag,0      
    je write_in_file  
    
    mov ax, 3D02h  ;open created file for read and write	int 21h DOS 3D	        
    lea dx, file_name        
    int 21h   
    mov id,ax
    jc open_error  
    print open_message      
    
	write_in_file:
	mov ah,40h        ;write file int 21h DOS 40h
	mov bx,id         ;file id
	mov cx,2          ;2 bytes
	lea dx, key_buffer
	int 21h
	
	;SPACE write
	mov ah,40h
	mov bx,id
	mov cx,1
	lea dx, SPACE
	int 21h
      
    mov open_file_flag,0  

    ;/////////////////////////IF NO FILE OR ERROR    -    SCREEN /////////////
    open_error:
    mov open_error_flag,1
    push 0B800h
    pop es    
    mov ah,31h   
    
    xor si,si   
    mov di, screen_message_offset
 
    
    screen_message:       
    cmp screen_mode_message[si], '$'
    je key_to_screen   
    mov al, screen_mode_message[si]
    mov es:[di], al 
    add di,2 
    inc si 
    jmp screen_message   
  
    
    key_to_screen:  
    mov di,screen_offset
    mov al,key_buffer[0]   
    mov es:[di],ax 
    add di,2
    mov al,key_buffer[1]   
    mov es:[di],ax 
   
   
    
    int15_end:
    
	pop es         
    pop ds      
    popa 
    popf
    
    jmp dword ptr cs:[int15_old_offset]    

iret    
int15_new_handler endp  
           
;/////////////////////////////////////////////INSTALLER INTERRUPT HANDLER////////////////////////////////////           
installer: 
   call get_file_name      ;fet file name
   
   continue_main: 
    cli                      ;disable interruptions
    mov ax, 3515h            ;ah = number interruption
    int 21h                  ;int 21h DOS 35h   get the address of the interrupt handler
    mov int15_old_offset, bx   ;bx = offset  interrupt handler
    mov int15_old_segment, es   ;es = segment  interrupt handler
    
    mov ax, 2515h                      ;   ah = number interruption
    mov dx, offset int15_new_handler   ;dx = offset  interrupt handler
    int 21h                           ;int 21h DOS 25 h    to establish the address of the interrupt handler
    sti                           ;   allow  interruptions
    
    mov dx, offset installer          ;dx = first byte after the resident sector
    int 27h                      ;exit, but leave the program resident         
    
;////////////////////////////////////////////////PRINT STR/////////////////////////////  
 macro print str
	mov ah,9
	mov dx,offset new_line 
	int 21h
  mov ah,9
  mov dx,offset str
  int 21h
  mov ah,9
	mov dx,offset new_line 
	int 21h
endm  

;////////////////////////////////////////////////GET FILE //////////////////////////////////////
get_file_name proc  
    xor cx, cx
    mov cl, es:[80h]  ;this adress contains size of cmd 
    cmp cl, 0 
    je empty_cmd
    mov di, 82h       ;start of cmd
    lea si, file_name     
get_symbols:
    mov al, es:[di]    
    cmp al, 0Dh       ;compare with end  
    je continue_main   
    cmp al, ' '
    je too_many_args
    mov [si], al       
    inc di            
    inc si            
jmp get_symbols 

    empty_cmd:
    print empty_cmd_message 
    call exit 
    too_many_args:
    print too_many_message 
    call exit 
ret
get_file_name endp 

;///////////////////////////////////////////EXIT /////////////////////////////////////                  
exit proc  
    int 20h 
ret
exit endp    

end start
