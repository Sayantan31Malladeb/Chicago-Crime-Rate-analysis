USE CHICAGO;
select * from chicago_crimes_2021;

--  CREATE TEMPORARY TABLE --

DROP TABLE IF EXISTS chicago_crimes;
CREATE TABLE chicago_crimes AS (
    SELECT
        DATE_FORMAT(STR_TO_DATE(C.crime_date, '%m/%d/%Y %H:%i'), '%Y-%m-%d %H:%i:%s') AS crime_date,
        TIME(STR_TO_DATE(C.crime_date, '%m/%d/%Y %H:%i')) AS time_reported,
        C.crime_type,
        C.crime_description,
        C.crime_location,
        C.city_block,
        D.name,
        D.population,
        D.area_sq_mi,
        D.density,
        C.arrest, 
        C.domestic,
        T.temp_high, 
        T.temp_low, 
        T.precipitation,
        C.latitude,
        C.longitude
    FROM chicago_crimes_2021 AS C
    JOIN chicago_areas AS D
    ON C.community_id = D.community_area_id
    JOIN chicago_temps_2021 AS T
    ON DATE_FORMAT(STR_TO_DATE(T.date, '%m/%d/%Y'), '%Y-%m-%d') = DATE_FORMAT(STR_TO_DATE(C.crime_date, '%m/%d/%Y %H:%i'), '%Y-%m-%d')
);


SELECT * FROM chicago_crimes ;
SELECT * FROM chicago_crimes LIMIT 10;

-- TOTAL CRIMES COMMITTED --

SELECT count(city_block) AS "Total crimes reported"
FROM chicago_crimes;

-- TOP 10 TYPE OF CRIME --

SELECT DISTINCT crime_type AS top_10_crime_types, COUNT(*) AS total_frequency 
FROM chicago_crimes
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;


-- MOST CONSECUTIVE DAYS WITH HOMICIDE CRIME --

SELECT
  MAX(consecutive_days) AS most_consecutive_days,
  CONCAT(DATE_FORMAT(MAX(c_date) - INTERVAL (MAX(consecutive_days) -1) DAY, '%Y-%m-%d'), ' to ', DATE_FORMAT(MAX(c_date), '%Y-%m-%d')) AS time_frame
FROM (
  SELECT
    c_date,
    @consecutive_days := IF(DATEDIFF(c_date, @prev_date) = 1, @consecutive_days + 1, 1) AS consecutive_days,
    @prev_date := c_date AS prev_date
  FROM (
    SELECT DISTINCT DATE(crime_date) AS c_date
    FROM chicago_crimes
    WHERE crime_type = 'homicide'
    ORDER BY DATE(crime_date)
  ) AS get_all_dates,
  (SELECT @consecutive_days := 1, @prev_date := NULL) AS vars
) AS grouped_data
WHERE consecutive_days > 40;


-- TOP 10 COMMUNITIES  AND BOTTOM 10 OF REPORTED CRIMES --
WITH community_summary AS (
    SELECT 
        name,
        population,
        density,
        COUNT(*) AS reported_crimes,
        ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS top_10_rank,
        ROW_NUMBER() OVER (ORDER BY COUNT(*) ASC) AS bottom_10_rank
    FROM chicago_crimes
    GROUP BY name, population, density
)
SELECT
    top_10.name AS top_10_DANGEROUS_communities,
    top_10.population AS top_10_DANGEROUS_population,
    top_10.density AS top_10_DANGEROUS_density,
    top_10.reported_crimes AS top_10_DANGEROUS_reported_crimes,
    bottom_10.name AS top_10_SAFEST_communities,
    bottom_10.population AS top_10_SAFEST_population,
    bottom_10.density AS top_10_SAFEST_density,
    bottom_10.reported_crimes AS top_10_SAFEST_reported_crimes
FROM community_summary top_10
JOIN community_summary bottom_10 ON top_10.top_10_rank = bottom_10.bottom_10_rank
WHERE top_10.top_10_rank <= 10;

 -- CRIMES BY CITY STREET ADDRESS --
 
 SELECT city_block AS street_name, count(*) AS number_of_crimes FROM chicago_crimes
GROUP BY 1 
ORDER BY count(*) DESC
LIMIT 10;


 -- Top 15 crimes--

select DISTINCT crime_type, COUNT(*) from chicago_crimes
GROUP BY 1 ORDER BY 2 DESC
LIMIT 15;






 -- TOP 10 STREET BY ASSAULTS -- 
SELECT
    street_name,
    number_of_assaults
FROM
    (SELECT
        CITY_BLOCK AS street_name,
        COUNT(*) AS number_of_assaults,
        ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS `rank`
    FROM
        chicago_crimes
    WHERE
        crime_type = 'assault'
    GROUP BY
        street_name
    ) AS tmp
WHERE
    `rank` <= 10;

 -- CRIME TYPE BY TIME RANGE --
 
SELECT
    crime_type,
    SUM(CASE
        WHEN TIME(CRIME_DATE) >= '00:00:00' AND TIME(CRIME_DATE) <= '05:59:59' THEN 1
        ELSE 0
    END) AS crimes_00_to_05,
    SUM(CASE
        WHEN TIME(CRIME_DATE) >= '06:00:00' AND TIME(CRIME_DATE) <= '11:59:59' THEN 1
        ELSE 0
    END) AS crimes_06_to_11,
    SUM(CASE
        WHEN TIME(CRIME_DATE) >= '12:00:00' AND TIME(CRIME_DATE) <= '17:59:59' THEN 1
        ELSE 0
    END) AS crimes_12_to_17,
    SUM(CASE
        WHEN TIME(CRIME_DATE) >= '18:00:00' AND TIME(CRIME_DATE) <= '23:59:59' THEN 1
        ELSE 0
    END) AS crimes_18_to_23
FROM
    chicago_crimes
GROUP BY
    1;

-- CRIMES BY POPULATION RANGE --

SELECT
    CONCAT(FLOOR(population / 10000) * 10000 + 1, '-', FLOOR(population / 10000) * 10000 + 10000) AS population_range,
    COUNT(*) AS crime_count
FROM
    chicago_crimes
GROUP BY
    1
ORDER BY
    2 desc;

-- CRIME LOCATION COUNT BY WEATHER --
SELECT
    crime_location,
    COUNT(*) AS crime_location_count,
    SUM(CASE WHEN crime_date BETWEEN '2021-04-15' AND '2021-10-15' THEN 1 ELSE 0 END) AS mild_weather,
    SUM(CASE WHEN crime_date < '2021-04-15' OR crime_date > '2021-10-15' THEN 1 ELSE 0 END) AS cold_weather
FROM
    chicago_crimes
WHERE
     crime_location IS NOT NULL
GROUP BY
    1
ORDER BY
    2 DESC
LIMIT 10;

-- DOMESTIC VIOLENCE VS NON-DOMESTIC VIOLENCE --

SELECT
    100 - (SUM(CASE WHEN domestic = 'TRUE' THEN 1 ELSE 0 END) * 100 / COUNT(*)) AS non_domestic_violence,
    (SUM(CASE WHEN domestic = 'TRUE' THEN 1 ELSE 0 END) * 100 / COUNT(*)) AS domestic_violence
FROM
    chicago_crimes;


-- CRIME COUNT CHANGES BY MONTH --
WITH monthly_crime_counts AS (
    SELECT
        DATE_FORMAT(crime_date, '%M') AS Month,
        COUNT(*) AS number_of_crimes
    FROM 
        chicago_crimes
    GROUP BY 
        DATE_FORMAT(crime_date, '%M')
),
previous_month_counts AS (
    SELECT
        Month,
        number_of_crimes,
        LAG(number_of_crimes) OVER (ORDER BY FIELD(Month,
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        )) AS previous_month_crimes
    FROM
        monthly_crime_counts
)
SELECT
    Month,
    number_of_crimes,
    ROUND(100 * (number_of_crimes - previous_month_crimes) / previous_month_crimes, 2) AS month_to_month_changes_in_crime
FROM
    previous_month_counts
ORDER BY
    FIELD(Month,
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    );

    
  -- CRIMES BY WEEKDAY --
  
SELECT DATE_FORMAT(CRIME_DATE, '%W') AS day_of_week, COUNT(*) AS n_crimes FROM chicago_crimes
GROUP BY 1
ORDER BY 2 DESC;

 -- What are the top 10 most reported crime, how many arrests were made and the percentage of arrests made? --
 WITH crime_summary AS (
    SELECT
        crime_type,
        COUNT(*) AS total_crimes,
        SUM(arrest = 'true') AS arrest_count
    FROM chicago_crimes
    GROUP BY crime_type
    ORDER BY total_crimes DESC
    LIMIT 10
)
SELECT
    crime_type AS least_reported_crimes,
    total_crimes AS crime_count,
    arrest_count,
    ROUND(100 * (arrest_count / total_crimes), 2) AS arrest_percentage
FROM crime_summary;

 -- ARRESTED PERCENTAGE --
SELECT
    100 - (SUM(CASE WHEN Arrest = 'TRUE'  THEN 1 ELSE 0 END) * 100 / COUNT(*)) AS not_arrested,
    (SUM(CASE WHEN Arrest = 'TRUE' THEN 1 ELSE 0 END) * 100 / COUNT(*)) AS arrested
FROM
    chicago_crimes;
