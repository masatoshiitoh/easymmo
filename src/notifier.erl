%%
%% notifier.erl
%%
%%

-module(notifier).

-export([start_link/0]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([add/2]).
-export([test/0]).
-export([test/2]).

%%
%% APIs
%%
test() ->
	io:format("request to run test/2 with 0, 1~n", []),
	notifier:add(1000, {mfa, notifier, test, [0,1]}).

test(A,B) ->
	io:format("notifier:test/2 called. ~p, ~p ~n", [A, B]).

add(DeltaMs, {mfa, M, F, A}) ->
	Reply = gen_server:call(?MODULE, {add, DeltaMs, {mfa, M, F, A}}).

%%
%% Behaviors
%%
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
	{ok, []}.

terminate(_Reason, State) ->
	ok.

handle_call({add, DeltaMs, {mfa, M, F, A}}, From, State) ->
	spawn(fun() ->
		receive after DeltaMs -> apply(M,F,A) end
		end),
	{reply, ok, State}.

