package flixel.addons.api;

import openfl.net.URLLoader;
import openfl.net.URLRequest;
import openfl.net.URLRequestMethod;
import openfl.events.Event;
import haxe.Json;

class FlxNewgrounds
{
    public static var appId:String;
    public static var aesKey:String;
    public static var sessionId:String;

    static var apiUrl:String = "https://www.newgrounds.io/gateway_v3.php";
    static var loader:URLLoader;

    public static var medals:Array<Dynamic> = [];

    public static function init(id:String, key:String):Void
    {
        appId = id;
        aesKey = key;
        startSession();
    }

    static function startSession():Void
    {
        var requestObj = {
            "app_id": appId,
            "execute": {
                "component": "App.startSession"
            }
        };

        var requestData = "request=" + StringTools.urlEncode(Json.stringify(requestObj));
        var req = new URLRequest(apiUrl);
        req.method = URLRequestMethod.POST;
        req.data = requestData;

        loader = new URLLoader();
        loader.addEventListener(Event.COMPLETE, onSessionStart);
        loader.load(req);
    }

    static function onSessionStart(e:Event):Void
    {
        var response = Json.parse(loader.data);
        if (response.success && response.result != null && response.result.data != null)
        {
            var data = response.result.data;
            if (data.session != null)
            {
                sessionId = data.session.id;
                getMedalList();
            }
        }
    }

    public static function postScore(boardId:String, score:Int):Void
    {
        if (sessionId == null) return;

        var requestObj = {
            "app_id": appId,
            "session_id": sessionId,
            "execute": {
                "component": "ScoreBoard.postScore",
                "parameters": {
                    "board_id": boardId,
                    "value": score
                }
            }
        };

        sendRequest(requestObj);
    }

    public static function unlockMedal(id:Int):Void
    {
        if (sessionId == null) return;

        var requestObj = {
            "app_id": appId,
            "session_id": sessionId,
            "execute": {
                "component": "Medal.unlock",
                "parameters": { "id": id }
            }
        };

        sendRequest(requestObj);
    }

    public static function getMedalList():Void
    {
        if (sessionId == null) return;

        var requestObj = {
            "app_id": appId,
            "session_id": sessionId,
            "execute": {
                "component": "Medal.getList"
            }
        };

        var req = new URLRequest(apiUrl);
        req.method = URLRequestMethod.POST;
        req.data = "request=" + StringTools.urlEncode(Json.stringify(requestObj));

        var l = new URLLoader();
        l.addEventListener(Event.COMPLETE, onMedalList);
        l.load(req);
    }

    static function onMedalList(e:Event):Void
    {
        var response = Json.parse(cast(e.target, URLLoader).data);
        if (response.success && response.result != null && response.result.data != null && response.result.data.medals != null)
        {
            medals = response.result.data.medals;
        }
    }

    public static function getMedalByName(name:String):Dynamic
    {
        for (medal in medals)
        {
            if (medal.name == name)
                return medal;
        }
        return null;
    }

    public static function isMedalUnlocked(id:Int):Bool
    {
        for (medal in medals)
        {
            if (medal.id == id)
                return medal.unlocked;
        }
        return false;
    }

    static function sendRequest(obj:Dynamic):Void
    {
        var data = "request=" + StringTools.urlEncode(Json.stringify(obj));
        var req = new URLRequest(apiUrl);
        req.method = URLRequestMethod.POST;
        req.data = data;

        var l = new URLLoader();
        l.load(req);
    }
}
