--1. What range of years for baseball games played does the provided database cover?
SELECT max(yearid), min(yearid)
FROM appearances;
--145 years (1871-2016)

SELECT max(finalgame), min(debut)
FROM people; 
--Precise dates: "1871-05-04", "2017-04-03"


--2. 
SELECT namelast, namefirst, height, appearances.g_all as games_played, appearances.teamid as team
FROM people
INNER JOIN appearances
ON people.playerid = appearances.playerid
WHERE height IS NOT null
ORDER BY height;

/*DON'T USE - TAKES 37 seconds to run 
SELECT DISTINCT teams.name, namelast, namefirst, height, appearances.g_all as games_played, appearances.yearid as year
FROM people
INNER JOIN appearances
ON people.playerid = appearances.playerid
INNER JOIN teams
ON appearances.teamid = teams.teamid
WHERE height IS NOT null
ORDER BY height, namelast;*/

WITH shortest_player AS (SELECT *
						FROM people
						ORDER BY height 
						LIMIT 1),
sp_total_games AS (SELECT *
				  FROM shortest_player 
				  LEFT JOIN appearances
				  USING(playerid))
SELECT DISTINCT(name), namelast, namefirst, height, g_all as games_played, sp_total_games.yearid
FROM sp_total_games
LEFT JOIN teams
USING(teamid);

/* 3. Find all players in the database who played at Vanderbilt University. 
Create a list showing each player’s first and last names as well as the total salary they earned 
in the major leagues. Sort this list in descending order by the total salary earned. 
Which Vanderbilt player earned the most money in the majors? */

WITH vandy AS (SELECT *
				FROM collegeplaying
				WHERE schoolid = 'vandy'), 
	vandy_names	AS (SELECT DISTINCT(playerid), namefirst, namelast
			   FROM vandy
			   LEFT JOIN people
			   USING(playerid))
SELECT DISTINCT(playerid), namefirst, namelast, (SUM(salary) OVER(PARTITION BY playerid))::numeric::money as total_salary
FROM vandy_names
LEFT JOIN salaries
USING(playerid)
WHERE salary IS NOT NULL
ORDER BY total_salary DESC;

--ALTERNATIVE APPROACH (KATIE DUNN)
SELECT distinct concat(p.namefirst, ' ', p.namelast) as name, sc.schoolname,
  sum(sa.salary)
  OVER (partition by concat(p.namefirst, ' ', p.namelast)) as total_salary
  FROM (people p JOIN collegeplaying cp ON p.playerid = cp.playerid)
  JOIN schools sc ON cp.schoolid = sc.schoolid
  JOIN salaries sa ON p.playerid = sa.playerid
  where cp.schoolid = 'vandy'
  group by name, schoolname, sa.salary, sa.yearid
  ORDER BY total_salary desc


/* 4. Using the fielding table, group players into three groups based on their position: 
label players with position OF as "Outfield", those with position "SS", "1B", "2B", 
and "3B" as "Infield", and those with position "P" or "C" as "Battery". 
Determine the number of putouts made by each of these three groups in 2016.*/


SELECT 
	CASE WHEN pos = 'OF' THEN 'Outfield'
		WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
		ELSE 'Battery' END as field_position, SUM(po) as total_putouts
FROM fielding
WHERE yearid = 2016
GROUP BY field_position;

--ALTERNATIVE APPROACH (CHRIS MULVEY)
SELECT
	CASE WHEN pos LIKE 'OF' THEN 'Outfield'
		WHEN pos LIKE 'C' THEN 'Battery'
		WHEN pos LIKE 'P' THEN 'Battery'
		ELSE 'Infield' END AS fielding_group,
	SUM(po) AS putouts
FROM fielding
WHERE yearid = 2016
GROUP BY fielding_group;


/* 5. Find the average number of strikeouts per game by decade since 1920. 
Round the numbers you report to 2 decimal places. Do the same for home runs per game. 
Do you see any trends?*/
SELECT yearid/10*10 as decade, ROUND(AVG(so::numeric/g::numeric), 2) as avg_so_per_game, ROUND(AVG(hr::numeric/g::numeric),2) as avg_h_per_game
FROM teams
WHERE yearid BETWEEN 1920 AND 2016
GROUP BY decade
ORDER BY decade;

--ALTERNATIVE APROACH (TANYA)
SELECT yearid/10 * 10 AS decade, 
	ROUND(((SUM(so)::float/SUM(g))::numeric), 2) AS avg_so_per_game,
	ROUND(((SUM(so)::float/SUM(ghome))::numeric), 2) AS avg_so_per_ghome
FROM teams
WHERE yearid >= 1920 
GROUP BY decade
ORDER BY decade

--GENERATE SERIES (MARY)
WITH decades as (	
	SELECT 	generate_series(1920,2010,10) as low_b,
			generate_series(1929,2019,10) as high_b)
			
SELECT 	low_b as decade,
		--SUM(so) as strikeouts,
		--SUM(g)/2 as games,  -- used last 2 lines to check that each step adds correctly
		ROUND(SUM(so::numeric)/(sum(g::numeric)/2),2) as SO_per_game,  -- note divide by 2, since games are played by 2 teams
		ROUND(SUM(hr::numeric)/(sum(g::numeric)/2),2) as hr_per_game
FROM decades LEFT JOIN teams
	ON yearid BETWEEN low_b AND high_b
GROUP BY decade
ORDER BY decade


/*Select avg(SO) as averageS_trikeouts ,decade||'-'||decade+9 as period
FROM (SELECT (CAST ((yearID/10) as int) *10) as decade
	  FROM PitchingPost
	  WHERE (CAST ((yearID/10) as int) *10) IS NOT NULL
	  GROUP BY decade
	  order by decade asc) as sub
     
SELECT *
FROM pitchingpost*/

/*6. Find the player who had the most success stealing bases in 2016, where success is measured as 
the percentage of stolen base attempts which are successful. (A stolen base attempt results either 
in a stolen base or being caught stealing.) Consider only players who attempted at least 20 
stolen bases.*/
SELECT playerid, namefirst, namelast, cs, sb, cs+sb as attempts, ROUND((sb::float/(cs::float+sb::float))::numeric, 2) as success
FROM batting
LEFT JOIN people
USING(playerid)
WHERE yearid = 2016
and SB >= 20
ORDER BY success DESC;

--ALTERNATIVE APPROACH (Cory)

SELECT Concat(namefirst,' ',namelast), batting.yearid, ROUND(MAX(sb::decimal/(cs::decimal+sb::decimal))*100,2) as sb_success_percentage
FROM batting
INNER JOIN people on batting.playerid = people.playerid
WHERE yearid = '2016'
AND (sb+cs) >= 20
GROUP BY namefirst, namelast, batting.yearid
ORDER BY sb_success_percentage DESC;

/*From 1970 – 2016, what is the largest number of wins for a team that did not win the world series? 
What is the smallest number of wins for a team that did win the world series? Doing this will 
probably result in an unusually small number of wins for a world series champion – determine why 
this is the case. Then redo your query, excluding the problem year. How often from 1970 – 2016 was 
it the case that a team with the most wins also won the world series? What percentage of the time?*/
--Carroll's
SELECT name as team_name, yearid as year, w as wins, wswin as world_series_win
FROM teams
WHERE wswin IS NOT null
AND yearid BETWEEN 1970 AND 2016
AND wswin = 'N'
ORDER BY wins DESC;

SELECT name as team_name, yearid as year, w as wins, wswin as world_series_win
FROM teams
WHERE wswin IS NOT null
AND yearid BETWEEN 1970 AND 2016
AND wswin = 'Y'
ORDER BY wins;

SELECT name as team_name, yearid as year, w as wins, wswin as world_series_win
FROM teams
WHERE wswin IS NOT null
AND yearid BETWEEN 1969 AND 2017
AND wswin = 'Y'
AND yearid <> 1981 --AND yearid NOT BETWEEN '1981' AND '1981'
ORDER BY wins;

--Mine
WITH games_wins AS (SELECT name as team_name, yearid as year, w as wins, wswin as world_series_win, 
			RANK() OVER (PARTITION BY yearid ORDER BY w DESC)
			FROM teams
			WHERE wswin IS NOT NULL
			AND yearid BETWEEN 1970 and 2016),
winners AS (SELECT *
		FROM games_wins
		WHERE rank = 1
		AND world_series_win = 'Y')
SELECT ROUND((COUNT(*)::numeric/(2016-1970)::numeric)*100, 2) as most_wins_won_percentage
FROM winners

--ALTERNATIVE APPROAH (CHRIS)
SELECT teamid,
	w,
	yearid
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
AND wswin = 'N'
GROUP BY teamid, yearid, w
ORDER BY w DESC
LIMIT 1;
10:39
SELECT yearid,
	MAX(w)
FROM teams
WHERE yearid BETWEEN 1970 and 2016
AND wswin = 'Y'
GROUP BY yearid
INTERSECT
SELECT yearid,
	MAX(w)
FROM teams
WHERE yearid BETWEEN 1970 and 2016
GROUP BY yearid
ORDER BY yearid;
10:41
WITH ws_winners AS (SELECT yearid,
						MAX(w)
					FROM teams
					WHERE yearid BETWEEN 1970 and 2016
					AND wswin = 'Y'
					GROUP BY yearid
					INTERSECT
					SELECT yearid,
						MAX(w)
					FROM teams
					WHERE yearid BETWEEN 1970 and 2016
					GROUP BY yearid
					ORDER BY yearid)
SELECT (COUNT(ws.yearid)/COUNT(t.yearid)::float)*100 AS percentage
FROM teams as t LEFT JOIN ws_winners AS ws ON t.yearid = ws.yearid
WHERE t.wswin IS NOT NULL
AND t.yearid BETWEEN 1970 AND 2016;


/* unneeded code...I think...  
AND world_series_win = 'Y'),
win_no AS (SELECT *
		  FROM games_wins
		  WHERE rank = 1
		  AND world_series_win = 'N')
SELECT win_yes/win_no
(COUNT(*
FROM win_no
most_game_wins AS (SELECT *
				FROM win_yes
				UNION ALL
				SELECT *
				FROM win_no)
SELECT *
FROM most_game_wins*/

/*8. Using the attendance figures from the homegames table, find the teams and parks which had the top 5 
average attendance per game in 2016 (where average attendance is defined as total attendance divided
by number of games). Only consider parks where there were at least 10 games played. 
Report the park name, team name, and average attendance. Repeat for the lowest 5 average attendance.*/
--Chira's code
WITH avg_atten as (select team, attendance/games as average
			   from homegames
			   where year = 2016)
select *
from homegames
left join avg_atten
using (team)
where year = 2016
and games > 10
order by average desc
limit 5
--Mine
WITH avg_attend as (SELECT team, park, ROUND(attendance::float/games::float) as avg_attendance
				 	 FROM homegames
				  	WHERE year = 2016
				  	AND games >= 10 )
SELECT team, teams.name, park_name, avg_attendance
FROM avg_attend
LEFT JOIN parks
USING(park)
LEFT JOIN teams
ON avg_attend.team = teams.teamid
WHERE teams.yearid = 2016
ORDER BY avg_attendance DESC
LIMIT 5;

--ALTERNATIVE APPROACH
SELECT DISTINCT p.park_name, h.team,
	(h.attendance/h.games) as avg_attendance, t.name		
FROM homegames as h JOIN parks as p ON h.park = p.park
LEFT JOIN teams as t on h.team = t.teamid AND t.yearid = h.year
WHERE year = 2016
AND games >= 10
ORDER BY avg_attendance DESC
LIMIT 5;

/* 9. Which managers have won the TSN Manager of the Year award in both the National League (NL) 
and the American League (AL)? Give their full name and the teams that they were managing when 
they won the award.*/

SELECT *
FROM awardsmanagers;

SELECT * 
FROM people;

SELECT *
FROM managers;


--Mahesh - HAVING DISTINCT(COUNT(lgid) = 2)

WITH TSN AS (SELECT *
			FROM awardsmanagers
			WHERE awardid LIKE 'TSN%'),
lg AS (SELECT playerid, lg1.yearid as NL_year, lg2.yearid as AL_year
		FROM TSN as lg1
		LEFT JOIN TSN as lg2
		USING (playerid)
		WHERE lg1.lgid = 'NL'
		AND lg2.lgid = 'AL'), 
award_recipients AS (SELECT playerid, NL_year as award_year
					FROM lg
					UNION ALL 
					SELECT DISTINCT(playerid), AL_year
					FROM lg 
					ORDER BY playerid),
testing AS (SELECT ar.playerid, namefirst, namelast, award_year, m.teamid
			FROM award_recipients as ar
			LEFT JOIN managers as m
			ON ar.playerid = m.playerid and ar.award_year = m.yearid
			LEFT JOIN people
			ON m.playerid = people.playerid)
SELECT namefirst, namelast, award_year, name
FROM testing
LEFT JOIN teams
ON testing.teamid = teams.teamid and testing.award_year = teams.yearid;

--ALTERNATIVE APPROACH (PAUL)
WITH manager_both AS (SELECT playerid, al.lgid AS al_lg, nl.lgid AS nl_lg,
					  al.yearid AS al_year, nl.yearid AS nl_year,
					  al.awardid AS al_award, nl.awardid AS nl_award
	FROM awardsmanagers AS al INNER JOIN awardsmanagers AS nl
	USING(playerid)
	WHERE al.awardid LIKE 'TSN%'
	AND nl.awardid LIKE 'TSN%'
	AND al.lgid LIKE 'AL'
	AND nl.lgid LIKE 'NL')
	
SELECT DISTINCT(people.playerid), namefirst, namelast, managers.teamid,
		managers.yearid AS year, managers.lgid
FROM manager_both AS mb LEFT JOIN people USING(playerid)
LEFT JOIN salaries USING(playerid)
LEFT JOIN managers USING(playerid)
WHERE managers.yearid = al_year OR managers.yearid = nl_year;

--ALTERNATIVE APPROACH
WITH mngr_list AS (SELECT playerid, awardid, COUNT(DISTINCT lgid) AS lg_count
				   FROM awardsmanagers
				   WHERE awardid = ‘TSN Manager of the Year’
				   		 AND lgid IN (‘NL’, ‘AL’)
				   GROUP BY playerid, awardid
				   HAVING COUNT(DISTINCT lgid) = 2),
	 mngr_full AS (SELECT playerid, awardid, lg_count, yearid, lgid
				   FROM mngr_list INNER JOIN awardsmanagers USING(playerid, awardid))
SELECT namegiven, namelast, name AS team_name
FROM mngr_full INNER JOIN people USING(playerid)
	 INNER JOIN managers USING(playerid, yearid, lgid)
	 INNER JOIN teams ON mngr_full.yearid = teams.yearid AND mngr_full.lgid = teams.lgid AND managers.teamid = teams.teamid
GROUP BY namegiven, namelast, name;

/* 10. Analyze all the colleges in the state of Tennessee. Which college has had the most success 
in the major leagues. Use whatever metric for success you like - number of players, number of games, 
salaries, world series wins, etc.*/

/*Not quite right in total_games columns, getting schools listed multiple times
WITH TN_schools AS (SELECT *
					FROM schools
					WHERE schoolstate = 'TN'),
TN_players AS (SELECT DISTINCT(playerid), schoolname
			  FROM TN_schools
			  LEFT JOIN collegeplaying
			  USING(schoolid)
			  WHERE playerid IS NOT NULL),
TN_prof AS (SELECT *
			FROM TN_players
			LEFT JOIN appearances
			USING(playerid)
			ORDER BY TN_players.playerid)
SELECT DISTINCT(schoolname), 
		SUM(g_all) OVER(PARTITION BY playerid) as total_games, 
		COUNT(playerid) OVER(PARTITION BY schoolname) as total_players
FROM TN_prof
ORDER BY total_games DESC;*/



WITH TN_players AS (SELECT playerid, schoolname
			  FROM schools
			  LEFT JOIN collegeplaying
			  USING(schoolid)
			  WHERE schoolstate = 'TN'
			   AND playerid IS NOT NULL)
SELECT schoolname, COUNT(DISTINCT(playerid)) as total_players, SUM(salary)::text::money as combined_salaries, SUM(salary)::text::money/COUNT(DISTINCT(playerid)) as money_per_player
FROM TN_players
INNER JOIN people
USING(playerid)
INNER JOIN salaries
USING(playerid)
GROUP BY schoolname
ORDER BY money_per_player DESC;

--Chira's code
with tn_players as (select schoolid, schoolstate, schoolname
				   from schools
				   where schoolstate= 'TN'),
college_pstate as (select distinct(playerid), schoolstate, schoolid
					   from collegeplaying
					   left join tn_players
					   using(schoolid)
					   where schoolstate = 'TN'
				   		and playerid is not null)
select distinct(schoolid),
sum(salary) over(partition by schoolid) as total_earned
from salaries
left join College_pstate
using(playerid)
where schoolid is not null
order by total_earned desc
--

/* 11. Is there any correlation between number of wins and team salary? 
Use data from 2000 and later to answer this question. As you do this analysis, 
keep in mind that salaries across the whole league tend to increase together, 
so you may want to look on a year-by-year basis.*/


WITH team_salaries_by_year AS (SELECT DISTINCT(teamid), yearid, (SUM(salary) OVER(PARTITION BY teamid, yearid)) as team_salary
								FROM salaries
								WHERE yearid >= 2000
								ORDER BY teamid, yearid),
game_wins AS (SELECT yearid, teamid, w
					FROM teams
					WHERE yearid >= 2000)
SELECT s.yearid, corr(team_salary, w) as sal_win_corr
FROM team_salaries_by_year as s
LEFT JOIN game_wins as w
ON s.teamid = w.teamid AND s.yearid = w.yearid 
GROUP BY s.yearid
ORDER BY yearid

/* 12.In this question, you will explore the connection between number of wins and attendance.
Does there appear to be any correlation between attendance at home games and number of wins?
Do teams that win the world series see a boost in attendance the following year? 
What about teams that made the playoffs? Making the playoffs means either being a division winner 
or a wild card winner.*/

SELECT corr(homegames.attendance, w) as corr_attend_w
FROM homegames
INNER JOIN teams
ON homegames.year = teams.yearid AND homegames.team = teams.teamid
WHERE homegames.attendance IS NOT NULL 

WITH wswin_teams AS (SELECT yearid, teamid, homegames.attendance
						FROM teams
						INNER JOIN homegames
						ON teams.yearid = homegames.year AND teams.teamid = homegames.team
						WHERE wswin = 'Y'),
ws_next_season AS (SELECT wt.yearid as wswin, year, team, h2.attendance
					FROM wswin_teams as wt
					INNER JOIN homegames as h2
					ON wt.yearid + 1 = h2.year AND wt.teamid = h2.team)
SELECT *
FROM wswin_teams
LEFT JOIN ws_next_season
ON wswin_teams.yearid = ws_next_season.wswin
WHERE ws_next_season.attendance > wswin_teams.attendance
AND wswin_teams.attendance <> 0




/* 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often,
that they are more effective. Investigate this claim and present evidence to either support or 
dispute this claim. First, determine just how rare left-handed pitchers are compared with 
right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? 
Are they more likely to make it into the hall of fame?*/

SELECT COUNT(CASE WHEN throws = 'R' THEN 'right' END) as throws_right, 
				COUNT(CASE WHEN throws = 'L' THEN 'left' END) as throws_left, 
				ROUND((COUNT(CASE WHEN throws = 'L' THEN 'left' END)::numeric/COUNT(*))*100,2) as percent_left
FROM people;

SELECT COUNT(CASE WHEN throws = 'R' THEN 'right' END) as throws_right, 
				COUNT(CASE WHEN throws = 'L' THEN 'left' END) as throws_left, 
				ROUND((COUNT(CASE WHEN throws = 'L' THEN 'left' END)::numeric/COUNT(*))*100,2) as percent_left
FROM people
INNER JOIN awardsplayers
USING(playerid)
WHERE awardid = 'Cy Young Award';

SELECT DISTINCT(people.playerid), --namelast, namefirst, throws as throwing_hand, pitching.w as wins, pitching.l as losses,
	COUNT(CASE WHEN throws = 'R' THEN 'right handed' END) as throws_right,
	COUNT(CASE WHEN throws = 'L' THEN 'left handed' END) as throws_left
FROM people
INNER JOIN pitching
ON people.playerid = pitching.playerid
WHERE throws IS NOT null
GROUP BY people.playerid
--ORDER BY w DESC
LIMIT 10;
		

SELECT
	COUNT(CASE WHEN throws = 'R' THEN 'right handed' END) as throws_right,
	COUNT(CASE WHEN throws = 'L' THEN 'left handed' END) as throws_left
FROM people
WHERE throws IS NOT null

SELECT *
FROM people





--MAHESH OPEN ENDED ANSWERS
-- Open-ended questions
​
-- Analyze all the colleges in the state of Tennessee.
-- Which college has had the most success in the major leagues.
-- Use whatever metric for success you like - number of players, number of games, salaries, world series wins, etc.
​
WITH tn_schools AS (SELECT schoolname, schoolid
					FROM schools
					WHERE schoolstate = 'TN'
					GROUP BY schoolname, schoolid)
SELECT schoolname, COUNT(DISTINCT playerid) AS player_count, SUM(salary)::text::money AS total_salary, (SUM(salary)/COUNT(DISTINCT playerid))::text::money AS money_per_player
FROM tn_schools INNER JOIN collegeplaying USING(schoolid)
	 INNER JOIN people USING(playerid)
	 INNER JOIN salaries USING(playerid)
GROUP BY schoolname
ORDER BY money_per_player DESC;


SELECT *
FROM teams
WHERE teamid = 'ANA'
AND yearid = '2000'
-- Is there any correlation between number of wins and team salary?
-- Use data from 2000 and later to answer this question.
-- As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.
​
WITH team_year_sal_w AS (SELECT teamid, yearid, SUM(salary) AS total_team_sal, AVG(w)::integer AS w
						 FROM salaries INNER JOIN teams USING(yearid, teamid)
						 WHERE yearid >= 2000
						 GROUP BY yearid, teamid)
SELECT yearid, CORR(total_team_sal, w) AS sal_win_corr
FROM team_year_sal_w
GROUP BY yearid
ORDER BY yearid;
​
​
-- In this question, you will explore the connection between number of wins and attendance.
-- Does there appear to be any correlation between attendance at home games and number of wins?
-- Do teams that win the world series see a boost in attendance the following year?
-- What about teams that made the playoffs?
-- Making the playoffs means either being a division winner or a wild card winner.
​
SELECT CORR(homegames.attendance, w) AS corr_attend_w --COUNT(DISTINCT playerid)
FROM teams INNER JOIN homegames ON teamid = team AND yearid = year
WHERE homegames.attendance IS NOT NULL
​
SELECT AVG(hg_2.attendance - hg_1.attendance) AS avg_attend_inc, stddev_pop(hg_2.attendance - hg_1.attendance) AS stdev_attend_inc 
--DISTINCT name, yearid, hg_1.attendance, hg_2.year, hg_2.attendance, hg_2.attendance - hg_1.attendance AS attend_inc
FROM teams INNER JOIN homegames AS hg_1 ON teams.yearid = hg_1.year AND teams.teamid = hg_1.team
	 INNER JOIN homegames AS hg_2 ON teams.yearid + 1 = hg_2.year AND teams.teamid = hg_2.team
WHERE wswin = 'Y'
	  AND hg_1.attendance > 0
	  AND hg_2.attendance > 0;
​
SELECT AVG(hg_2.attendance - hg_1.attendance) AS avg_attend_inc, stddev_pop(hg_2.attendance - hg_1.attendance) AS stdev_attend_inc
--DISTINCT name, yearid, hg_1.attendance, hg_2.year, hg_2.attendance, hg_2.attendance - hg_1.attendance AS attend_inc
FROM teams INNER JOIN homegames AS hg_1 ON teams.yearid = hg_1.year AND teams.teamid = hg_1.team
	 INNER JOIN homegames AS hg_2 ON teams.yearid + 1 = hg_2.year AND teams.teamid = hg_2.team
WHERE (divwin = 'Y' OR wcwin = 'Y')
	  AND hg_1.attendance > 0
	  AND hg_2.attendance > 0;
​
​
​
-- It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective.
-- Investigate this claim and present evidence to either support or dispute this claim.
-- First, determine just how rare left-handed pitchers are compared with right-handed pitchers.
-- Are left-handed pitchers more likely to win the Cy Young Award?
-- Are they more likely to make it into the hall of fame?
​
SELECT *
FROM halloffame
​
WITH pitchers AS (SELECT *
				  FROM people INNER JOIN pitching USING(playerid)
				 	   INNER JOIN awardsplayers USING(playerid)
				 	   INNER JOIN halloffame USING(playerid))
SELECT (SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE throws = 'L')/COUNT(DISTINCT playerid)::float AS pct_left_pitch,
	   (SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE awardid = 'Cy Young Award')/COUNT(DISTINCT playerid)::float AS pct_cy_young,
	   ((SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE awardid = 'Cy Young Award')/COUNT(DISTINCT playerid)::float) * ((SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE throws = 'L')/COUNT(DISTINCT playerid)::float) AS calc_pct_left_cy_young,
	   (SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE awardid = 'Cy Young Award' AND throws = 'L')/COUNT(DISTINCT playerid)::float AS actual_pct_left_cy_young,
	   (SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE inducted = 'Y')/COUNT(DISTINCT playerid)::float AS pct_hof,
	   ((SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE inducted = 'Y')/COUNT(DISTINCT playerid)::float) * ((SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE throws = 'L')/COUNT(DISTINCT playerid)::float) AS calc_pct_left_hof,
	   (SELECT COUNT(DISTINCT playerid)::float FROM pitchers WHERE inducted = 'Y' AND throws = 'L')/COUNT(DISTINCT playerid)::float AS actual_pct_left_hof
FROM pitchers;
