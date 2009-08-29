// Spy script for the OpenCollar Project (c)
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

integer timeout = 60;
//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;
integer COMMAND_SAFEWORD = 510;  // new for safeword

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

string dbtoken = "spy";
//5000 block is reserved for IM slaves

//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";
string parentmenu = "Main";
string submenu = "Spy";
string currentmenu;

key owner = NULL_KEY;
string subName;
integer menuchannel;
integer menuhandle;
string location;
list avsNearby;
float sensorRange = 8.0;
float sensorRepeat = 300.0;
integer listenhandle;
list settings;

integer listenCap = 20; // Distance for owner to be from sub for listener to shut off
integer listenCheckRepeat = 5;
float sensorTiming;
float sensorCountdown = 0;
integer listenEnabled; // Toggled by the sensor; only applies if listen is actually on

updateSensor()
{
    llSensorRemove();
    float range = listenCap;
    if (!enabled("listen") && enabled("radar"))
    {
        range = sensorRange;
    }
    if (enabled("listen"))
    {
        sensorTiming = listenCheckRepeat;
    }
    else
    {
        sensorTiming = sensorRepeat;
    }
    if (enabled("listen"))// || enabled("radar"))
    {
        llSensorRepeat("" ,"" , AGENT, range, PI, listenCheckRepeat);
    }
    else if (enabled("radar"))
    {
        llSensorRepeat("" ,"" , AGENT, range, PI, sensorRepeat);
    }
}

integer enabled(string token)
{
    integer index = llListFindList(settings, [token]);
    if(index == -1)
    {
        return FALSE;
    }
    else
    {
        if(llList2String(settings, index + 1) == "on")
        {
            return TRUE;
        }
        else if(llList2String(settings, index + 1) == "off")
        {
            return FALSE;
        }
        else
        {
            return FALSE;
        }
    }
}

string GetTimestamp() // Return a string of the date and time
{
    integer t = (integer)llGetWallclock(); // seconds since midnight

    return GetPSTDate() + " " + (string)(t / 3600) + ":" + PadNum((t % 3600) / 60) + ":" + PadNum(t % 60);
}

string PadNum(integer value)
{
    if(value < 10)
    {
        return "0" + (string)value;
    }
    return (string)value;
}

string GetPSTDate()
{ //Convert the date from UTC to PST if GMT time is less than 8 hours after midnight (and therefore tomorow's date).
    string DateUTC = llGetDate();
    if (llGetGMTclock() < 28800) // that's 28800 seconds, a.k.a. 8 hours.
    {
        list DateList = llParseString2List(DateUTC, ["-", "-"], []);
        integer year = llList2Integer(DateList, 0);
        integer month = llList2Integer(DateList, 1);
        integer day = llList2Integer(DateList, 2);
        day = day - 1;
        return (string)year + "-" + (string)month + "-" + (string)day;
    }
    return llGetDate();
}

DialogSpy(key id)
{
    currentmenu = "spy";
    list buttons ;
    string text = "These are ONLY Primary Owner options:\n";
    text += "Trace turns on/off notices if the sub teleports.\n";
    text += "Radar turns on/off a report every "+ (string)((integer)sensorRepeat/60) + " of who joined  or left " + subName + " in a range of " + (string)((integer)sensorRange) + "m.\n";
    text += "Listen turns on/off if you get directly said what " + subName + " says in public chat.\n";
    text += "This menu will time out in " + (string)timeout + " seconds.";
    
    if(enabled("trace"))
    {
        buttons += ["Trace Off"];
    }
    else
    {
        buttons += ["Trace On"];
    }
    if(enabled("radar"))
    {
        buttons += ["Radar Off"];
    }
    else
    {
        buttons += ["Radar On"];
    }
    if(enabled("listen"))
    {
        buttons += ["Listen Off"];
    }
    else
    {
        buttons += ["Listen On"];
    }
    buttons += ["RadarSettings"];
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    menuhandle = llListen(menuchannel, "", id, "");
    llDialog(id, text, buttons, menuchannel);
    llSetTimerEvent(timeout);
}

DialogRadarSettings(key id)
{
    currentmenu = "radarsettings";
    list buttons;
    string text = "Choose the report repeat and sensor range:\n";
    text += "Current Report Range is: " + (string)((integer)sensorRange) + " meter.\n";
    text += "Current Report Frequenz is: " + (string)((integer)sensorRepeat/60) + " minutes.\n";
    buttons += ["5 meter", "8 meter", "10 meter", "15 meter"];
    buttons += ["2 minutes", "5 minutes", "8 minutes", "10 minutes","15 minutes", "30 minutes", "60 minutes"];
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    menuhandle = llListen(menuchannel, "", id, "");
    llDialog(id, text, buttons, menuchannel);
    llSetTimerEvent(45.0);    
}

SendIM(key id, string str)
{
    if (id != NULL_KEY)
    {
        llInstantMessage(id, str);
    }
}
list FillMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) != 3 && llGetListLength(in) != 6 && llGetListLength(in) != 9 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    return in;
}

list RestackMenu(list in)
{ //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);    
    return out;
}

SendNotify(string newlocation)
{
    string message = subName + " teleported from " + location + " to " +  newlocation + " at "  + GetTimestamp() + ".";
    SendIM(owner, message);
    location = newlocation;
}

ReportAviList(list sensed)
{
    string message = "Avis in a " + (string)((integer)sensorRange) + "m range around " + subName + ":\n";
    if(llGetListLength(sensed))
    {
        message += llDumpList2String(sensed, ",");
    }
    else
    {
        message += "None.";
    }
    SendIM(owner, message);
}

SaveSettings(string str, key id)
{
    list temp = llParseString2List(str, [" "], []);
    string option = llList2String(temp, 0);
    string value = llList2String(temp, 1);
    integer index = llListFindList(settings, [option]);
    if(index == -1)
    {
        settings += temp;
    }
    else
    {
        settings = llListReplaceList(settings, [value], index + 1, index + 1);
    }
    string save = llDumpList2String(settings, ",");
    llMessageLinked(LINK_SET, HTTPDB_SAVE, save, NULL_KEY);
    if(currentmenu == "spy")
    {
        llMessageLinked(LINK_SET, SUBMENU, submenu, id);
    }
}

SetSettings()
{
    integer i;
    integer listlength = llGetListLength(settings);
    for(i = 1; i < listlength; i += 2)
    {
        string option = llList2String(settings, i);
        string value = llList2String(settings, i + 1);
        if(option == "listen")
        {
            if(value == "on")
            {
                listenhandle = llListen(0, subName, llGetOwner(), "");
            }
            else if(value == "off")
            {
                llListenRemove(listenhandle);
            }
        }
        else if(option == "meter")
        {
            sensorRange = (float)value;
        }
        else if(option == "minutes")
        {
            sensorRepeat = (float)value;
        }
    }
    sensorCountdown = sensorRepeat;
    updateSensor();
}

TurnAllOff()
{ // set all values to off and remove sensor and listener
    llSensorRemove();
    llListenRemove(listenhandle);
    list temp = ["radar", "listen", "trace"];
    integer i;
    for (i=0; i < llGetListLength(temp); i++)
    {
        string option = llList2String(temp, i);
        integer index = llListFindList(settings, [option]);
        if(index != -1)
        {
           settings = llListReplaceList(settings, ["off"], index + 1, index + 1);
        }
    }
    string save = llDumpList2String(settings, ",");
    llMessageLinked(LINK_SET, HTTPDB_SAVE, save, NULL_KEY);
}

default
{
    state_entry()
    {
        menuchannel = -llFloor(llFrand(999999.0))  - 9999;
        subName = llKey2Name(llGetOwner());
        settings = [dbtoken + "="];
        location=llGetRegionName();
        llSleep(1.0);
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if(id == llGetOwner() && channel == 0)
        {
            if (listenEnabled)
            {
                string objectName = llGetObjectName();
                if(llGetSubString(message, 0, 2) == "/me")
                {
                    llSetObjectName(subName + " emoted: " + subName);
                }
                else
                {
                    llSetObjectName(subName + " said");
                }
                SendIM(owner, message);
                llSetObjectName(objectName);
            }
        }
        else if(channel == menuchannel)
        {
            llListenRemove(menuhandle);
            llSetTimerEvent(0.0);
            if(message == UPMENU)
            {
                if(currentmenu == "radarsettings")
                {
                    DialogSpy(id);
                }
                else
                {
                    llMessageLinked(LINK_SET, SUBMENU, parentmenu, id);
                }
            }
            else if(currentmenu == "radarsettings")
            {
                list temp = llParseString2List(message, [" "], []);
                float value = (float)llList2String(temp,0);
                string option = llList2String(temp,1);
                if(option == "meter")
                {
                    sensorRange = value;
                    SaveSettings(option + " " + (string)value, id);
                    SendIM(id, "You change the Report Range to " + (string)((integer)value) + " meters.");
                }
                else if(option == "minutes")
                {
                    sensorRepeat = value * 60;
                    SaveSettings(option + " " + (string)sensorRepeat, id);
                    sensorCountdown=sensorRepeat;
                    SendIM(id, "You changed the Report Frequency to " + (string)((integer)value) + " minutes.");
                }
                if(enabled("radar"))
                {
                    updateSensor();
                }
                DialogSpy(id);
            }
            else if(message != " ")
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, llToLower(message), id);
            }
        }
    }
        
    link_message(integer sender, integer auth, string str, key id)
    {  //only the primary owner can use this !!
        if (auth == COMMAND_OWNER)
        {
            owner = id;
            if(str == "spy")
            {
                DialogSpy(id);
            }
            if(str == "radarsettings")
            {
                DialogRadarSettings(id);
            }
            else if(str == "trace on")
            {
                SaveSettings(str, id);
                SendIM(id, "Teleport tracing is now turned on for " + subName + ".");
                location=llGetRegionName();
            }
            else if(str == "trace off")
            {
                SaveSettings(str, id);
                SendIM(id, "Teleport tracing is now turned off for " + subName + ".");
            }
            else if(str == "radar on")
            {
                SaveSettings(str, id);
                sensorCountdown=sensorRepeat;
                updateSensor();
                SendIM(id, "Avatar reporting a range of " + (string)((integer)sensorRange) + "m your sub " + subName + " is now turned ON.");
            }
            else if(str == "radar off")
            {
                SaveSettings(str, id);
                updateSensor();
                SendIM(id, "Avatar reporting in a range of " + (string)((integer)sensorRange) + "m your sub " + subName + " is now turned OFF.");
            }
            else if(str == "listen on")
            {
                SaveSettings(str, id);
                listenhandle = llListen(0, subName, llGetOwner(), "");
                updateSensor();
                SendIM(id, "You listen now to everything your sub " + subName + " says in public chat.");
            }
            else if(str == "listen off")
            {
                SaveSettings(str, id);
                llListenRemove(listenhandle);
                updateSensor();
                SendIM(id, "You stopped to listen your sub " + subName + "'s public chat.");
            }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if(token == "owner")
            {
                owner = (key)llList2String(llParseString2List(value, [","], []), 0);
            }
            else if (token == dbtoken)
            { //llOwnerSay("Loading Spy Settings: " + value + " from Database.");
                settings = llParseString2List(str, [","], []);
                SetSettings();
            }
        }
        else if (auth == COMMAND_OWNER && str == "reset")
        {
            llResetScript();
        }
        else if (auth == COMMAND_WEARER && (str == "reset" || str == "runaway"))
        {
            llResetScript();
        }
        else if (auth == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            DialogSpy(id);
        }
        else if((auth > COMMAND_OWNER) && (auth <= COMMAND_EVERYONE))
        {
            list cmds = ["trace on","trace off", "radar on", "radar off", "listen on", "listen off"];
            if (~llListFindList(cmds, [str]))
            {
                SendIM(id, "Sorry, only the primary owner can set trace on or off.");
            }
        }
        else if(auth == COMMAND_SAFEWORD)
        {//we recieved a safeword command, turn all off
            TurnAllOff();
        }
    }
    
    on_rez(integer param)
    {     //should reset on rez to make sure the parent menu gets populated with our button
        llResetScript();
    }

    sensor(integer num_detected)
    {
        integer i;
        string detectedName;
        list allSensed = [];
        vector position = llGetPos();
        listenEnabled = 1;
        for(i=0; i < num_detected; i++)
        {
            detectedName = llDetectedName(i);
            if(detectedName != subName)
            {
                float distance = llVecDist(llDetectedPos(i), position);
                if (distance <= listenCap && llDetectedKey(i) == owner)
                {
                    listenEnabled = 0; // Shut off listener because owner is present
                }
                if (distance <= sensorRange && enabled("radar"))
                {
                    allSensed += [detectedName];
                }
            }
        }
        sensorCountdown -= sensorTiming;
        if (sensorCountdown <= 0 && enabled("radar"))
        {
            ReportAviList(allSensed);
            sensorCountdown = sensorRepeat;
        }
    }
    no_sensor()
    {
        listenEnabled = 1; // If nobody is present, then owner is not present
        
        sensorCountdown -= sensorTiming;
        if (sensorCountdown <= 0 && enabled("radar"))
        {
            ReportAviList([]);
            sensorCountdown = sensorRepeat;
        }
    }
    attach(key id)
    {
        if(id != NULL_KEY)
        {
            location = llGetRegionName();
        }
    }
    changed(integer change)
    {
        if(enabled("trace"))
        {
            if((change & CHANGED_TELEPORT) || (change & CHANGED_REGION))
            {
                SendNotify(llGetRegionName());
            }
        }
    }
    timer()
    {
        llSetTimerEvent(0.0);
        llListenRemove(menuhandle);
    }
}
