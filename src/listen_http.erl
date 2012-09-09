%% ridiculously simple http server that currently only supports simple GET requests
%% one thread. one socket. one module.  starring vin diesel.

-module(listen_http).
-export([wait_for_request/2]).

-include("http_request.hrl").
-include("http_header.hrl").

receive_http_bytes(Conn, ByteList, LastByte) ->
	%% Just keep getting request data until two returns are found

	%% Do the absolute best to support the shittiest of shit browsers
	%% that don't use carriage returns by ignoring the returns in the request
	{Status,Response} = gen_tcp:recv(Conn, 1),
	case {Status,Response} of
		{ok,<<"\r">>} ->
			receive_http_bytes(Conn, ByteList, LastByte);

		%% Two subsequent returns means end of request
		{ok,<<"\n">>} ->
			if
				LastByte == <<"\n">> ->
					{ok,binary:bin_to_list(binary:list_to_bin(lists:reverse(ByteList)))};

				true ->
					receive_http_bytes(Conn, [Response | ByteList], Response)
			end;

		{ok,_} ->
			receive_http_bytes(Conn, [Response | ByteList], Response);

		{error,Reason} ->
			{error,Reason};

		{_,_} ->
			io:format("..uh: ~p ~p\n", [Status,Response])
	end.

receive_request(Conn) ->
	receive_http_bytes(Conn, [], <<>>).

receive_http_request(Conn) ->
	%% Keep receiving bytes from the peer until two \r\n's are received
	case receive_request(Conn) of
		%% Take raw bytes, tokenize by \r\n
		{ok,ReqBytes} ->
			[ReqString | HeaderStrParts] = string:tokens(ReqBytes, "\n"),
			[Verb | [Handle | _] ] = string:tokens(ReqString, " "),
			Func = fun (X) ->
				[Name | [Val | _] ] = string:tokens(X, ": "),
				#http_header{name = Name, value = Val}
			end,
			{ok,#http_request{verb = Verb, handle = Handle, headers = lists:map(Func, HeaderStrParts)}};

		{error,Reason} ->
			{error,Reason}
	end.

serve_http(Conn, Fun) ->
	case receive_http_request(Conn) of
		{ok,RequestParams} ->
			{ok,Fun(Conn, RequestParams)};

		{error, Reason} ->
			{error, Reason};

		_ -> %% You should never get here in the first place
			{error, "Very bad things happened"}
	end.

wait_for_request(LSock, Fun) ->
	http_loop(LSock, Fun).

handle_request(Conn, Fun) ->
	case serve_http(Conn, Fun) of
		{ok,Output} ->
			gen_tcp:send(Conn, Output),
			handle_request(Conn, Fun);

		{error, Reason} ->
			{error, Reason}
	end.

http_loop(LSock, Fun) ->
	http_loop_persistent(LSock, Fun).

http_loop_persistent(LSock, Fun) ->
	case gen_tcp:accept(LSock) of
		{ok,Conn} ->
			inet:setopts(Conn, [binary, {packet, raw}, {header, 0}, {active, false}]),
			handle_request(Conn, Fun),
			http_loop_persistent(LSock, Fun);

		{error,closed} ->
			http_loop_persistent(LSock, Fun);

		{error,killed} ->
			gen_tcp:close(LSock),
			{error,killed};

		{error,Reason} ->
			{error,Reason}
	end.
