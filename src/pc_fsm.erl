%%
%% pc_fsm.erl
%%
%% Easymmo one character fsm
%%
%% Start -> waiting -> Exit.
%%            | |
%%        oing action
%%

-module(pc_fsm).

-behavior(gen_fsm).

-include("emmo.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).

%%
%% APIs
%%

%%
%% Behaviors
%%
start_link(RiakIp, RiakPort) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [RiakIp, RiakPort], []).

init(Args) ->
    [RiakIp, RiakPort] = Args,
	{ok, Pid} = riakc_pb_socket:start(RiakIp, RiakPort),
	NewState = Pid,
	{ok, NewState}.

terminate(_Reason, State) ->
	ok.





