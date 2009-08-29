//Nandana Singh mod for OpenCollar compatibility.

// ZHAO-II-interface - Ziggy Puff, 06/07

////////////////////////////////////////////////////////////////////////
// Interface script - handles all the UI work, sends link
// messages to the ZHAO-II 'engine' script
//
// Interface definition: The following link_message commands are
// handled by the core script. All of these are sent in the string
// field. All other fields are ignored
//
// ZHAO_RESET                          Reset script
// ZHAO_LOAD|<notecardName>            Load specified notecard
// ZHAO_NEXTSTAND                      Switch to next stand
// ZHAO_STANDTIME|<time>               Time between stands. Specified
//                                     in seconds, expects an integer.
//                                     0 turns it off
// ZHAO_AOON                           AO On
// ZHAO_AOOFF                          AO Off
// ZHAO_SITON                          Sit On
// ZHAO_SITOFF                         Sit Off
// ZHAO_RANDOMSTANDS                   Stands cycle randomly
// ZHAO_SEQUENTIALSTANDS               Stands cycle sequentially
// ZHAO_SETTINGS                       Prints status
// ZHAO_SITS                           Select a sit
// ZHAO_GROUNDSITS                     Select a ground sit
// ZHAO_WALKS                          Select a walk
//



// Added for OCCuffs:
// ZHAO_PAUSE                           Stops the AO temporary, AO gets reactivated on next rez if needed
// ZHAO_UNPAUSE                         Restart the AO if it was paused
// End of add OCCuffs




// So, to send a command to the ZHAO-II engine, send a linked message:
//
//   llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
//
////////////////////////////////////////////////////////////////////////

// Ziggy, 07/16/07 - Single script to handle touches, position changes, etc., since idle scripts take up
//
// Ziggy, 06/07:
//          Single script to handle touches, position changes, etc., since idle scripts take up
//          scheduler time
//          Tokenize notecard reader, to simplify notecard setup
//          Remove scripted texture changes, to simplify customization by animation sellers

// Fennec Wind, January 18th, 2007:
//          Changed Walk/Sit/Ground Sit dialogs to show animation name (or partial name if too long)
//          and only show buttons for non-blank entries.
//          Fixed minor bug in the state_entry, ground sits were not being initialized.
//

// Dzonatas Sol, 09/06: Fixed forward walk override (same as previous backward walk fix).


// Based on Francis Chung's Franimation Overrider v1.8

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307, USA.

// CONSTANTS
//////////////////////////////////////////////////////////////////////////////////////////////////////////

integer collarchannel = -782690;
// integer disabled = FALSE;//used to prevent manually turning AO on when collar has turned it off
// key disabler;//the key of th eobject that turned us off.  will be needed for a workaround later

// Help notecard
string helpNotecard = "READ ME FIRST - ZHAO-II";

// How long before flipping stand animations
integer standTimeDefault = 30;

// Listen channel for pop-up menu...
// should be different from channel used by ZHAO engine (-91234)
integer listenChannel = -91235;

integer listenHandle;                          // Listen handlers - only used for pop-up menu, then turned off
integer listenState = 0;                       // What pop-up menu we're handling now

// Overall AO state
integer zhaoOn = TRUE;

list attachPoints = [
    ATTACH_HUD_TOP_RIGHT,
    ATTACH_HUD_TOP_CENTER,
    ATTACH_HUD_TOP_LEFT,
    ATTACH_HUD_BOTTOM_RIGHT,
    ATTACH_HUD_BOTTOM,
    ATTACH_HUD_BOTTOM_LEFT
        ];

// For the on/off (root) prim
list rootPrimOffsets = [
    <0.0,  0.025, -0.05>,    // Top right
    <0.0,  0.025, -0.05>,    // Top middle
    <0.0, -0.025, -0.05>,    // Top left
    <0.0,  0.025,  0.10>,    // Bottom right
    <0.0,  0.00,  0.10>,    // Bottom middle
    <0.0, -0.025,  0.10>    // Bottom left
        ];

// For the menu (child)
list menuPrimOffsets = [
    <0.0, 0.0, -0.057>,
    <0.0, -0.057, 0.0>,
    <0.0, 0.0, -0.057>,
    <0.0, 0.0,  0.057>,
    <0.0, 0.0,  0.057>,
    <0.0, 0.0,  0.057>
        ];

// For the SitAnywhere Button (child)
list sitAWPrimOffsets = [
    <0.0, 0.0, -0.114>,
    <0.0, -0.114, 0.0>,
    <0.0, 0.0, -0.114>,
    <0.0, 0.0,  0.114>,
    <0.0, 0.0,  0.114>,
    <0.0, 0.0,  0.114>
        ];

vector onColor = <1.0, 1.0, 1.0>;
vector offColor = <0.5, 0.5, 0.5>;

// Interface script now keeps track of these states. The defaults
// match what the core script starts out with
integer sitOverride = TRUE;
integer sitAnywhere = FALSE;
integer StandAO = TRUE; // store state of standing ao
integer randomStands = FALSE;

key Owner = NULL_KEY;

integer isLocked = FALSE;
string UNLOCK = "*unlock*";
string LOCK = "*lock*";

// CODE
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Initialize listeners, and reset some status variables
Initialize() {
    Owner = llGetOwner();
    SetListener(Owner);
}

DoMenu(key rcpt)
{
    // The rows are inverted in the actual dialog box. This must match
    // the checks in the listen() handler
    list mainMenu = [
        "Walks", "Sits", "Ground Sits",
        "Sit On/Off", "Rand/Seq", "Stand Time",
        "Load", "Settings", "Next Stand",
        "Help", "Reset"
            ];
    /* //new for locking feature not yet implemented
        if (isLocked)
        {
            mainMenu = [UNLOCK] + mainMenu;
        }
    else
    {
        mainMenu = [LOCK] + mainMenu;
    }
    */
        if (sitAnywhere)
        {
            mainMenu = ["SitAnyOFF"] + mainMenu;
        }
    else
    {
        mainMenu = ["SitAnyON"] + mainMenu;
    }
    listenState = 0;
    llListenControl(listenHandle, TRUE);
    llDialog( rcpt, "Please select an option:", mainMenu, listenChannel );
}

DoPosition()
{
    // Using 2 for the child prim's link number... if you
    // want to add prims that need to be moved, you'll
    // have to do work here

    integer position = llListFindList(attachPoints, [llGetAttached()]);
    if (position != -1) {
        llSetPos((vector)llList2String(rootPrimOffsets, position));
        llSetLinkPrimitiveParams(2, [PRIM_POSITION, (vector)llList2String(menuPrimOffsets, position)]);
        llSetLinkPrimitiveParams(3, [PRIM_POSITION, (vector)llList2String(sitAWPrimOffsets, position)]);
    }
}

TurnOn()
{
    zhaoOn = TRUE;
    llSetColor(onColor, ALL_SIDES);
}

TurnOff()
{
    llSetColor(offColor, ALL_SIDES);
    zhaoOn = FALSE;
}

ToggleSitAnywhere()
{
    if (!StandAO)
    {
        llOwnerSay("SitAnywhere is not possible while you are in a collar pose.");
        return; // only allow changed if StandAO is enabled
    }
    
    if (sitAnywhere == TRUE) {
        llMessageLinked(LINK_SET, 0, "ZHAO_SITANYWHERE_OFF", NULL_KEY);
    } else {
            llMessageLinked(LINK_SET, 0, "ZHAO_SITANYWHERE_ON", NULL_KEY);
    }
    sitAnywhere = !sitAnywhere;
}

SetListener(key speaker)
{
    //randomize listenchannel to prevent crosstalk
    listenChannel = llRound(llFrand(999999) + 1);
    // On init, open a new listener...
    if ( listenHandle )
        llListenRemove( listenHandle );

    listenHandle = llListen( listenChannel, "", speaker, "" );

    // ... And turn it off
    llListenControl(listenHandle, FALSE);
}

integer isAttachedToHUD()
{
    if (llGetAttached() > 30)
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

// STATE
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

default {
    state_entry() {
        integer i;

        Initialize();
        DoPosition();

        // Sleep a little to let other script reset (in case this is a reset)
        llSleep(2.0);

        // We start out as AO ON
        llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
        llListen(collarchannel, "", NULL_KEY, "");

        //sit anywhere OFF by default
        llMessageLinked(LINK_SET, 0, "ZHAO_SITANYWHERE_OFF", NULL_KEY);
        sitAnywhere = FALSE;
    }

    on_rez( integer _code ) {
        Initialize();
    }

    attach( key _k ) {
        if ( _k != NULL_KEY )
        {
            DoPosition();
            if( isAttachedToHUD() )
            {
                llSetLinkAlpha(LINK_SET, 1.0, ALL_SIDES);
            }
            else
            {
                llSetLinkAlpha(LINK_SET, 0.0, ALL_SIDES);
            }
        }
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (str == "ZHAO_AOON")
        {
            //make sure button is bright, on is TRUE
            TurnOn();
        }
        else if (str == "ZHAO_AOOFF")
        {
            TurnOff();
        }
        else if (str == "ZHAO_MENU")
        {
            SetListener(id);
            DoMenu(id);
        }
        else if (str == "ZHAO_LOCK")
        {
            isLocked = TRUE;
            llOwnerSay("@detach=n");
        }
        else if (str == "ZHAO_UNLOCK")
        {
            isLocked = FALSE;
            llOwnerSay("detach=y");
        }
    }

    touch_start( integer _num ) {
        if (llDetectedLinkNumber(0) == 2) {
            // Menu prim... use number instead of name
            //DoMenu();
            llMessageLinked(LINK_SET, 0, "ZHAO_MENU", llDetectedKey(0));
        } else {
                //            if (disabled)
                //            {
                //                llInstantMessage(llGetOwner(), "AO currently disabled by collar.");
                //            }
                //            else
                //            {
                // On/Off prim
                if (llDetectedLinkNumber(0) == 3) {
                    ToggleSitAnywhere();
                }
            else
                if (zhaoOn) {
                    llMessageLinked(LINK_SET, 0, "ZHAO_AOOFF", NULL_KEY);
                } else {
                        llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
                }
            //            }
        }
    }

    listen( integer _channel, string _name, key _id, string _message) {
        if (_channel == listenChannel)
        {
            // Turn listen off. We turn it on again if we need to present
            // another menu
            llListenControl(listenHandle, FALSE);

            if ( _message == "Help" ) {
                if (llGetInventoryType(helpNotecard) == INVENTORY_NOTECARD)
                    llGiveInventory(Owner, helpNotecard);
                else
                    llOwnerSay("No help notecard found.");
            }
            else if ( _message == "Reset" ) {
                llMessageLinked(LINK_SET, 0, "ZHAO_RESET", NULL_KEY);
                llSleep(1.0);
                llResetScript();
            }
            else if ( _message == "Settings" ) {
                llMessageLinked(LINK_SET, 0, "ZHAO_SETTINGS", NULL_KEY);
            }
            else if ( _message == "Sit On/Off" ) {
                if (sitOverride == TRUE) {
                    llMessageLinked(LINK_SET, 0, "ZHAO_SITOFF", NULL_KEY);
                    sitOverride = FALSE;
                } else {
                        llMessageLinked(LINK_SET, 0, "ZHAO_SITON", NULL_KEY);
                    sitOverride = TRUE;
                }
            }
            else if ( _message == "SitAnyON" || _message == "SitAnyOFF" ) {
                //toggleSitAnywhere() by Marcus Gray
                ToggleSitAnywhere();
            }
            else if ( _message == "Rand/Seq" ) {
                if (randomStands == TRUE) {
                    llMessageLinked(LINK_SET, 0, "ZHAO_SEQUENTIALSTANDS", NULL_KEY);
                    randomStands = FALSE;
                } else {
                        llMessageLinked(LINK_SET, 0, "ZHAO_RANDOMSTANDS", NULL_KEY);
                    randomStands = TRUE;
                }
            }
            else if ( _message == "Next Stand" ) {
                llMessageLinked(LINK_SET, 0, "ZHAO_NEXTSTAND", NULL_KEY);
            }
            else if ( _message == "Load" ) {
                integer n = llGetInventoryNumber( INVENTORY_NOTECARD );
                // Can only have 12 buttons in a dialog box
                if ( n > 12 ) {
                    llOwnerSay( "You cannot have more than 12 animation notecards." );
                    return;
                }

                integer i;
                list animSets = [];

                // Build a list of notecard names and present them in a dialog box
                for ( i = 0; i < n; i++ ) {
                    string notecardName = llGetInventoryName( INVENTORY_NOTECARD, i );
                    if ( notecardName != helpNotecard )
                        animSets += [ notecardName ];
                }

                llListenControl(listenHandle, TRUE);
                llDialog( _id, "Select the notecard to load:", animSets, listenChannel );
                listenState = 1;
            }
            else if ( _message == "Stand Time" ) {
                // Pick stand times
                list standTimes = ["0", "5", "10", "15", "20", "30", "40", "60", "90", "120", "180", "240"];
                llListenControl(listenHandle, TRUE);
                llDialog( _id, "Select stand cycle time (in seconds). \n\nSelect '0' to turn off stand auto-cycling.",
                    standTimes, listenChannel);
                listenState = 2;
            }
            else if ( _message == "Sits" ) {
                llMessageLinked(LINK_SET, 0, "ZHAO_SITS", _id);
            }
            else if ( _message == "Walks" ) {
                llMessageLinked(LINK_SET, 0, "ZHAO_WALKS", _id);
            }
            else if ( _message == "Ground Sits" ) {
                llMessageLinked(LINK_SET, 0, "ZHAO_GROUNDSITS", _id);
            }
            /*
                //added for lock
                else if ( _message == LOCK || _message == UNLOCK)
                {
                    isLocked = !isLocked;
                    if(isLocked)
                    {
                        llOwnerSay("@detach=n");
                    }
                    else
                    {
                        llOwnerSay("@detach=y");
                    }
                }
            */
                else if ( listenState == 1 ) {
                    // Load notecard
                    llMessageLinked(LINK_SET, 0, "ZHAO_LOAD|" + _message, NULL_KEY);
                }
            else if ( listenState == 2 ) {
                // Stand time change
                llMessageLinked(LINK_SET, 0, "ZHAO_STANDTIME|" + _message, NULL_KEY);
            }

        }
        else if (_channel == collarchannel)
        {
            //only accept commands from owner's objects,
            //or from the object that disabled us
            //this is needed because the collar sends a ZHAO_STANDON message when it detaches
            //but because it's no longer rezzed, llgetownerkey doesn't work
            if (llGetOwnerKey(_id) == llGetOwner())
            {
                list params = llParseString2List(_message, ["|"], []);
                if (_message == "ZHAO_AOOFF")
                {
                    llMessageLinked(LINK_SET, 0, _message, NULL_KEY);
                }
                else if (_message == "ZHAO_AOON")
                {
                    llMessageLinked(LINK_SET, 0, _message, NULL_KEY);
                }
                //added for lock
                else if (_message == "ZHAO_LOCK" || _message == "ZHAO_UNLOCK")
                {
                    llMessageLinked(LINK_SET, 0, _message, NULL_KEY);
                }
                // Added for OCCuffs
                else if (_message == "ZHAO_PAUSE")
                {
                    llMessageLinked(LINK_SET, 0, _message, NULL_KEY);
                }
                else if (_message == "ZHAO_UNPAUSE")
                {
                    llMessageLinked(LINK_SET, 0, _message, NULL_KEY);
                }
                // End of change
                else if (_message == "ZHAO_STANDOFF")
                {
                    if (sitAnywhere) ToggleSitAnywhere(); // ShitAnyWhere is On, so disable it first
                    StandAO=FALSE; // and store that we are in off mode
                    llMessageLinked(LINK_SET, 0, _message, NULL_KEY);
                }
                else if (_message == "ZHAO_STANDON")
                {
                    StandAO=TRUE; // set state of Stand AO to TRUE
                    llMessageLinked(LINK_SET, 0, _message, NULL_KEY);
                }
                else if (llList2String(params, 0) == "ZHAO_MENU")
                {
                    llMessageLinked(LINK_SET, 0, "ZHAO_MENU", (key)llList2String(params, 1));
                }
                else if (_message == "ZHAO_AOSHOW")
                {
                    if(!isAttachedToHUD())
                    {
                        llSetLinkAlpha(LINK_SET, 1.0, ALL_SIDES);
                    }
                }
                else if (_message == "ZHAO_AOHIDE")
                {
                    if(!isAttachedToHUD())
                    {
                        llSetLinkAlpha(LINK_SET, 0.0, ALL_SIDES);
                    }
                    else
                    {
                        llOwnerSay("You can only hide the AO when it is not attached to the HUD.");
                    }
                }
            }
        }
    }
}

