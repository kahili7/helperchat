-module(mod_lhc).

-define(NO_EXT_LIB, 1)

-behavior(gen_mod).
-include("ejabberd.hrl").
-include("jlib.hrl").
-include("logger.hrl").
-include("ejabberd.hrl").
-include("ejabberd_http.hrl").

-export([start/2, stop/1, on_set/4, on_unset/4, on_filter_packet/1, create_message/3, process/2]).


start(Host, _Opts) ->
   ejabberd_hooks:add(set_presence_hook, Host, ?MODULE, on_set, 50),
   %%ejabberd_hooks:add(unset_presence_hook, Host, ?MODULE, on_unset, 50),
   ejabberd_hooks:add(filter_packet, global, ?MODULE, on_filter_packet, 50),
   %%ejabberd_hooks:add(offline_message_hook, Host, ?MODULE, create_message, 50),
   ok.

stop(Host) ->
   ejabberd_hooks:delete(set_presence_hook, Host, ?MODULE, on_set, 50),
   %%ejabberd_hooks:delete(unset_presence_hook, Host, ?MODULE, on_unset, 50),
   ejabberd_hooks:delete(filter_packet, global, ?MODULE, on_filter_packet, 50),
   %%ejabberd_hooks:delete(offline_message_hook, Host, ?MODULE, create_message, 50),
   ok.
			 
create_message(_From, _To, _Packet) ->
   stop.
    
on_filter_packet({From, To, XML} = Packet) ->
    
	#jid{user = LUser, lserver = LServer} = From,
	case re:run(LUser, "^visitor\.\d{1,}\.\S{1,}") of
	  {match, _} -> ok;
	  nomatch -> 
		Type = xml:get_tag_attr_s(<<"type">>, XML),
	    Body = xml:get_subtag(XML, <<"body">>),
		
		if (Type == <<"chat">>) and (Body /= false) -> 
	    	 #jid{user = LReceiverUser, lserver = _LReceiverServer} = To,
			 URL = gen_mod:get_module_opt(LServer, ?MODULE, message_address, fun iolist_to_binary/1, undefined),	
			 BodyMessage = "body="++erlang:binary_to_list(ejabberd_http:url_encode(xml:get_tag_cdata(Body)))++
			               "&sender="++erlang:binary_to_list(ejabberd_http:url_encode(LUser))++
						   "&receiver="++erlang:binary_to_list(ejabberd_http:url_encode(LReceiverUser))++
						   "&server="++erlang:binary_to_list(ejabberd_http:url_encode(LServer)),
						   
			 httpc:request(post, {erlang:binary_to_list(URL), [], "application/x-www-form-urlencoded", BodyMessage}, [], []);
	    true -> false
	    end
	end,
	%% --------------
    Packet.
    
on_set(User, Server, _Resource, _Packet) ->
   LUser = jlib:nodeprep(User),
   LServer = jlib:nodeprep(Server),

   case re:run(erlang:binary_to_list(LUser),"^visitor\.\d{1,}\.\S{1,}") of
	  {match, _} -> ok;
	  nomatch -> 
		   URL = gen_mod:get_module_opt(LServer, ?MODULE, login_address, fun iolist_to_binary/1, undefined),
		   Body = "{\"action\":\"connect\",\"user\":\""++erlang:binary_to_list(LUser)++
		          "\",\"server\":\""++erlang:binary_to_list(LServer)++"\"}",
		
		   httpc:request(post, {erlang:binary_to_list(URL), [], "application/json", Body}, [], [])
   end.

on_unset(User, Server, _Resource, _Packet) ->
   LUser = jlib:nodeprep(User),
   LServer = jlib:nodeprep(Server),
       
   case re:run(erlang:binary_to_list(LUser),"^visitor\.\d{1,}\.\S{1,}") of
	  {match, _} -> ok;
	  nomatch -> 
		   URL = gen_mod:get_module_opt(LServer, ?MODULE, logout_address, fun iolist_to_binary/1, undefined),
		   Body = "{\"action\":\"disconnect\",\"user\":\""++erlang:binary_to_list(LUser)++
		          "\",\"server\":\""++erlang:binary_to_list(LServer)++"\"}",   
		   
		   httpc:request(post, {erlang:binary_to_list(URL), [], "application/json", Body}, [], [])   
   end.

process([<<"makeonline">>], _Request) ->
	"Not implemented yet";
	
process(_Page, _Request) ->
	"Fallback result".