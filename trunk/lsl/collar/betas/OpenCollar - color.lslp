//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//color

//on getting color command, give menu to choose which element, followed by menu to pick color

list elements;
string currentelement = "";
string currentcategory = "";
list categories = ["Blues", "Browns", "Grays", "Greens", "Purples", "Reds", "Yellows"];
list colorsettings;
string parentmenu = "Appearance";
string submenu = "Colors";

string dbtoken = "colorsettings";

key user;
key httpid;

list colors;
integer stridelength = 2;
integer page = 0;

integer listenchannel = 202983;//just something i randomly chose
integer listenhandle;
integer timeout = 60;

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

//5000 block is reserved for IM slaves

//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";

key wearer;

Notify(key id, string msg, integer alsoNotifyWearer) {
    if (id == wearer) {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) {
            llOwnerSay(msg);
        }
    }    
}

list RestackMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) % 3 != 0 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    //look for ^ and > in the menu
    integer m = llListFindList(in, [MORE]);
    if (m != -1)
    {
        in = llDeleteSubList(in, m, m);
    }
    integer u = llListFindList(in, [UPMENU]);
    if (u != -1)
    {
        in = llDeleteSubList(in, u, u);
    }
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);
    //make sure we move ^ and > to position 1 and 2
    if (u != -1)
    {
        out = llListInsertList(out, [UPMENU], 1);
    }
    if (m != -1)
    {
        out = llListInsertList(out, [MORE], 2);
    }
    return out;
}

CategoryMenu(key av)
{
    //give av a dialog with a list of color cards 
    string prompt = "Pick a Color.";
    prompt += "  (Menu will time out in " + (string)timeout + " seconds.)\n";
    list buttons = categories;
    //buttons = llListSort(buttons, 1, TRUE);
    buttons += [UPMENU];
    llListenRemove(listenhandle);
    listenhandle = llListen(listenchannel, "", av, "");
    buttons = RestackMenu(buttons);
    llDialog(av, prompt, buttons, listenchannel);    
    llSetTimerEvent((float)timeout);    
}

ColorMenu(key av)
{
    string prompt = "Pick a Color.";
    prompt += "  (Menu will time out in " + (string)timeout + " seconds.)\n";
    list buttons;
    
    if (llGetListLength(colors) <= stridelength * 11)
    {
        integer n;
        for (n = 0; n < llGetListLength(colors); n = n + 2)
        {
            buttons += llList2List(colors, n, n);
        }        
        buttons += [UPMENU];        
    }
    else
    {
        //there are more than 12 colors, use page number in adding buttons
        integer n;
        for (n=0;n<10;n++)
        {
            string name = llList2String(colors, n * stridelength + (page * 10 * stridelength));
            if (name != "")
            {
                //prompt += "\n" + (string)(n + (page * 10) + 1) + " - " + name;
                //buttons += [(string)(n + (page * 10) + 1)];        
                buttons += [name];        
            }
        }
        //add the More button
        buttons += [UPMENU];        
        buttons += [MORE];
    }
    
    llListenRemove(listenhandle);
    listenhandle = llListen(listenchannel, "", av, "");
    buttons = RestackMenu(buttons);
    llDialog(av, prompt, buttons, listenchannel);    
    llSetTimerEvent((float)timeout);
}

ElementMenu(key av)
{
    string prompt = "Pick which part of the collar you would like to recolor";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";    
    list buttons = llListSort(elements, 1, TRUE);
    buttons += [UPMENU] ;  
    buttons = RestackMenu(buttons);      
    llListenRemove(listenhandle);
    listenhandle = llListen(listenchannel, "", av, "");
    llDialog(av, prompt, buttons, listenchannel);    
    llSetTimerEvent((float)timeout);
}

string ElementType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to 
    //not appear in the color or texture menus
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, ["nocolor"]) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return "nocolor";
    }
    else
    {
        return llList2String(params, 0);
    }
}


LoadColorSettings()
{
    //llOwnerSay(llDumpList2String(colorsettings, ","));
    //loop through links, setting each's color according to entry in colorsettings list
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementType(n);
        integer index = llListFindList(colorsettings, [element]);
        vector color = (vector)llList2String(colorsettings, index + 1);        
        //llOwnerSay(llList2String(colorsettings, index + 1));
        if (index != -1)
        {
            //set link to new color
            llSetLinkColor(n, color, ALL_SIDES);
            //llSay(0, "setting link " + (string)n + " to color " + (string)color);
        }
    }        
}

BuildElementList()
{
    integer n;
    integer linkcount = llGetNumberOfPrims();
    
    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementType(n);
        if (!(~llListFindList(elements, [element])) && element != "nocolor")
        {
            elements += [element];
            //llSay(0, "added " + element + " to elements");
        }
    }    
}

SetElementColor(string element, vector color)
{
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string thiselement = ElementType(n);
        if (thiselement == element)
        {
            //set link to new color
            //llSetLinkPrimitiveParams(n, [PRIM_COLOR, ALL_SIDES, color, 1.0]);
            llSetLinkColor(n, color, ALL_SIDES);
        }
    }
    //create shorter string from the color vectors before saving
    string strColor = Vec2String(color);
    //change the colorsettings list entry for the current element
    integer index = llListFindList(colorsettings, [element]);
    if (index == -1)
    {
        colorsettings += [element, strColor];
    }
    else
    {
        colorsettings = llListReplaceList(colorsettings, [strColor], index + 1, index + 1);
    }
    //save to httpdb
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(colorsettings, "~"), NULL_KEY);
    //currentelement = "";    
}



integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

string Vec2String(vector vec)
{
    list parts = [vec.x, vec.y, vec.z];
    
    integer n;
    for (n = 0; n < 3; n++)
    {
        string str = llList2String(parts, n);
        //remove any trailing 0's or .'s from str
        while (~llSubStringIndex(str, ".") && (llGetSubString(str, -1, -1) == "0" || llGetSubString(str, -1, -1) == "."))
        {
            str = llGetSubString(str, 0, -2);
        }
        parts = llListReplaceList(parts, [str], n, n);
    } 
    return "<" + llDumpList2String(parts, ",") + ">";
}

default
{
    state_entry()
    {
        wearer = llGetOwner();
        listenchannel = -(llRound(llFrand(999999)) + 99999);
        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        string prefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (prefix != "")
        {
            dbtoken = prefix + dbtoken;
        }  
        
        //loop through non-root prims, build element list
        BuildElementList();
         /* // no more needed
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        */        
    }

    link_message(integer sender, integer auth, string str, key id)
    {
        //owner, secowner, group, and wearer may currently change colors
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER && str == "colors")
        {
            if (id!=wearer && auth!=COMMAND_OWNER)
            {
                Notify(id,"You are not allowed to change the colors.", FALSE);
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else
            {
                currentelement = "";
                ElementMenu(id);
            }
        }
        else if (str == "reset" && (auth == COMMAND_OWNER || auth == COMMAND_WEARER))
        {
            //clear saved settings            
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);      
            llResetScript();
        }
        else if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            if (str == "settings")
            {
                Notify(id, "Color Settings: " + llDumpList2String(colorsettings, ","),FALSE);
            }
            else if (startswith(str, "setcolor"))
            {
                if (id!=wearer && auth!=COMMAND_OWNER)
                {
                    Notify(id,"You are not allowed to change the colors.", FALSE);
                }
                else
                {
                    list params = llParseString2List(str, [" "], []);
                    string element = llList2String(params, 1);
                    params = llParseString2List(str, ["<"], []);
                    vector color = (vector)("<"+llList2String(params, 1));
                    SetElementColor(element, color);                
                }
            }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == dbtoken)
            {
                colorsettings = llParseString2List(value, ["~"], []);
                //llInstantMessage(llGetOwner(), "Loaded color settings.");
                LoadColorSettings();
            }            
        }
        else if (auth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //we don't know the authority of the menu requester, so send a message through the auth system
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "colors", id);
        }
    }
    
    http_response(key id, integer status, list meta, string body)
    {
        if (id == httpid)
        {
            if (status == 200)
            {
                //we'll have gotten several lines like "Chartreuse|<0.54118, 0.98431, 0.09020>"
                //parse that into 2-strided list of colorname, colorvector
                colors = llParseString2List(body, ["\n", "|"], []);
                colors = llListSort(colors, 2, TRUE);                
                ColorMenu(user);
            }
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (message == UPMENU)
        {
            if (currentelement == "")
            {
                //main menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);                            
            }
            else if (currentcategory == "")
            {
                currentelement = "";
                ElementMenu(id);
            }
            else
            {
                currentcategory = "";
                CategoryMenu(id);
            }
        }        
        else if (currentelement == "")
        {
            //we just got the element name
            currentelement = message;
            page = 0;            
            currentcategory = "";
            CategoryMenu(id);
        }
        else if (currentcategory == "")
        {
            colors = [];
            currentcategory = message;
            page = 0;            
            //ColorMenu(id);   
            user = id;         
            //line = 0;
            //dataid = llGetNotecardLine("colors-" + currentcategory, line);
            string url = "http://collardata.appspot.com/static/colors-" + currentcategory + ".txt";
            httpid = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
        }
        else if (message == MORE)
        {
            //increment page number
            if (llGetListLength(colors) > (11 * stridelength * (page + 1)))
            {
                //there are more pages
                page++;
            }
            else
            {
                page = 0;
            }           
            ColorMenu(id);                     
        }        
        else if (~llListFindList(colors, [message]))
        {
            //found a color, now set it
            integer index = llListFindList(colors, [message]);
            vector color = (vector)llList2String(colors, index + 1);
            //llSay(0, "color = " + (string)color);
            //loop through links, setting color if element type matches what we're changing
            //root prim is 1, so start at 2
            SetElementColor(currentelement, color);
            //ElementMenu(id);            
            ColorMenu(id);
        }            
    }
    
    timer()
    {
        //menus need to time out
        llListenRemove(listenhandle);
        llSetTimerEvent(0);
    }

    on_rez(integer param)
    {
        llResetScript();
    }
}
