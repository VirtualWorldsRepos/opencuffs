// OpenCollar MultiVendor Net - 0.901
//on start, read desc for item name

//on touch, do http request to enqueue delivery

string url = "http://collardata.appspot.com/dist/deliver";
string g_SObjName = "OpenCollar";
string g_SObjTextureKey = "963c17e9-43ec-3e22-91e7-9b74baae3702";



key rcpt;
key groupid = "45d71cc1-17fc-8ee4-8799-7164ee264811";
integer current;

string next = "Next";
string prev = "Prev";
integer frontface = 1;

integer g_iNum_Textures;//total textures


key g_kVendor_Httpid;
key g_kTexture_Httpid;

integer g_iUpdateIntervall = 3600; // intervall the server contacvht the db for new textures, for testing we use 3600 secind (1 hour)
integer g_iRecheckIntervall = 60; // intervall to wait if texture update is in progress



list g_lTextureNameList;
list g_lTextureKeyList;

string g_sTextureVersion="0";
string g_sBaseURL  = "http://vendors.mycollar.org";
string g_sTextureURL;




string PrimName(integer linknum)
{
	return llList2String(llGetObjectDetails(llGetLinkKey(linknum), [OBJECT_NAME]), 0);
}

ShowTexture(){
	integer next1;
	integer prev1;
	integer next2;
	integer prev2;
	integer next3;
	integer prev3;
	integer i;
	llSetTexture(g_SObjTextureKey, frontface); // 1
	if (g_iNum_Textures>1){
		next1 = current+1;
		if (next1 == g_iNum_Textures) next1 = 0;
		llSetTexture(llList2Key(g_lTextureKeyList, next1),0);
		prev1 = current-1;
		if (prev1 < 0) prev1 = g_iNum_Textures-1;
		llSetTexture(llList2Key(g_lTextureKeyList, prev1),2);
	}
	if (g_iNum_Textures>2){
		next2 = next1+1;
		if (next2 == g_iNum_Textures) next2 = 0;
		llSetTexture(llList2Key(g_lTextureKeyList, next2),4);
		prev2 = prev1-1;
		if (prev2 < 0) prev2 = g_iNum_Textures-1;
		llSetTexture(llList2Key(g_lTextureKeyList, prev2),5);
	}
	if (g_iNum_Textures>5){
		for(i = 1; i < 5; i++){
			next3 = next2 + i;
			if(next3 >= g_iNum_Textures) next3 = i-1;
			llMessageLinked(2, 0, "", llList2Key(g_lTextureKeyList,next3));
			prev3 = prev2 - i;
			if(prev3 < 0) prev3 = g_iNum_Textures-i;
			llMessageLinked(3, 0, "", llList2Key(g_lTextureKeyList,prev3));
		}
	}
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
		//        ShowTextures(3000);//blank all panes until we know we're set to the right group
		if (llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0) != (string)groupid)
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
							llSetTexture(g_SObjTextureKey, frontface);
							//ShowTextures(topleft);

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

	touch_start(integer total_number)
	{
		string primname = PrimName(llDetectedLinkNumber(0));
		if (primname == next)
		{
			current++;
			if (current >= g_iNum_Textures)
			{
				current = 0;
			}
			g_SObjName = llList2Key(g_lTextureNameList, current);
			g_SObjTextureKey = llList2Key(g_lTextureKeyList, current);

			ShowTexture();
		}
		else if (primname == prev)
		{
			current--;
			if (current < 0)
			{
				current = g_iNum_Textures - 1;
			}
			g_SObjName = llList2Key(g_lTextureNameList, current);
			g_SObjTextureKey = llList2Key(g_lTextureKeyList, current);
			ShowTexture();
		}
		else
		{
			rcpt = llDetectedKey(0);
			if (llDetectedGroup(0))
			{
				g_kVendor_Httpid = llHTTPRequest(url, [HTTP_METHOD, "POST"], "objname=" + g_SObjName + "\nrcpt=" + (string)rcpt);
			}
			else
			{
				llInstantMessage(rcpt, "Sorry, but this item is only for OpenCollar group members.  Admission is free.  You can find the group in search, or click here: secondlife:///app/group/" + (string)groupid + "/about");
			}
		}
	}

	http_response(key id, integer status, list meta, string body)
	{
		if (id == g_kVendor_Httpid)
		{
			if (status == 200)
			{
				llInstantMessage(rcpt, g_SObjName + " should be delivered in the next 30 seconds.");
			}
			else
			{
				llSay(0, "There was a problem with your delivery. Please try again or contact the support from OpenCollar.");
				llOwnerSay((string)status);
				llOwnerSay(body);
			}
		}
	}

	on_rez(integer param)
	{
		llResetScript();
	}

	changed(integer change){
		if (change & CHANGED_INVENTORY) llResetScript();
	}

	timer()
	{
		llOwnerSay("Checking for updated textures. (Current version "+ g_sTextureVersion +")");
		state init;
	}


}