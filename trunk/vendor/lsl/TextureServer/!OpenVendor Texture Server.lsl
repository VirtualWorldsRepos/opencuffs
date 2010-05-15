// OpenCollar NetVendor - 0.904
string groupid = "45d71cc1-17fc-8ee4-8799-7164ee264811";
integer frontface = 0;
integer topleft = 0;//lowest numbered item (by texture num) currently being displayed
key BLANK = "9b17c673-e805-ed71-4e98-7bdbcb841140";
integer pagesize = 8;
integer g_iNum_Textures;
key rcpt;
key g_kVendor_Httpid;
key g_kTexture_Httpid;
string objname;

integer g_iUpdateIntervall = 3600; // intervall the server contacvht the db for new textures, for testing we use 3600 secind (1 hour)
integer g_iRecheckIntervall = 60; // intervall to wait if texture update is in progress



list g_lTextureNameList;
list g_lTextureKeyList;

string g_sTextureVersion="0";
string g_sBaseURL  = "http://vendors.mycollar.org";
string g_sTextureURL;


string PrimName(integer link)
{
	return llList2String(llGetObjectDetails(llGetLinkKey(link), [OBJECT_NAME]), 0);
}

ShowTextures(integer start)
{
	//loop through all prims, displaying textures
	integer n;
	integer stop = llGetNumberOfPrims() + 1;
	for (n = 0; n < stop; n++)
	{
		string name = PrimName(n);
		if ((integer)name || name == "0")
		{
			if ( (start + (integer)name) >= llGetListLength(g_lTextureKeyList) )
			{//no texture for this prim, set to blank
				llSetLinkTexture(n, BLANK, frontface);
			}
			else
			{
				key tex = (key)llList2String(g_lTextureKeyList, start + (integer)name);
				llSetLinkTexture(n, tex, frontface);
			}
		}
	}
}
Debug(string sStr)
{
	llOwnerSay(sStr);
}

GenerateList()
{
	g_lTextureNameList = [];
	g_lTextureKeyList = [];
	integer i;
	for (i=0; i<llGetInventoryNumber(INVENTORY_TEXTURE); i++)
	{
		g_lTextureNameList += [llGetInventoryName(INVENTORY_TEXTURE, i)];
		g_lTextureKeyList += [llGetInventoryKey(llGetInventoryName(INVENTORY_TEXTURE, i))];
	}
	g_iNum_Textures = llGetInventoryNumber(INVENTORY_TEXTURE);
}


default
{
	on_rez(integer param)
	{
		llResetScript();
	}

	state_entry()
	{
		llOwnerSay("The vendor is inializing, please wait ...");
		llSetText("Initializing ...",<1,1,0>,1);
		list lParams = llParseString2List(llGetObjectDesc(), ["~"], []);
		string sDescURL = llList2String(lParams, 2);
		if (sDescURL == "")
		{
			llOwnerSay("You have changed my description. Using standard URL!");
		}
		else
		{
			g_sBaseURL = sDescURL;

		}
		llOwnerSay("Server adress used: " + g_sBaseURL);
		g_sTextureURL = g_sBaseURL + "/vendor/";
		ShowTextures(3000);//blank all panes until we know we're set to the right group
		if (llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0) != groupid)
		{
			llOwnerSay("Sorry, but group-only vendors must be set to the OpenCollar group.");
			llSetText("Wrong group set, vendor stopped!",<1,0,0>,1);
		}
		else
		{
			state init;
		}
	}
}


state init
{

	state_entry()
	{
		llOwnerSay("Contacting DB for texure pack update ...");
		llSetText("Contacting DB for texure pack update ...",<1,1,0>,1);
		g_kTexture_Httpid = llHTTPRequest(g_sTextureURL + "getalltextures?last_version=" + g_sTextureVersion, [HTTP_METHOD, "POST"], "");

	}

	on_rez(integer n)
	{
		llResetScript();
	}


	changed(integer c)
	{
		if (c & CHANGED_INVENTORY)
		{
			llResetScript();
		}
	}

	http_response(key id, integer status, list meta, string body)
	{
		if (id == g_kTexture_Httpid)
		{
			if (status == 200)
			{
				if (body == "CURRENT")
				{
					llOwnerSay("Textures are current, switching back to vendor mode!");
					state ready;
				}
				if (body == "Updating")
				{
					llOwnerSay("The texture server is just receiving new textures, update wil be restarted in 1 minute!");
					llSetTimerEvent(g_iRecheckIntervall);                }

				else
				{
					//llOwnerSay("Length:"+(string)llStringLength(body) +"\n"+ body);
					list lLines= llParseString2List(body,["\n"], []);
					string sGetNext = "";
					if ( (llList2String(lLines, 0) == "version") || (llList2String(lLines, 0) == "continue") )
					{
						if (llList2String(lLines, 0) == "version")
						{
							llOwnerSay("Textures need update to Texture pack version " + llList2String(lLines, 1));

							g_lTextureNameList = [];
							g_lTextureKeyList = [];
						}
						else
						{
							//llOwnerSay("Receiving next package from Texture pack version " + llList2String(lLines, 1));
						}
						integer i;
						for (i=2; i<llGetListLength(lLines); i += 2)
						{
							if (llList2String(lLines, i) == "end")
							{
								g_sTextureVersion = llList2String(lLines, 1);
							}
							else if (llList2String(lLines, i) == "startwith")
							{
								sGetNext = llList2String(lLines, i + 1);
							}
							else
							{
								g_lTextureNameList += [llList2String(lLines, i)];
								g_lTextureKeyList += [llList2String(lLines, i+1)];
							}
						}
						if (sGetNext != "")
						{
							//llOwnerSay("Getting next part of the texture pack");
							g_kTexture_Httpid = llHTTPRequest(g_sTextureURL + "getalltextures?last_version=" + g_sTextureVersion + "&start=" + sGetNext, [HTTP_METHOD, "POST"], "");
						}
						else
						{
							g_iNum_Textures = llGetListLength(g_lTextureNameList);
							llOwnerSay("Finished updating the texture pack, " + (string)g_iNum_Textures + " textures loaded. Switching back to vendor mode");
							ShowTextures(topleft);

							state ready;
						}

					}
					else
					{
						llOwnerSay("Unknown answer, status " + (string)status);
						llOwnerSay(body);
						llSetText("Error occured, vendor offline!",<1,0,0>,1);
					}
				}
			}
			else
			{
				llOwnerSay((string)status);
				llOwnerSay(body);
				llSetText("Error occured, vendor offline!",<1,0,0>,1);
			}
		}
	}

	timer()
	{
		llSetTimerEvent(0);
		llOwnerSay("Re-contacting DB for texure pack update ...");
		llSetText("DB busy, please wait a minute ...",<1,1,0>,1);

		g_kTexture_Httpid = llHTTPRequest(g_sTextureURL + "getalltextures?last_version=" + g_sTextureVersion, [HTTP_METHOD, "POST"], "");

	}
}

state ready
{
	state_entry()
	{
		llSetText("",<1,1,1>,1);

		llOwnerSay("System in vendor mode");
		//        GenerateList();
		//        g_iNum_Textures = llGetInventoryNumber(INVENTORY_TEXTURE);
		//        g_kTexture_Httpid = llHTTPRequest(g_sTextureURL + "versioncheck?tv=" + g_sTextureVersion, [HTTP_METHOD, "POST"], "");
		llSetTimerEvent(g_iUpdateIntervall);

	}

	touch_start(integer t)
	{
		if (llDetectedGroup(0))
		{
			integer link = llDetectedLinkNumber(0);
			if (link == 1)
			{//clicked root prim.  invite to group
				string url = "secondlife:///app/group/" + groupid + "/about";
				llInstantMessage(llDetectedKey(0), "To join the OpenCollar Group, please Click this link:\n" + url);
			}
			else
			{
				string name = PrimName(link);
				if (name == "Prev")
				{//show prev page
					topleft = topleft - pagesize;
					if (topleft < 0)
					{

						topleft = g_iNum_Textures - (g_iNum_Textures % pagesize);
					}
					ShowTextures(topleft);
				}
				else if (name == "Next")
				{//show next page
					topleft = topleft + pagesize;
					if (topleft > g_iNum_Textures - 1)
					{
						topleft = 0;
					}
					ShowTextures(topleft);
				}
				else if ((integer)name || name == "0")
				{//one of the numbered panes was clicked, deliver collar
					integer itemnum = (integer)name + topleft;
					if (itemnum < g_iNum_Textures)
					{
						rcpt = llDetectedKey(0);
						objname = llList2String(g_lTextureNameList, (integer)name + topleft);
						g_kVendor_Httpid = llHTTPRequest("http://collardata.appspot.com/dist/deliver", [HTTP_METHOD, "POST"], "objname=" + objname + "\nrcpt=" + (string)rcpt);
					}
				}
			}
		}
		else
		{
			llInstantMessage(llDetectedKey(0), "Sorry, but you must be an OpenCollar group member to use this vendor.  Admission is free.  You can find the group in search, or click here: secondlife:///app/group/" + (string)groupid + "/about");
		}
	}

	http_response(key id, integer status, list meta, string body)
	{
		if (id == g_kVendor_Httpid)
		{
			if (status == 200)
			{
				llInstantMessage(rcpt, objname + " should be delivered in the next 30 seconds.");
			}
			else
			{
				llSay(0, "There was a problem with your delivery. Please try again or contact the support from OpenCollar.");
				llOwnerSay((string)status);
				llOwnerSay(body);
			}
		}
	}

	on_rez(integer num)
	{
		llResetScript();
	}

	changed(integer c)
	{
		if (c & CHANGED_INVENTORY)
		{
			llResetScript();
		}
	}

	timer()
	{
		llOwnerSay("Checking for updated textures. (Current version "+ g_sTextureVersion +")");
		state init;
	}

}
