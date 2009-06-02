// Spy script for the OpenCollar Project (c)
// "Copyright 2008 OpenCollar" written by Lulu Pink
//  Distributed under the term of the GNU General Public License


//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;

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

string UPMENU = "~PrevMenu~";
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

integer enabled(string token)
{
    integer index = llListFindList(settings, [token]);
    integer yes;
    if(index == -1)
        yes = FALSE;
    else
    {
        if(llList2String(settings, index + 1) == "on")
            yes = TRUE;
        else if(llList2String(settings, index + 1) == "off")
            yes = FALSE;
    }
    return yes;
}
// Return a string of the date and time
string GetTimestamp()
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
{
    //Convert the date from UTC to PST if GMT time is less than 8 hours after midnight (and therefore tomorow's date).
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
    
    if(enabled("trace"))
        buttons += ["Trace Off"];
    else
        buttons += ["Trace On"];
    if(enabled("radar"))
        buttons += ["Radar Off"];
    else
        buttons += ["Radar On"];
    if(enabled("listen"))
        buttons += ["Listen Off"];
    else
        buttons += ["Listen On"];
    buttons += ["RadarSettings"];
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    menuchannel = -(integer)llFrand(9999.0) + 3000;
    menuhandle = llListen(menuchannel, "", id, "");
    llDialog(id, text, buttons, menuchannel);
    llSetTimerEvent(30.0);
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
    menuchannel = -(integer)llFrand(9999.0) + 3000;
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
{
    //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) != 3 && llGetListLength(in) != 6 && llGetListLength(in) != 9 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    return in;
}

list RestackMenu(list in)
{
    //re-orders a list so dialog buttons start in the top row
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

ReportAvis(list new, list all)
{
    avsNearby += new;
    integer iAvs = llGetListLength(avsNearby);
    integer iNew = llGetListLength(new);
    integer i;
    list avsLeft;
    string reportNew;
    string reportLeft;
    string message;
    string time = (string)((integer)(sensorRepeat/60));
    for(i = 0; i < iAvs; i++)
    {
        string avName = llList2String(avsNearby, i);
        if(llListFindList(all, [avName]) == -1)
        {
            //avi left range
            avsLeft += [avName];
            integer index = llListFindList(avsNearby, [avName]);
            avsNearby = llListReplaceList(avsNearby, [], index, index);
        }
    }
    message = "Avis in a " + (string)((integer)sensorRange) + "m range around " + subName + ":\n" + llDumpList2String(all, ",");
    SendIM(owner, message);
    if(iNew) // if list new is empty iNew = 0 so false
    {
        reportNew = llDumpList2String(new, ", ");
        message = "Avis that joined " + subName + " in the last " + time + " minutes:\n" + reportNew;
        SendIM(owner, message);
    }
    if(llGetListLength(avsLeft))
    {
        reportLeft = llDumpList2String(avsLeft, ", ");
        message = "Avis that left " + subName + " in the last " + time + " minutes:\n" + reportLeft;
        SendIM(owner, message);
    }
}
ReportAviList(list sensed)
{
    string message = "Avis in a " + (string)((integer)sensorRange) + "m range around " + subName + ":\n";
    if(llGetListLength(sensed))
        message += llDumpList2String(sensed, ",");
    else
        message += "None.";
    SendIM(owner, message);
}

SaveSettings(string str, key id)
{
    list temp = llParseString2List(str, [" "], []);
    string option = llList2String(temp, 0);
    string value = llList2String(temp, 1);
    integer index = llListFindList(settings, [option]);
    if(index == -1)
        settings += temp;
    else
        settings = llListReplaceList(settings, [value], index + 1, index + 1);
    string save = llDumpList2String(settings, ",");
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, save, NULL_KEY);
    if(currentmenu == "spy")
        llMessageLinked(LINK_THIS, SUBMENU, submenu, id);
}

SetSettings()
{
    integer i;
    integer listlength = llGetListLength(settings);
    for(i = 1; i < listlength; i += 2)
    {
        string option = llList2String(settings, i);
        string value = llList2String(settings, i + 1);
        if(option == "radar")
        {
            if(value == "on")
                llSensorRepeat("" ,"" , AGENT, sensorRange, PI, sensorRepeat);
            else if(value == "off")
                llSensorRemove();
        }
        else if(option == "listen")
        {
            if(value == "on")
                listenhandle = llListen(0, subName, llGetOwner(), "");
            else if(value == "off")
                llListenRemove(listenhandle);
        }
        else if(option == "meter")
            sensorRange = (float)value;
        else if(option == "minutes")
            sensorRepeat = (float)value;
            
    }
}

ClearHttpDBSettings()
{
    settings = [dbtoken + "="];
    string save = llDumpList2String(settings, ",");
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, save, NULL_KEY);
}

default
{
    state_entry()
    {
        subName = llKey2Name(llGetOwner());
        settings = [dbtoken + "="];
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
//        llMessageLinked(LINK_THIS, HTTPDB_REQUEST, dbtoken, NULL_KEY);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if(id == llGetOwner() && channel == 0)
        {
            string objectName = llGetObjectName();
            if(llGetSubString(message, 0, 2) == "/me")
                llSetObjectName(subName + " emoted: " + subName);
            else
                llSetObjectName(subName + " said");
            SendIM(owner, message);
            llSetObjectName(objectName);
        }
        else
        {
            llListenRemove(menuhandle);
            llSetTimerEvent(0.0);
            if(message == UPMENU)
            {
                if(currentmenu == "radarsettings")
                    DialogSpy(id);
                else
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
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
                    SendIM(id, "You changed the Report Frequency to " + (string)((integer)value) + " minutes.");
                }
                if(enabled("radar"))
                {
                    llSensorRemove();
                    llSensorRepeat("" ,"" , AGENT, sensorRange, PI, sensorRepeat);
                }
                DialogSpy(id);
            }
            else if(message != " ")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, llToLower(message), id);
            }
        }
    }
        
    link_message(integer sender, integer auth, string str, key id)
    {
        //only the primary owner can use this !!
        if (auth == COMMAND_OWNER)
        {
            owner = id;
            if(str == "spy")
                DialogSpy(id);
            if(str == "radarsettings")
                DialogRadarSettings(id);
            else if(str == "trace on")
            {
                SaveSettings(str, id);
                SendIM(id, "Teleport tracing is now turned on for " + subName + ".");
            }
            else if(str == "trace off")
            {
                SaveSettings(str, id);
                SendIM(id, "Teleport tracing is now turned off for " + subName + ".");
            }
            else if(str == "radar on")
            {
                SaveSettings(str, id);
                llSensorRepeat("" ,"" , AGENT, sensorRange, PI, sensorRepeat);
                SendIM(id, "Avatar reporting a range of " + (string)((integer)sensorRange) + "m your sub " + subName + " is now turned ON.");
            }
            else if(str == "radar off")
            {
                SaveSettings(str, id);
                llSensorRemove();
                SendIM(id, "Avatar reporting in a range of " + (string)((integer)sensorRange) + "m your sub " + subName + " is now turned OFF.");
            }
            else if(str == "listen on")
            {
                SaveSettings(str, id);
                listenhandle = llListen(0, subName, llGetOwner(), "");
                SendIM(id, "You listen now to everything your sub " + subName + " says in public chat.");
            }
            else if(str == "listen off")
            {
                SaveSettings(str, id);
                llListenRemove(listenhandle);
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
            {
                //llOwnerSay("Loading Spy Settings: " + value + " from Database.");
                settings = llParseString2List(str, [","], []);
                SetSettings();
            }
        }
        else if (auth == COMMAND_OWNER && str == "reset")
        {
            //clearing settings should not be necessary, as the httpdb script deletes *all* of the av's tokens in the db on reset
            //if every script did this, then "reset" would become just as clogged with link messages as startup used to be
            //ClearHttpDBSettings();
            llResetScript();
        }  
        else if (auth == COMMAND_WEARER && (str == "reset" || str == "runaway"))
        {
            //ClearHttpDBSettings();
            llResetScript();
        }
        else if (auth == MENUNAME_REQUEST && str == parentmenu)
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        else if (auth == SUBMENU && str == submenu)
            DialogSpy(id);
        else if((auth > COMMAND_OWNER) && (auth <= COMMAND_EVERYONE))
        {
            list cmds = ["trace on","trace off", "radar on", "radar off", "listen on", "listen off"];
            if (~llListFindList(cmds, [str]))
            {
                SendIM(id, "Sorry, only the primary owner can set trace on or off.");                
            }
            
            //why is this necessary?
            //llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
            //
        }
    }
    
    on_rez(integer param)
    {
        //should reset on rez to make sure the parent menu gets populated with our button
        llResetScript();
    }

    sensor(integer num_detected)
    {
        integer i;
        string detectedName;
//        list newSensed = [];
        list allSensed = [];
        for(i=0; i < num_detected; i++)
        {
            detectedName = llDetectedName(i);
            if(detectedName != subName)
            {
                allSensed += [detectedName];
//                if(llListFindList(avsNearby, [detectedName]) == -1)
//                    newSensed += [detectedName];
            }
//            allSensed += [detectedName];
        }
//        ReportAvis(newSensed, allSensed);
        ReportAviList(allSensed);
    }
    no_sensor()
    {
        ReportAviList([]);
//        ReportAvis([], []);
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
