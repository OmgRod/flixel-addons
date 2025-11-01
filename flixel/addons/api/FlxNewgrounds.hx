package flixel.addons.api;

import openfl.net.URLLoader;
import openfl.net.URLRequest;
import openfl.net.URLRequestMethod;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.Lib;
import haxe.Json;
import haxe.Timer;

class FlxNewgrounds
{
    public static var appId:String;
    public static var aesKey:String;
    public static var sessionId:String;
	public static var medals:Array<Dynamic> = [];
	public static var connected:Bool = false;

	static var apiUrl:String = "https://www.newgrounds.io/gateway_v3.php";

	public static var onReady:Void->Void = null;
	public static var onError:String->Void = null;
	public static var onMedalUnlocked:Dynamic->Void = null;

	static var _loader:URLLoader;
	
	public static function init(id:String, key:String, ?onReadyCallback:Void->Void, ?onErrorCallback:String->Void):Void
    {
        appId = id;
        aesKey = key;
		onReady = onReadyCallback;
		onError = onErrorCallback;

        startSession();
    }

    static function startSession():Void
    {
		var params = Lib.current.loaderInfo.parameters;
		var ngSessionId:String = params.exists("ngio_session_id") ? params.get("ngio_session_id") : null;
		var requestObj:Dynamic;
		
		if (ngSessionId != null)
		{
			requestObj = {
				"app_id": appId,
				"execute": {
					"component": "App.checkSession",
					"parameters": {"session_id": ngSessionId}
				}
			};
		}
		else
		{
			requestObj = {
				"app_id": appId,
				"execute": {"component": "App.startSession"}
			};
		}

		sendRequest(requestObj, onSessionResponse);
    }

	static function onSessionResponse(response:Dynamic):Void
    {
		if (!response.success || response.result == null || response.result.data == null)
        {
			handleError("Invalid session response");
			return;
		}

		var data = response.result.data;
		if (data.session != null)
		{
			sessionId = data.session.id;
			connected = true;
			getMedalList();
		}
		else
		{
			handleError("Failed to start session: no session ID");
        }
    }

	public static function getMedalList():Void
    {
        if (sessionId == null) return;

		var requestObj = {
			"app_id": appId,
			"session_id": sessionId,
			"execute": {"component": "Medal.getList"}
		};
		
		sendRequest(requestObj, onMedalListResponse);
	}
	
	static function onMedalListResponse(response:Dynamic):Void
	{
		if (response.success && response.result != null && response.result.data != null)
		{
			medals = response.result.data.medals;
			if (onReady != null)
				onReady();
		}
		else
		{
			handleError("Failed to get medal list");
		}
	}
	
	public static function postScore(boardId:String, value:Int):Void
	{
		if (!connected || sessionId == null)
			return;

        var requestObj = {
            "app_id": appId,
            "session_id": sessionId,
            "execute": {
                "component": "ScoreBoard.postScore",
                "parameters": {
                    "board_id": boardId,
					"value": value
                }
            }
        };

        sendRequest(requestObj);
    }

    public static function unlockMedal(id:Int):Void
    {
		if (!connected || sessionId == null)
			return;
		if (isMedalUnlocked(id))
			return;

        var requestObj = {
            "app_id": appId,
            "session_id": sessionId,
            "execute": {
                "component": "Medal.unlock",
                "parameters": { "id": id }
            }
        };

		sendRequest(requestObj, function(res)
		{
			if (res.success && res.result != null && res.result.data.success)
			{
				var medal = getMedalById(id);
				if (medal != null)
					medal.unlocked = true;
				if (onMedalUnlocked != null)
					onMedalUnlocked(medal);
			}
		});
    }

	public static function getMedalById(id:Int):Dynamic
	{
		for (m in medals)
			if (m.id == id)
				return m;
		return null;
	}
	
	public static function getMedalByName(name:String):Dynamic
	{
		for (m in medals)
			if (m.name == name)
				return m;
		return null;
	}
	
	public static function isMedalUnlocked(id:Int):Bool
	{
		for (m in medals)
			if (m.id == id)
				return m.unlocked;
		return false;
	}
	
	public static function pingSession():Void
    {
        if (sessionId == null) return;

		var reqObj = {
            "app_id": appId,
            "session_id": sessionId,
			"execute": {"component": "Gateway.ping"}
        };

		sendRequest(reqObj);
	}
	
	static function sendRequest(requestObj:Dynamic, ?callback:Dynamic->Void):Void
	{
        var req = new URLRequest(apiUrl);
        req.method = URLRequestMethod.POST;
        req.data = "request=" + StringTools.urlEncode(Json.stringify(requestObj));

        var l = new URLLoader();
		l.addEventListener(Event.COMPLETE, function(e:Event)
		{
			try
			{
				var response = Json.parse(l.data);
				if (callback != null)
					callback(response);
			}
			catch (err:Dynamic)
			{
				handleError("Failed to parse response: " + Std.string(err));
			}
		});

		l.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent)
		{
			handleError("Network error: " + e.text);
		});
		
		l.load(req);
    }

	static function handleError(msg:String):Void
    {
		trace("[FlxNewgrounds Error] " + msg);
		if (onError != null)
			onError(msg);
    }
}
