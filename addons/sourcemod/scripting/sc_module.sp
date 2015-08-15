/*
 * Server Crontab Main Module - www.sourcemod.net
 *
 * Plugin licensed under the GPLv3
 *
 * Coded by dubbeh - www.yegods.net
 *
 */


#include <sourcemod>
#include <scrontab>

#pragma semicolon 			1

#define JOB_WEEKDAY_START	0
#define JOB_WEEKDAY_END		1
#define JOB_HOUR_START		2
#define JOB_HOUR_END		3
#define JOB_MINUTE_START	4
#define JOB_MINUTE_END		5
#define JOB_TIME_SIZE		6


new Handle:g_cVarEnableLogging = INVALID_HANDLE;
new Handle:g_hJobsTimeArray = INVALID_HANDLE;
new Handle:g_hJobsTaskArray = INVALID_HANDLE;
new Handle:g_hJobsTimer = INVALID_HANDLE;
new Handle:g_hCronCallForward = INVALID_HANDLE;

static const String:g_szConfigFile[] = "sourcemod/sc_module.cfg";

public Plugin:ServerCrontabModule = 
{
	name = "Server Crontab Module", 
	author = "dubbeh", 
	description = "Run specific server jobs at certain times in SourceMod", 
	version = SCRONTAB_VERSION, 
	url = "http://www.yegods.net/"
};


public OnPluginStart()
{
	CreateConVar("sc_module_version", SCRONTAB_VERSION, "Server Crontab Module version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	g_cVarEnableLogging = CreateConVar("sc_module_jobslog", "1.0", "Enable the console output for ran jobs", 0, true, 0.0, true, 1.0);
	
	if (((g_hJobsTaskArray = CreateArray(MAX_JOB_LEN, 0)) != INVALID_HANDLE) && ((g_hJobsTimeArray = CreateArray(JOB_TIME_SIZE, 0)) != INVALID_HANDLE))
	{
		g_hCronCallForward = CreateGlobalForward("OnCronCall", ET_Event, Param_Cell, Param_String);
		g_hJobsTimer = CreateTimer(60.0, CrontabTimer, _, TIMER_REPEAT);
	}
	else
	{
		SetFailState("SC Module Error - Unable to create the arrays");
	}
	
	/* Create the delayed config execute timer */
	CreateTimer(10.0, OnPluginStart_Delayed);
}

public Action:OnPluginStart_Delayed(Handle:timer)
{
	/* Run delayed startup timer. Thanks to FlyingMongoose/sslice for the idea :) */
	/* We want to execute the jobs config file here */
	ServerCommand("exec %s", g_szConfigFile);
}

public OnPluginEnd()
{
	if (g_hJobsTimer != INVALID_HANDLE)
	{
		KillTimer(g_hJobsTimer);
		g_hJobsTimer = INVALID_HANDLE;
	}
	if (g_hJobsTimeArray != INVALID_HANDLE)
	{
		ClearArray(g_hJobsTimeArray);
		CloseHandle(g_hJobsTimeArray);
		g_hJobsTimeArray = INVALID_HANDLE;
	}
	if (g_hJobsTaskArray != INVALID_HANDLE)
	{
		ClearArray(g_hJobsTaskArray);
		CloseHandle(g_hJobsTaskArray);
		g_hJobsTaskArray = INVALID_HANDLE;
	}
	if (g_hCronCallForward != INVALID_HANDLE)
	{
		CloseHandle(g_hCronCallForward);
		g_hCronCallForward = INVALID_HANDLE;
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("SC_AddCronJob", Native_AddCronJob);
	CreateNative("SC_RemoveCronJob", Native_RemoveCronJob);
	CreateNative("SC_SearchCronJobId", Native_SearchCronJobId);
	CreateNative("SC_GetNumberOfCronJobs", Native_GetNumberOfCronJobs);
	CreateNative("SC_GetCronJobFromId", Native_GetCronJobFromId);
	CreateNative("SC_RemoveAllCronJobs", Native_RemoveAllCronJobs);
	CreateNative("SC_DoesCronJobExist", Native_DoesCronJobExist);
	return APLRes_Success;
}

public Native_AddCronJob(Handle:hPlugin, iNumParams)
{
	decl String:szJobTask[MAX_JOB_LEN] = "";
	static iLen = 0, iJobTime[JOB_TIME_SIZE];
	
	iJobTime[JOB_WEEKDAY_START] = GetNativeCell(1);
	iJobTime[JOB_WEEKDAY_END] = GetNativeCell(2);
	if (!SC_IsWeekdayValid(iJobTime[JOB_WEEKDAY_START]) || !SC_IsWeekdayValid(iJobTime[JOB_WEEKDAY_END]))
		return ThrowNativeError(SP_ERROR_NATIVE, "Weekday value is out of range - Maximum value is 6");
	
	iJobTime[JOB_HOUR_START] = GetNativeCell(3);
	iJobTime[JOB_HOUR_END] = GetNativeCell(4);
	if (!SC_IsHourValid(iJobTime[JOB_HOUR_START]) || !SC_IsHourValid(iJobTime[JOB_HOUR_END]))
		return ThrowNativeError(SP_ERROR_NATIVE, "Hour value is out of range - Maximum value is 23");
	
	iJobTime[JOB_MINUTE_START] = GetNativeCell(5);
	iJobTime[JOB_MINUTE_END] = GetNativeCell(6);
	if (!SC_IsMinuteValid(iJobTime[JOB_MINUTE_START]) || !SC_IsMinuteValid(iJobTime[JOB_MINUTE_END]))
		return ThrowNativeError(SP_ERROR_NATIVE, "Minute value is out of range - Maximum value is 59");
	
	GetNativeStringLength(7, iLen);
	GetNativeString(7, szJobTask, iLen + 1);
	if (szJobTask[0] == '\0')
		return ThrowNativeError(SP_ERROR_NATIVE, "No cron job specified");
	
	PushArrayArray(g_hJobsTimeArray, iJobTime);
	return PushArrayString(g_hJobsTaskArray, szJobTask);
}

public Native_SearchCronJobId(Handle:hPlugin, iNumParams)
{
	new iSearchJobTime[JOB_TIME_SIZE], iLen, iArraySize, iArrayIndex, iJobTime[JOB_TIME_SIZE];
	decl String:szSearchJob[MAX_JOB_LEN] = "", String:szCronJob[MAX_JOB_LEN] = "";
	
	iSearchJobTime[JOB_WEEKDAY_START] = GetNativeCell(1);
	iSearchJobTime[JOB_WEEKDAY_END] = GetNativeCell(2);
	if (!SC_IsWeekdayValid(iSearchJobTime[JOB_WEEKDAY_START]) || !SC_IsWeekdayValid(iSearchJobTime[JOB_WEEKDAY_END]))
		return -1;
	
	iSearchJobTime[JOB_HOUR_START] = GetNativeCell(3);
	iSearchJobTime[JOB_HOUR_END] = GetNativeCell(4);
	if (!SC_IsHourValid(iSearchJobTime[JOB_HOUR_START]) || !SC_IsHourValid(iSearchJobTime[JOB_HOUR_END]))
		return -1;
	
	iSearchJobTime[JOB_MINUTE_START] = GetNativeCell(5);
	iSearchJobTime[JOB_MINUTE_END] = GetNativeCell(6);
	if (!SC_IsMinuteValid(iSearchJobTime[JOB_MINUTE_START]) || !SC_IsMinuteValid(iSearchJobTime[JOB_MINUTE_END]))
		return -1;
	
	GetNativeStringLength(7, iLen);
	GetNativeString(7, szSearchJob, iLen + 1);
	
	iArraySize = GetArraySize(g_hJobsTimeArray);
	
	if (iArraySize > 0)
	{
		iArrayIndex = 0;
		while (iArrayIndex < iArraySize)
		{
			GetArrayArray(g_hJobsTimeArray, iArrayIndex, iJobTime);
			
			if ((iSearchJobTime[JOB_WEEKDAY_START] == iJobTime[JOB_WEEKDAY_START]) && 
				(iSearchJobTime[JOB_WEEKDAY_END] == iJobTime[JOB_WEEKDAY_END]))
			{
				if ((iSearchJobTime[JOB_HOUR_START] == iJobTime[JOB_HOUR_START]) && 
					(iSearchJobTime[JOB_HOUR_END] == iJobTime[JOB_HOUR_END]))
				{
					if ((iSearchJobTime[JOB_MINUTE_START] == iJobTime[JOB_MINUTE_START]) && 
						(iSearchJobTime[JOB_MINUTE_END] == iJobTime[JOB_MINUTE_END]))
					{
						GetArrayString(g_hJobsTaskArray, iArrayIndex, szCronJob, sizeof(szCronJob));
						if (!strcmp(szSearchJob, szCronJob, false))
							return iArrayIndex;
					}
				}
			}
			
			iArrayIndex++;
		}
	}
	
	return -1;
}

public Native_RemoveCronJob(Handle:hPlugin, iNumParams)
{
	static iJobIndex;
	
	iJobIndex = GetNativeCell(1);
	if (iJobIndex < GetArraySize(g_hJobsTimeArray))
	{
		RemoveFromArray(g_hJobsTimeArray, iJobIndex);
		RemoveFromArray(g_hJobsTaskArray, iJobIndex);
		return true;
	}
	
	return false;
}

public Native_GetNumberOfCronJobs(Handle:hPlugin, iNumParams)
{
	return GetArraySize(g_hJobsTimeArray) - 1;
}

public Native_GetCronJobFromId(Handle:hPlugin, iNumParams)
{
	static iCronJobId, iArraySize, iJobTime[JOB_TIME_SIZE];
	decl String:szCronJob[MAX_JOB_LEN] = "";
	
	iArraySize = GetArraySize(g_hJobsTimeArray);
	iCronJobId = GetNativeCell(1);
	
	if ((iArraySize == 0) || (iCronJobId > iArraySize))
		return false;
	
	GetArrayArray(g_hJobsTimeArray, iCronJobId, iJobTime);
	GetArrayString(g_hJobsTaskArray, iCronJobId, szCronJob, sizeof(szCronJob));
	SetNativeCellRef(2, iJobTime[JOB_WEEKDAY_START]);
	SetNativeCellRef(3, iJobTime[JOB_WEEKDAY_END]);
	SetNativeCellRef(4, iJobTime[JOB_HOUR_START]);
	SetNativeCellRef(5, iJobTime[JOB_HOUR_END]);
	SetNativeCellRef(6, iJobTime[JOB_MINUTE_START]);
	SetNativeCellRef(7, iJobTime[JOB_MINUTE_END]);
	SetNativeString(8, szCronJob, sizeof(szCronJob));
	return true;
}

public Native_RemoveAllCronJobs(Handle:hPlugin, iNumParams)
{
	if (g_hJobsTimeArray != INVALID_HANDLE)
	{
		ClearArray(g_hJobsTimeArray);
	}
	if (g_hJobsTaskArray != INVALID_HANDLE)
	{
		ClearArray(g_hJobsTaskArray);
	}
}

// This is basically the same as search cron job without the extra checks, so it's slightly faster
public Native_DoesCronJobExist(Handle:hPlugin, iNumParams)
{
	new iSearchJobTime[JOB_TIME_SIZE], iLen, iArraySize, iArrayIndex, iJobTime[JOB_TIME_SIZE];
	decl String:szSearchJob[MAX_JOB_LEN] = "", String:szCronJob[MAX_JOB_LEN] = "";
	
	iSearchJobTime[JOB_WEEKDAY_START] = GetNativeCell(1);
	iSearchJobTime[JOB_WEEKDAY_END] = GetNativeCell(2);
	iSearchJobTime[JOB_HOUR_START] = GetNativeCell(3);
	iSearchJobTime[JOB_HOUR_END] = GetNativeCell(4);
	iSearchJobTime[JOB_MINUTE_START] = GetNativeCell(5);
	iSearchJobTime[JOB_MINUTE_END] = GetNativeCell(6);
	
	GetNativeStringLength(7, iLen);
	GetNativeString(7, szSearchJob, iLen + 1);
	
	iArraySize = GetArraySize(g_hJobsTimeArray);
	
	if (iArraySize > 0)
	{
		iArrayIndex = 0;
		while (iArrayIndex < iArraySize)
		{
			GetArrayArray(g_hJobsTimeArray, iArrayIndex, iJobTime);
			
			if ((iSearchJobTime[JOB_WEEKDAY_START] == iJobTime[JOB_WEEKDAY_START]) && 
				(iSearchJobTime[JOB_WEEKDAY_END] == iJobTime[JOB_WEEKDAY_END]))
			{
				if ((iSearchJobTime[JOB_HOUR_START] == iJobTime[JOB_HOUR_START]) && 
					(iSearchJobTime[JOB_HOUR_END] == iJobTime[JOB_HOUR_END]))
				{
					if ((iSearchJobTime[JOB_MINUTE_START] == iJobTime[JOB_MINUTE_START]) && 
						(iSearchJobTime[JOB_MINUTE_END] == iJobTime[JOB_MINUTE_END]))
					{
						GetArrayString(g_hJobsTaskArray, iArrayIndex, szCronJob, sizeof(szCronJob));
						if (!strcmp(szSearchJob, szCronJob, false))
							return iArrayIndex;
					}
				}
			}
			
			iArrayIndex++;
		}
	}
	
	return -1;
}

public Action:CrontabTimer(Handle:timer)
{
	new iArrayIndex, iArraySize, iJobTime[JOB_TIME_SIZE], iWeekday, iHour, iMinute;
	new Action:aResult = Plugin_Continue;
	decl String:szCronJob[MAX_JOB_LEN] = "";
	
	iArraySize = GetArraySize(g_hJobsTimeArray);
	iWeekday = getWeekDay();
	iHour = getHour();
	iMinute = getMinute();
	
	if (iArraySize > 0)
	{
		iArrayIndex = 0;
		while (iArrayIndex < iArraySize)
		{
			GetArrayArray(g_hJobsTimeArray, iArrayIndex, iJobTime);
			
			if (((iJobTime[JOB_WEEKDAY_START] <= iWeekday) || (iJobTime[JOB_WEEKDAY_START] == JOB_WILDCARD)) && 
				((iJobTime[JOB_WEEKDAY_END] >= iWeekday) || (iJobTime[JOB_WEEKDAY_END] == JOB_WILDCARD)))
			{
				if (((iJobTime[JOB_HOUR_START] <= iHour) || (iJobTime[JOB_HOUR_START] == JOB_WILDCARD)) && 
					((iJobTime[JOB_HOUR_END] >= iHour) || (iJobTime[JOB_HOUR_END] == JOB_WILDCARD)))
				{
					if (((iJobTime[JOB_MINUTE_START] <= iMinute) || (iJobTime[JOB_MINUTE_START] == JOB_WILDCARD)) && 
						((iJobTime[JOB_MINUTE_START] >= iMinute) || (iJobTime[JOB_MINUTE_START] == JOB_WILDCARD)))
					{
						GetArrayString(g_hJobsTaskArray, iArrayIndex, szCronJob, sizeof(szCronJob));
						
						aResult = Plugin_Continue;
						Call_StartForward(g_hCronCallForward);
						Call_PushCell(iArrayIndex);
						Call_PushString(szCronJob);
						Call_Finish(aResult);
						
						if (aResult < Plugin_Handled)
						{
							if (GetConVarBool(g_cVarEnableLogging))
								LogMessage("Running cron job \"%s\"", szCronJob);
							ServerCommand(szCronJob);
						}
						else
						{
							if (GetConVarBool(g_cVarEnableLogging))
								LogMessage("Skipping cron job \"%s\"", szCronJob);
						}
					}
				}
			}
			
			iArrayIndex++;
		}
	}
	
	return Plugin_Continue;
}

stock getMinute()
{
	decl String:szMinute[3] = "";
	
	FormatTime(szMinute, sizeof(szMinute), "%M");
	return StringToInt(szMinute);
}

stock getHour()
{
	decl String:szHour[3] = "";
	
	FormatTime(szHour, sizeof(szHour), "%H");
	return StringToInt(szHour);
}

stock getWeekDay()
{
	decl String:szWeekday[3] = "";
	
	FormatTime(szWeekday, sizeof(szWeekday), "%w");
	return StringToInt(szWeekday);
}
