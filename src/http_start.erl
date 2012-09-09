-module(http_start).
-export([start/2, stop/1]).
-behavior(application).
-import(listen_http, [wait_for_request/2]).

-define(HTTP_PORT, 9988).

start(_Type, _Args) ->
	{ok,LSock} = gen_tcp:listen(?HTTP_PORT, [binary]),
	ServFunc = fun(_Conn, _HttpRequest) ->
		Body = "<html><head><title>Eat it</title></head><body><h1>I WIN</h1></body></html>",
		Schtuff = [
			"HTTP/1.1 200 OK",
			"Content-Type: text/html",
			io_lib:format("Content-Length: ~p", [string:len(Body)]),
			"",
			Body,
			""
		],
		string:join(Schtuff, "\r\n")
	end,
	listen_http:wait_for_request(LSock, ServFunc).

stop(_State) ->
	ok.
