{$IFDEF PORTUGUES}
//: Implementa funções de socket para Windows CE.
{$ELSE}
//: Windows CE socket functions.
{$ENDIF}
unit sockets_wince;

{$IFDEF FPC}
{$mode delphi}
{$ENDIF}

interface

uses
  windows, Sockets, socket_types, commtypes;

  function socket_recv(sock:Tsocket; buf:PByte; len: Cardinal; flags, timeout: Integer):Integer;
  function socket_send(sock:Tsocket; buf:PByte; len: Cardinal; flags, timeout: Integer):Integer;

  {$IFDEF PORTUGUES}
  //: Seta o modo de operação de socket.
  {$ELSE}
  //: Sets the socket operation mode.
  {$ENDIF}
  function setblockingmode(fd:TSocket; mode:dword):Integer;

  {$IFDEF PORTUGUES}
  {:
  Função de conexão com timeout. Seus parametros são identicos a função
  connect/fpconnect, porem adicionado o tempo máximo de espera pelo estabelecimento
  da conexão em milisegundos.
  @returns(0 se a conexão foi estabelecida com sucesso.)
  }
  {$ELSE}
  {:
  Connect function with timeout. Their parameters are the same of the functions
  connect/fpconnect, with a extra parameter that is the maximum timeout of the
  connection establishment in milliseconds.
  @returns(0 if the connection was estabilished successful.)
  }
  {$ENDIF}
  function connect_with_timeout(sock:Tsocket; address:PSockAddr; address_len:t_socklen; timeout:Integer):Integer;

  {$IFDEF PORTUGUES}
  {:
  Verifica o estado da conexão e atualiza o estado da porta da comunicação.
  @returns(@True se ainda está conectado)
  }
  {$ELSE}
  {:
  Check the current connection state and updates the state of the communication port.
  @returns(@True if stills connected.)
  }
  {$ENDIF}
  function CheckConnection(var CommResult:TIOResult; var incRetries:Boolean; var PActive:Boolean; var FSocket:TSocket; DoCommPortDisconected:TDisconnectNotifierProc):Boolean;

implementation

uses winsock;

function setblockingmode(fd:sockets.Tsocket; mode:u_long):Integer;
begin
  if ioctlsocket(fd, FIONBIO, mode)=SOCKET_ERROR then
    Result:=-1
  else
    Result:=0;
end;

function connect_with_timeout(sock:sockets.Tsocket; address:sockets.psockaddr; address_len:t_socklen; timeout:Integer):Integer;
var
  sel:TFDSet;
  mode:u_long;
  tv : TTimeVal;
  p:ptimeval;
begin

  if timeout=-1 then
    p:=nil
  else begin
    tv.tv_Sec:=Timeout div 1000;
    tv.tv_Usec:=(Timeout mod 1000)*1000;
    p:=@tv;
  end;

  Result:=0;

  if fpconnect(sock, address, address_len) <> 0 then begin
    if WSAGetLastError=WSAEWOULDBLOCK then begin
      FD_ZERO(sel);
      FD_SET(sock, sel);
      mode := select(sock, nil, @sel, nil, p);

      if (mode < 0) then begin
        Result := -1;
      end else begin
        if (mode > 0) then begin
          Result := 0;
        end else begin
          if (mode = 0) then begin
            Result := -2;
          end;
        end;
      end;
    end else
      Result := -1;
  end;
end;

function socket_recv(sock:sockets.Tsocket; buf:PByte; len: Cardinal; flags, timeout: Integer):Integer;
var
  sel:TFDSet;
  mode:u_long;
  tv : TTimeVal;
  p:ptimeval;
begin

  if timeout=-1 then
    p:=nil
  else begin
    tv.tv_Sec:=Timeout div 1000;
    tv.tv_Usec:=(Timeout mod 1000)*1000;
    p:=@tv;
  end;

  Result:=fprecv(sock, buf, len, flags);

  if Result = SOCKET_ERROR then begin
    if WSAGetLastError=WSAEWOULDBLOCK then begin
      FD_ZERO(sel);
      FD_SET(sock, sel);
      mode := select(sock, @sel, nil, nil, p);

      if (mode < 0) then begin
        Result := -1;
      end else begin
        if (mode > 0) then begin
          Result := fprecv(sock, buf, len, flags);
        end else begin
          if (mode = 0) then begin
            Result := -2;
          end;
        end;
      end;
    end else
      Result := -1;
  end;
end;

function socket_send(sock:sockets.Tsocket; buf:PByte; len: Cardinal; flags, timeout: Integer):Integer;
var
  sel:TFDSet;
  mode:u_long;
  tv : TTimeVal;
  p:ptimeval;
begin

  if timeout=-1 then
    p:=nil
  else begin
    tv.tv_Sec:=Timeout div 1000;
    tv.tv_Usec:=(Timeout mod 1000)*1000;
    p:=@tv;
  end;

  Result:=fpsend(sock, buf, len, flags);

  if Result = SOCKET_ERROR then begin
    if WSAGetLastError=WSAEWOULDBLOCK then begin
      FD_ZERO(sel);
      FD_SET(sock, sel);
      mode := select(sock, nil, @sel, nil, p);

      if (mode < 0) then begin
        Result := -1;
      end else begin
        if (mode > 0) then begin
          Result := fpsend(sock, buf, len, flags);
        end else begin
          if (mode = 0) then begin
            Result := -2;
          end;
        end;
      end;
    end else
      Result := -1;
  end;
end;

function CheckConnection(var CommResult:TIOResult; var incRetries:Boolean; var PActive:Boolean; var FSocket:Sockets.TSocket; DoCommPortDisconected:TDisconnectNotifierProc):Boolean;
var
  retval, nbytes:Integer;
  t:TTimeVal;
  readset:TFDSet;
begin
  Result:=true;

  retval:=0;
  nbytes:=0;
  retval:=ioctlsocket(FSocket,FIONREAD,@nbytes);

  if retval<>0 then begin
    DoCommPortDisconected();
    CommResult:=iorPortError;
    PActive:=false;
    Result:=false;
    exit;
  end;

  if (nbytes>0) then begin   // there is something in receive buffer, it doesn't seem the socket has been closed
    Result:=true;
    exit;
  end;

  t.tv_usec:=1;
  t.tv_sec:=0;

  FD_ZERO(readset);
  FD_SET(FSocket,readset);
  retval:=Select(FSocket,@readset,nil,nil,@t);

  if (retval=0) then begin   //timeout, appears to be ok...
    Result:=true;
    CommResult:=iorTimeOut;
    incRetries:=true;
    exit;
  end;

  if (retval<0) then begin //error on socket...
    DoCommPortDisconected();
    CommResult:=iorPortError;
    PActive:=false;
    Result:=false;
    exit;
  end;

  if (retval=1) then begin  // seems there is something in our receive buffer!!
    // now we check how many bytes are in receive buffer
    retval:=ioctlsocket(FSocket,FIONREAD,@nbytes);

    if (retval<>0) then begin  // some error occured
      DoCommPortDisconected();
      CommResult:=iorPortError;
      PActive:=false;
      Result:=false;
      exit;
    end;

    if (nbytes=0) then begin
      DoCommPortDisconected();
      CommResult:=iorNotReady;
      PActive:=false;
      Result:=false;
      exit;
    end;

    incRetries:=true;
  end;
end;

end.
