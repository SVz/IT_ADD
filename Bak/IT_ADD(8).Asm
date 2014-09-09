.386
.model flat,stdcall
option casemap:none
WinMain proto :DWORD,:DWORD,:DWORD,:DWORD
round_ proto :DWORD,:DWORD

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc
include \masm32\include\masm32.inc
include \masm32\include\comdlg32.inc
include \masm32\include\advapi32.inc
includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\masm32.lib
includelib \masm32\lib\comdlg32.lib
includelib \masm32\lib\advapi32.lib

.const
 IDC_OPEN                                           equ 3000
 IDC_EXIT                                           equ 3001
 IDC_FILENAME                                       equ 3002
 IDC_FILESIZE                                       equ 3003
 IDC_NBSECTION                                      equ 3004
 IDC_ITB                                            equ 3005
 IDC_ITNAME                                         equ 3006
 IDC_ITSIZE                                         equ 3007
 IDC_DOIT                                           equ 3008
 IDC_RAWSIZE                                        equ 3009
 MAXSIZE equ 260
;Res\IT_ADD.dlg
IDC_GRP1								equ 1007
IDC_EOP									equ 1001
IDC_STC1								equ 1002
IDC_IT									equ 1003
IDC_STC2								equ 1004
IDC_EOP_F								equ 1005
IDC_IT_F								equ 1006

.data
ofn                 OPENFILENAME <>
ClassName           db "DLGCLASS",0
DlgName             db "SVDialog",0
buffer_exe          db MAXSIZE   dup(0)
align
buffer              db MAXSIZE   dup(0)
hMemory_alloc       HANDLE ?
hMapFile            HANDLE 0
hMapFile_it         HANDLE 0
hwMapFile           HANDLE 0
FilterString        db "Exe Files",0,"*.exe",0,0
FilterString_bin    db "IT Files",0,"*.bin",0,0
template            db "%X",0  
MsgCaption          db "Error",0
MsgCaptionGood      db "Yeah!",0
MsgBoxText          db "File can't be opened !",0
MsgBoxDel           db "Delete File ?",0
MsgBoxTextGood      db "File created successfully !",0
szsvKey             db  '\Software\SV',0
szsvDir             db  'dir',0
szSIZE              dd 256
idata_section_name  db ".idata",0
.data?
hInstance           HINSTANCE ?
CommandLine         LPSTR ?
hFileRead           HANDLE ?
hFileRead_it        HANDLE ?
hFileWrite          HANDLE ?
pMemory             DWORD ?
pMemory_alloc       DWORD ?
pMemory_it          DWORD ?
stubsize            DWORD ?
nbsection           db ?
textbuffer          db 512 dup(?)
file_size           dd ?
file_size_it        dd ?
dirbuffer           db 512 dup(?)
hReg                dd ?
lpdwDisposition     dd ?
section_raw_size    dd ?
section_virtual_size dd ?
section_virtual_offset dd ?
file_size_raw       dd ?
new_size            dd ?
new_file_size       dd ?
SizeReadWrite       DWORD ?
.code
;--------------------------------------------------------------------
   
;--------------------------------------------------------------------
;--------------------------------------------------------------------
;--------------------------------------------------------------------
start:
    invoke GetModuleHandle, NULL
    mov    hInstance,eax
    invoke GetCommandLine
    call svdirregopen
    invoke WinMain, hInstance,NULL,CommandLine, SW_SHOWDEFAULT
exit:
    invoke ExitProcess,eax
    
WinMain proc hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hDlg:HWND
    
    mov   wc.cbSize,SIZEOF WNDCLASSEX
    mov   wc.style, CS_HREDRAW or CS_VREDRAW
    mov   wc.lpfnWndProc, OFFSET WndProc
    mov   wc.cbClsExtra,NULL
    mov   wc.cbWndExtra,DLGWINDOWEXTRA
    push  hInst
    pop   wc.hInstance
    mov   wc.hbrBackground,COLOR_BTNFACE+1
    mov   wc.lpszClassName,OFFSET ClassName
    
    invoke LoadIcon,hInst,1
    mov   wc.hIcon,eax
    mov   wc.hIconSm,eax
    invoke LoadCursor,NULL,IDC_ARROW
    mov   wc.hCursor,eax
    invoke RegisterClassEx, addr wc
    invoke CreateDialogParam,hInstance,ADDR DlgName,NULL,NULL,NULL
    mov   hDlg,eax
    INVOKE ShowWindow, hDlg,SW_SHOWNORMAL
    INVOKE UpdateWindow, hDlg

    mov ofn.lStructSize,SIZEOF ofn
    push hDlg
    pop  ofn.hWndOwner
    push hInstance
    pop  ofn.hInstance
    mov  ofn.lpstrFile, OFFSET buffer
    mov  ofn.nMaxFile,MAXSIZE

    .WHILE TRUE
                INVOKE GetMessage, ADDR msg,NULL,0,0
                .BREAK .IF (!eax)
                invoke IsDialogMessage, hDlg, ADDR msg
                .if eax==FALSE
                        INVOKE TranslateMessage, ADDR msg
                        INVOKE DispatchMessage, ADDR msg
                .endif
    .ENDW
    mov     eax,msg.wParam
    ret
WinMain endp
WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
;int 3
    .IF uMsg==WM_DESTROY
        invoke PostQuitMessage,NULL
    .ELSEIF uMsg==WM_COMMAND
        mov eax,wParam
        mov edx,wParam
        shr edx,16
        .IF dx==BN_CLICKED
            .IF ax==IDC_OPEN
                .if hMapFile!=0
                    invoke UnmapViewOfFile,pMemory
                    call CloseMapFile
                .endif
                mov  ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER or OFN_HIDEREADONLY
                mov ofn.lpstrInitialDir, offset dirbuffer
                mov  ofn.lpstrFilter, OFFSET FilterString
                invoke GetOpenFileName, ADDR ofn
                .if eax==TRUE
                    invoke lstrcpy,addr buffer_exe,addr buffer
                    invoke CreateFile,ADDR buffer,GENERIC_READ,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_ARCHIVE,NULL
                    test eax,eax
                    jz error                                                
                    mov hFileRead,eax
                    invoke GetFileSize,hFileRead,NULL
                    mov file_size_raw,eax
                    invoke wsprintf,addr textbuffer,offset template,eax
                    invoke SetDlgItemText,hWnd,IDC_RAWSIZE,addr textbuffer
                    invoke RegSetValueExA,hReg,offset szsvDir,0,REG_SZ,offset buffer,255
                    invoke lstrcpy,addr dirbuffer,addr buffer
                    invoke CreateFileMapping,hFileRead,NULL,PAGE_READONLY,0,0,NULL
                    test eax,eax
                    jz error                                                
                    mov  hMapFile,eax
                    mov    eax,OFFSET buffer
                    movzx  edx,ofn.nFileOffset
                    add    eax,edx
                    invoke SetDlgItemText,hWnd,IDC_FILENAME,eax
                    invoke MapViewOfFile,hMapFile,FILE_MAP_READ,0,0,0
                    mov pMemory,eax
                    add eax,3Ch
                    mov eax,[eax]
                    mov stubsize,eax
                    mov eax,pMemory
                    add eax,stubsize
                    add eax,6       ; Nb Section
                    movsx eax,byte ptr [eax]
                    mov nbsection,al
                    invoke wsprintf,addr textbuffer,offset template,eax
                    invoke SetDlgItemText,hWnd,IDC_NBSECTION,addr textbuffer

                    mov eax,pMemory
                    add eax,stubsize
                    add eax,50h       ; Size
                    mov eax,[eax]
                    mov file_size,eax
                    invoke wsprintf,addr textbuffer,offset template,eax
                    invoke SetDlgItemText,hWnd,IDC_FILESIZE,addr textbuffer

                    mov eax,pMemory
                    add eax,stubsize
                    add eax,28h       ; EOP
                    mov eax,[eax]
                    invoke wsprintf,addr textbuffer,offset template,eax
                    invoke SetDlgItemText,hWnd,IDC_EOP,addr textbuffer

                    mov eax,pMemory
                    add eax,stubsize
                    add eax,80h       ; IT
                    mov eax,[eax]
                    invoke wsprintf,addr textbuffer,offset template,eax
                    invoke SetDlgItemText,hWnd,IDC_IT,addr textbuffer

                    invoke GetDlgItem,hWnd,IDC_ITB
                    invoke EnableWindow,eax,TRUE
                    jmp finerror
                error:
                    invoke MessageBox, NULL,addr MsgBoxText, addr MsgCaption, MB_OK
                finerror:
                .endif
            .ELSEIF ax==IDC_EOP_F
                invoke GetDlgItemText,hWnd,IDC_FILESIZE,addr textbuffer,10
                invoke SetDlgItemText,hWnd,IDC_EOP,addr textbuffer
                mov edi,pMemory
                add edi,stubsize
                add edi,28h       ; EOP
                mov eax,file_size
                mov dword ptr [edi],eax
            .ELSEIF ax==IDC_IT_F
                invoke GetDlgItemText,hWnd,IDC_FILESIZE,addr textbuffer,10
                invoke SetDlgItemText,hWnd,IDC_IT,addr textbuffer
                mov edi,pMemory
                add edi,stubsize
                add edi,80h       ; IT
                mov eax,file_size
                mov dword ptr [edi],eax
           .ELSEIF ax==IDC_ITB
            	pushad
                .if hMapFile_it!=0
                    invoke UnmapViewOfFile,pMemory_it
                    call   CloseMapFile_it
                .endif
                mov  ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER or OFN_HIDEREADONLY
                mov  ofn.lpstrFilter, OFFSET FilterString_bin
                mov byte ptr [buffer],0
                mov ofn.lpstrInitialDir, offset dirbuffer
                invoke GetOpenFileName, ADDR ofn
                .if eax==TRUE
                    invoke CreateFile,ADDR buffer,GENERIC_READ,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_ARCHIVE,NULL
                    test eax,eax
                    jz error_it                                                
                    mov hFileRead_it,eax
                    invoke RegSetValueExA,hReg,offset szsvDir,0,REG_SZ,offset buffer,255
                    invoke lstrcpy,addr dirbuffer,addr buffer
                    invoke GetFileSize,hFileRead_it,NULL
                    mov file_size_it,eax
                    invoke CreateFileMapping,hFileRead_it,NULL,PAGE_READONLY,0,0,NULL
                    test eax,eax
                    jz error_it                                                
                    mov  hMapFile_it,eax
                    mov    eax,OFFSET buffer
                    movzx  edx,ofn.nFileOffset
                    add    eax,edx
                    invoke SetDlgItemText,hWnd,IDC_ITNAME,eax
                    invoke MapViewOfFile,hMapFile_it,FILE_MAP_READ,0,0,0
                    mov pMemory_it,eax
                    invoke wsprintf,addr textbuffer,offset template,file_size_it
                    invoke SetDlgItemText,hWnd,IDC_ITSIZE,addr textbuffer
                    invoke GetDlgItem,hWnd,IDC_DOIT
                    invoke EnableWindow,eax,TRUE
                    jmp error_it_
                error_it:
                    invoke MessageBox, NULL,addr MsgBoxText, addr MsgCaption, MB_OK
                error_it_:
                popad
                .endif
            .ELSEIF ax==IDC_DOIT
				
				call fix_header
				
                mov ofn.Flags,OFN_LONGNAMES or OFN_EXPLORER or OFN_HIDEREADONLY
                mov ofn.lpstrInitialDir, offset dirbuffer
                mov  ofn.lpstrFilter, OFFSET FilterString
                mov byte ptr [buffer],0
                invoke GetSaveFileName, ADDR ofn
                .if eax==TRUE
                    invoke CreateFile,ADDR buffer,GENERIC_READ or GENERIC_WRITE ,\
                          FILE_SHARE_READ or FILE_SHARE_WRITE,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
                    .if (eax)
                        mov hFileWrite,eax
                        invoke WriteFile,hFileWrite,pMemory_alloc,new_size,ADDR SizeReadWrite,NULL
                        invoke CloseHandle,hFileWrite
                        invoke MessageBox, NULL,addr MsgBoxTextGood, addr MsgCaptionGood, MB_OK
                    .endif
                    invoke MessageBox, NULL,addr MsgBoxDel, addr MsgCaptionGood, MB_OKCANCEL
                    .if eax==IDOK
                        invoke DeleteFile,addr buffer_exe
                    .endif
                .endif
                ;free alloc mem                
                call   CloseMapFile_it
                call   CloseMapFile
                invoke GlobalUnlock,pMemory_alloc
                invoke GlobalFree,hMemory_alloc
            .ELSEIF ax==IDC_EXIT
                invoke RegCloseKey,hReg
                invoke DestroyWindow,hWnd
            .ENDIF
        .ENDIF
    .ENDIF
    invoke DefWindowProc,hWnd,uMsg,wParam,lParam
    ret
WndProc endp

fix_header PROC
	
	            push file_size
                pop section_virtual_offset
                
                invoke round_,file_size_it,200h
                mov section_raw_size,eax
                invoke round_,file_size_it,1000h
                mov section_virtual_size,eax

                mov eax,file_size_raw
                add eax,section_raw_size
                mov new_size,eax

                mov eax,file_size                                
                add eax,section_virtual_size
                mov new_file_size,eax
;                
                ;alloc memory              
                invoke GlobalAlloc,GMEM_MOVEABLE or GMEM_ZEROINIT,new_size
                mov  hMemory_alloc,eax
                invoke GlobalLock,hMemory_alloc
                mov  pMemory_alloc,eax

                ;copy exe
                mov ecx,file_size_raw
                mov esi,pMemory
                mov edi,pMemory_alloc
                rep movsb
                
                ;copy IT
                mov ecx,file_size_it
                mov esi,pMemory_it
                rep movsb
                
                ;section update
                ;inc section number
                mov edi,pMemory_alloc
                add edi,stubsize
                add edi,6       ; Nb Section
                movsx ebx,nbsection
                inc ebx
                mov byte ptr [edi],bl
                
                ;file size
                mov edi,pMemory_alloc
                add edi,stubsize
                add edi,50h       ; Size
                mov eax,new_file_size
                mov dword ptr [edi],eax

                ;new section
                mov edi,pMemory_alloc
                add edi,stubsize
                movzx eax,byte ptr [edi+14h]    ;NT Header size
                add edi,eax
                add edi,18h
                movsx ebx,nbsection
                imul ebx,28h
                add edi,ebx
                ;name
                invoke lstrcpy,edi,offset idata_section_name
                add edi,8
                ;virtual size
                mov eax,section_virtual_size
                mov dword ptr [edi],eax
                add edi,4
                ;virtual offset
                mov eax,section_virtual_offset
                mov dword ptr [edi],eax
                add edi,4
                ;raw size
                mov eax,section_raw_size
                mov dword ptr [edi],eax
                add edi,4
                ;raw offset
                mov eax,file_size_raw
                mov dword ptr [edi],eax
                add edi,10h
                ;caracteristic
                mov dword ptr [edi],40000040h
	ret

fix_header endp
round_ PROC val:DWORD,modulo:DWORD
    pushad
    mov eax,val
    mov ebx,modulo
    xor edx,edx
    cdq
    idiv ebx
    test edx,edx
    jz suite_modulo
    inc eax
suite_modulo:
    imul eax,modulo
    mov val,eax
	popad
	mov eax,val
    ret
round_ endp

svdirregopen PROC
    invoke RegCreateKeyExA,HKEY_CURRENT_USER,offset szsvKey,0,0,0,\
    1F0003h,0,offset hReg,offset lpdwDisposition
    invoke RegQueryValueExA,hReg,offset szsvDir,0,0,offset dirbuffer,offset szSIZE
    ret
svdirregopen endp
CloseMapFile PROC
        invoke UnmapViewOfFile,pMemory
        invoke CloseHandle,hMapFile
        mov    hMapFile,0
        invoke CloseHandle,hFileRead
        ret
CloseMapFile endp
CloseMapFile_it PROC
        invoke UnmapViewOfFile,pMemory_it
        invoke CloseHandle,hMapFile_it
        mov    hMapFile_it,0
        invoke CloseHandle,hFileRead_it
        ret
CloseMapFile_it endp
end start
