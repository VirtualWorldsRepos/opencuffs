//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//on getting menu request, give element menu
//on getting element type, give Hide and Show buttons
//on hearing "hide" or "Show", do that for the current element type

string parentmenu = "Appearance";
string submenu = "Hide/Show";
integer timeout = 60;
integer listener;
list elements;
integer listenchannel;
string dbtoken = "elementalpha";
list alphasettings;
string ignore = "nohide";
string currentelement;

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

//5000 block is reserved for IM slaves

string HIDE = "Hide";
string SHOW = "Show";
//string UPMENU = "â†‘";
//string MORE = "â†’";
string UPMENU = "^";

string SHOWN = "Shown";
string HIDDEN = "Hidden";
string ALL = "All";

SetAllElementsAlpha(float alpha)
{
    //loop through element list, setting all alphas
    //integer n;
    //integer stop = llGetListLength(elements);
    //for (n = 0; n < stop; n++)
    //{
    //    string element = llList2String(elements, n);
    //    SetElementAlpha(element, alpha);
    //}

    llSetLinkAlpha(LINK_SET, alpha, ALL_SIDES);
    //set alphasettings of all elements to alpha (either 1.0 or 0.0 here)
    alphasettings = [];
    integer n;
    integer stop = llGetListLength(elements);
    for (n = 0; n < stop; n++)
    {
        string element = llList2String(elements, n);
        alphasettings += [element, alpha];
    }
}

SetElementAlpha(string element_to_set, float alpha)
{
    //loop through links, setting color if element type matches what we're changing
    //root prim is 1, so start at 2
    integer n;
    integer linkcount = llGetNumberOfPrims();
    for (n = 2; n <= linkcount; n++)
    {
        string element = ElementType(n);
        if (element == element_to_set)
        {
            //set link to new color
            //llSetLinkPrimitiveParams(n, [PRIM_COLOR, ALL_SIDES, color, 1.0]);
            llSetLinkAlpha(n, alpha, ALL_SIDES);

            //update element in list of settings
            integer index = llListFindList(alphasettings, [element]);
            if (index == -1)
            {
                alphasettings += [element, alpha];
            }
            else
            {
                alphasettings = llListReplaceList(alphasettings, [alpha], index + 1, index + 1);
            }
        }
    }
}

SaveAlphaSettings()
{
    if (llGetListLength(alphasettings)>0)
    {
        //dump list to string and do httpdb save
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(alphasettings, ","), NULL_KEY);
    }
    else
    {
        //dump list to string and do httpdb save
        llMessageLinked(LINK_THIS, HTTPDB_DELETE, dbtoken, NULL_KEY);
    }

}

ElementMenu(key av)
{
    currentelement = "";
    string prompt = "Pick which part of the collar you would like to hide or show";
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";
    list buttons;

    //loop through elements, show appropriate buttons and prompts if hidden or shown

    elements = llListSort(elements, 1, TRUE);

    integer n;
    integer stop = llGetListLength(elements);
    for (n = 0; n < stop; n++)
    {
        string element = llList2String(elements, n);
        integer index = llListFindList(alphasettings, [element]);
        if (index == -1)
        {
            //element not found in settings list.  Assume it's currently shown
            //prompt += "\n" + element + " (" + SHOWN + ")";
            buttons += HIDE + " " + element;
        }
        else
        {
            float alpha = (float)llList2String(alphasettings, index + 1);
            if (alpha)
            {
                //currently shown
                //prompt += "\n" + element + " (" + SHOWN + ")";
                buttons += HIDE + " " + element;
            }
            else
            {
                //not currently shown
                //prompt += "\n" + element + " (" + HIDDEN + ")";
                buttons += SHOW + " " + element;
            }
        }
    }

    buttons += [SHOW + " " + ALL, HIDE + " " + ALL];

    buttons += [UPMENU] ;
    buttons = RestackMenu(buttons);
    llListenRemove(listener);
    listenchannel = - llRound(llFrand(999999.0)) - 9999;
    listener = llListen(listenchannel, "", av, "");
    llDialog(av, prompt, buttons, listenchannel);
    llSetTimerEvent((float)timeout);
}
string ElementType(integer linknumber)
{
    string desc = (string)llGetObjectDetails(llGetLinkKey(linknumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to
    //not appear in the color or texture menus
    list params = llParseString2List(desc, ["~"], []);
    if (~llListFindList(params, [ignore]) || desc == "" || desc == " " || desc == "(No Description)")
    {
        return ignore;
    }
    else
    {
        return llList2String(params, 0);
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
        if (!(~llListFindList(elements, [element])) && element != ignore)
        {
            elements += [element];
            //llSay(0, "added " + element + " to elements");
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
    return out;
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

default
{
    state_entry()
    {
        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        string prefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (prefix != "")
        {
            dbtoken = prefix + dbtoken;
        }

        BuildElementList();
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, "hidden", NULL_KEY);
        //llMessageLinked(LINK_THIS, HTTPDB_REQUEST, dbtoken, NULL_KEY);
        /* // no more needed
            llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        */
    }

    on_rez(integer param)
    {
        llResetScript();
    }

    link_message(integer sender, integer auth, string str, key id)
    {
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            if (str == "hide")
            {
                SetAllElementsAlpha(0.0);
                SaveAlphaSettings();
            }
            else if (str == "show")
            {
                SetAllElementsAlpha(1.0);
                SaveAlphaSettings();
            }
            else if (str == "hidemenu")
            {
                 ElementMenu(id);
            }
            else if (str == "settings")
            {
                if (llGetAlpha(ALL_SIDES) == 0.0)
                {
                    llInstantMessage(id, "Hidden");
                }
            }
            else if (startswith(str, "setalpha"))
            {
                list params = llParseString2List(str, [" "], []);
                string element = llList2String(params, 1);
                float alpha = (float)llList2String(params, 2);
                SetElementAlpha(element, alpha);
                SaveAlphaSettings();
            }
            else if (auth == COMMAND_OWNER && str == "reset")
            {
                SetAllElementsAlpha(1.0);
                /* // no more self - resets
                    llResetScript();
                */
                }
            //else if (auth == COMMAND_WEARER && (str == "reset" || str == "runaway"))
            else if ((auth == COMMAND_WEARER || id == llGetOwner()) && (str == "reset" || str == "runaway"))
            {
                SetAllElementsAlpha(1.0);
                /* // no more self - resets
                    llResetScript();
                */
                }
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == dbtoken)
            {
                //we got the list of alphas for each element
                alphasettings = llParseString2List(value, [","], []);
                integer n;
                integer stop = llGetListLength(alphasettings);
                for (n = 0; n < stop; n = n + 2)
                {
                    string element = llList2String(alphasettings, n);
                    float alpha = (float)llList2String(alphasettings, n + 1);
                    SetElementAlpha(element, alpha);
                }
            }
        }
        else if (auth == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            //give element menu
            ElementMenu(id);
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(listener);
        llSetTimerEvent(0);
        if (message == UPMENU)
        {
            if (currentelement == "")
            {
                //main menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else
            {
                currentelement = "";
                ElementMenu(id);
            }
        }
        else
        {
            //get "Hide" or "Show" and element name
            list params = llParseString2List(message, [" "], []);
            string cmd = llList2String(params, 0);
            string element = llList2String(params, 1);
            float alpha;
            if (cmd == HIDE)
            {
                alpha = 0.0;
            }
            else if (cmd == SHOW)
            {
                alpha = 1.0;
            }

            if (element == ALL)
            {
                if (cmd == SHOW)
                {
                    SetAllElementsAlpha(1.0);
                }
                else if (cmd == HIDE)
                {
                    SetAllElementsAlpha(0.0);
                }
            }
            else if (element != "")//ignore empty element strings since they won't work anyway
            {
                SetElementAlpha(element, alpha);
            }
            SaveAlphaSettings();
            ElementMenu(id);
        }
    }

    timer()
    {
        llSetTimerEvent(0.0);
        llListenRemove(listener);
    }
}
