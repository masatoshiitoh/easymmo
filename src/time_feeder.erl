-module(time_feeder).

-export([hello/1]).

start() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% kick %%
hello(Name) ->
	Reply = gen_server:call(?MODULE, {hello, Name}),
	io:format("Hello, ~s~n", [Reply]). 

%% gen_server behaviour %%        
handle_call({hello, Name}, From, State) ->
	Reply = lists:append(["newbie- ", Name]),
	{reply, Reply, State}.

