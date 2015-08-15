
#if defined _sc_module_included
 #endinput
#endif
#define _sc_module_included

public SharedPlugin:__pl_sc_module =
{
    name = "sc_module",
    file = "sc_module.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

// Server Crontab global version
#define SCRONTAB_VERSION "1.0.1.3"

// Maximum size a cron job can be
#define MAX_JOB_LEN		255

// Wildcard "?" to skip checking the weekday/hour/minute
#define JOB_WILDCARD	0x3F

/*
 * Add a new cron job
 *
 * @param 	iWeekDayStart = The weekday the job starts (0-6)
 * @param 	iWeekDayEnd = The weekday the job ends (0-6) 
 * @param 	iHourStart = The hour the job starts (0-23)
 * @param 	iHourEnd = The hour the job ends (0-23) 
 * @param 	iMinuteStart = The minute the job starts (0-59)
 * @param 	iMinuteEnd = The minute the job ends (0-59) 
 * @param	szCronJob = The job to be run
 * @return	Cron job ID (Watch out because this can change over time. With adding & removing jobs)
 *
 */

native SC_AddCronJob (iWeekdayStart = -1, iWeekdayEnd = -1, iHourStart = -1, iHourEnd = -1, iMinuteStart = -1, iMinuteEnd = -1, const String:szCronJob[] = "");


/*
 * Find the index for a specific cron job
 *  
 * This is important when using arrays & removing jobs to grab the current index
 *
 * @param 	iWeekDayStart = The weekday the job starts (0-6)
 * @param 	iWeekDayEnd = The weekday the job ends (0-6) 
 * @param 	iHourStart = The hour the job starts (0-23)
 * @param 	iHourEnd = The hour the job ends (0-23) 
 * @param 	iMinuteStart = The minute the job starts (0-59)
 * @param 	iMinuteEnd = The minute the job ends (0-59) 
 * @param	szCronJob = The job to be run
 * @return	The cron job Id
 *
 */

native SC_SearchCronJobId (iWeekdayStart = -1, iWeekdayEnd = -1, iHourStart = -1, iHourEnd = -1, iMinuteStart = -1, iMinuteEnd = -1, const String:szCronJob[] = "");


/*
 * Remove a cron job
 *
 * @param 	iCronId = The cron job id to remove
 * @return	true if the job was removed sucessfully
 *
 */

native bool:SC_RemoveCronJob (iCronId = -1);


/*
 * Called just before the cron job is run
 * 
 * Allows a cron job to be skipped
 *  
 * @param   iCronId = The cron job ID 
 * @param	szCronJob = The job to be run
 * @return	Plugin_Handled to skip the cron job or Plugin_Continue to run it
 */

forward Action:SC_OnCronCall (iCronId, const String:szCronJob[]);


/*
 * Get the current number of cron jobs
 *
 * @return The number of current cron jobs
 *
 */

native SC_GetNumberOfCronJobs ();


/*
 * Get the cron job for the current id
 *
 * @param 	iCronId = The cron job id to retrieve
 * @param 	iWeekDayStart = The weekday the job starts (0-6)
 * @param 	iWeekDayEnd = The weekday the job ends (0-6) 
 * @param 	iHourStart = The hour the job starts (0-23)
 * @param 	iHourEnd = The hour the job ends (0-23) 
 * @param 	iMinuteStart = The minute the job starts (0-59)
 * @param 	iMinuteEnd = The minute the job ends (0-59) 
 * @param 	szCronJob = Place to store the cron job task
 * @return 	true if the job id was found or false if the job id is out of range
 *
 */

native bool:SC_GetCronJobFromId (iCronId = -1, &iWeekdayStart, &iWeekdayEnd, &iHourStart, &iHourEnd, &iMinuteStart, &iMinuteEnd, const String:szCronJob[]);


/*
 * Remove all the current cron jobs 
 */
native SC_RemoveAllCronJobs ();


/*
 * Check if a cron job you're about to add, already exists in the jobs array - saves duplicate jobs getting added
 *
 * @param 	iWeekDayStart = The weekday the job starts (0-6)
 * @param 	iWeekDayEnd = The weekday the job ends (0-6) 
 * @param 	iHourStart = The hour the job starts (0-23)
 * @param 	iHourEnd = The hour the job ends (0-23) 
 * @param 	iMinuteStart = The minute the job starts (0-59)
 * @param 	iMinuteEnd = The minute the job ends (0-59) 
 * @param	szCronJob = The job to be run
 * @return	Cron job ID (This will return -1 if no matching job was found, or the job ID if a duplicate was found)
 *
 */

native SC_DoesCronJobExist (iWeekdayStart = -1, iWeekdayEnd = -1, iHourStart = -1, iHourEnd = -1, iMinuteStart = -1, iMinuteEnd = -1, const String:szCronJob[] = "");

/*
 * Check the weekday is in range
 */  
stock bool:SC_IsWeekdayValid (iWeekday)
{
    if ((iWeekday > 6) && (iWeekday != JOB_WILDCARD))
        return false;
    return true;
}


/*
 * Check the hour is in range
 */
stock bool:SC_IsHourValid (iHour)
{
    if ((iHour > 23)  && (iHour != JOB_WILDCARD))
        return false;
    return true;
}


/*
 * Check the minute is in range
 */  
stock bool:SC_IsMinuteValid (iMinute)
{
    if ((iMinute > 59) && (iMinute != JOB_WILDCARD))
        return false;
    return true;
}

