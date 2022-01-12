------- From [covid-deaths] & [covid-vaccines], updating 'population' values of 0 to NULL instead
UPDATE PortfolioProject.dbo.[covid-deaths]
SET population = NULL
WHERE population = 0
UPDATE PortfolioProject.dbo.[covid-vaccines]
SET population = NULL
WHERE population = 0
------- From [covid-deaths], updating 'total_deaths', 'total_cases', 'new_cases' & 'new_deaths' values of 0 to NULL instead
UPDATE PortfolioProject.dbo.[covid-deaths]
SET total_deaths = NULL
WHERE total_deaths = 0
UPDATE PortfolioProject.dbo.[covid-deaths]
SET total_cases = NULL
WHERE total_cases = 0
UPDATE PortfolioProject.dbo.[covid-deaths]
SET new_cases = NULL
WHERE new_cases = 0
UPDATE PortfolioProject.dbo.[covid-deaths]
SET new_deaths = NULL
WHERE new_deaths = 0
------- From [covid-vaccines], updating 'new_vaccinations' values of 0 to NULL instead
UPDATE PortfolioProject.dbo.[covid-vaccines]
SET new_vaccinations = NULL
WHERE new_vaccinations = 0
------- Updating 'continent' blank values to NULL instead
UPDATE PortfolioProject.dbo.[covid-deaths]
SET continent = NULL
WHERE continent = ' '
------- Updating table to set 'total_deaths' values to float
ALTER TABLE PortfolioProject.dbo.[covid-deaths]
ALTER COLUMN total_deaths float



--- Top Countries in terms of Deaths and Cases (Regions and Continents excluded)
--Filtering out Regions/Continents with DATALENGTH

SELECT 
	location, 
	MAX(total_deaths) AS 'current death count', 
	MAX(total_cases) AS 'current case count'
FROM PortfolioProject.dbo.[covid-deaths]
WHERE DATALENGTH(iso_code) = 3
GROUP BY location
ORDER BY MAX(total_deaths) DESC



--- Looking at Total Deaths vs Total Cases per Countries, through Time
-- Calculating the average Fatality Rate of COVID (chances of dying after contracting it)

SELECT 
	location,
	date,
	total_cases,
	total_deaths,
	(total_deaths/total_cases)*100 AS death_percentage
FROM PortfolioProject.dbo.[covid-deaths]
WHERE DATALENGTH(iso_code) = 3
GROUP BY location, date, total_deaths, total_cases
ORDER BY location



--- Looking at Total Cases vs Population
--- Calculating what percentage of the population has had COVID at any given time

SELECT 
	location,
	date,
	population,
	total_cases,
	(cast(total_cases as float)/population)*100 as percent_infected
FROM PortfolioProject.dbo.[covid-deaths]
WHERE location = 'Canada'



--- Looking at Countries with Highest Infection Rate compared to Population
--- Only looking at Countries with a Population over 1,000,000
-- Casting total_cases as float to avoid calculation errors

SELECT 
	location,
	population,
	MAX(total_cases) as highest_infection_count,
	MAX((cast(total_cases as float)/population))*100 as cases_per_pop
FROM PortfolioProject.dbo.[covid-deaths]
WHERE DATALENGTH(iso_code) = 3
	AND  population > 1000000
GROUP BY location, population
ORDER BY cases_per_pop DESC



--- Showing Countries with Highest Death Count (per Population)
-- With the blank 'continent' values updated to NULLs, "continent IS NOT NULL"
-- can now also be used to filter out Regions/Continents

SELECT 
	location,
	MAX(total_deaths) as total_death_count
FROM PortfolioProject.dbo.[covid-deaths]
--WHERE DATALENGTH(iso_code) = 3
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_death_count DESC



--- Same thing but for Continents
-- Showing Countries with Highest Death Count (per Population)

SELECT 
	continent,
	MAX(total_deaths) as total_death_count
FROM PortfolioProject.dbo.[covid-deaths]
--WHERE DATALENGTH(iso_code) = 3
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY total_death_count DESC



--- Global Numbers
-- Casting new_deaths as float to avoid calculation errors

SELECT 
	SUM(new_cases) AS total_cases,
	SUM(new_deaths) AS total_deaths,
	SUM(cast(new_deaths as float))/SUM(new_cases)*100 AS death_percentage
FROM PortfolioProject.dbo.[covid-deaths]
WHERE continent IS NOT NULL



--- Looking at Total Population vs New Vaccinations

SELECT 
	d.continent,
	d.location,
	d.date,
	d.population,
	v.new_vaccinations,
	SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS total_vaccination_count
	--(total_vaccination_count/d.population)*100 AS doses_per_pop
FROM PortfolioProject.dbo.[covid-deaths] d
JOIN PortfolioProject.dbo.[covid-vaccines] v
	ON d.location = v.location
	AND d.date = v.date
WHERE d.continent IS NOT NULL
ORDER BY location, date



--- USE CTE
-- We use this Common Table Expression because 'total_vaccination_count' can't be referred to within the same query it's created

WITH PopVsVac (continent, location, date, population, new_vaccinations, total_vaccination_count)
AS
(
SELECT 
	d.continent,
	d.location,
	d.date,
	d.population,
	v.new_vaccinations,
	SUM(cast(v.new_vaccinations as float)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS total_vaccination_count
	--(total_vaccinated_count/d.population)*100 AS percent_vaccinated
FROM PortfolioProject.dbo.[covid-deaths] d
JOIN PortfolioProject.dbo.[covid-vaccines] v
	ON d.location = v.location
	AND d.date = v.date
WHERE d.continent IS NOT NULL
--ORDER BY location, date
)
SELECT *, (total_vaccination_count/population)*100 AS doses_per_pop
FROM PopVsVac




--- USE TABLE
-- Creating a Temp Table instead to achieve the same effect as CTE

DROP TABLE IF EXISTS DosesPerPop
CREATE TABLE DosesPerPop
	(continent nvarchar(255),
	 location nvarchar(255),
	 date datetime, 
	 population numeric,
	 new_vaccinations numeric,
	 total_vaccination_count numeric,
	)

INSERT INTO DosesPerPop
SELECT 
	d.continent,
	d.location,
	d.date,
	d.population,
	v.new_vaccinations,
	SUM(cast(v.new_vaccinations as float)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS total_vaccination_count
	--(total_vaccinated_count/d.population)*100 AS percent_vaccinated
FROM PortfolioProject.dbo.[covid-deaths] d
JOIN PortfolioProject.dbo.[covid-vaccines] v
	ON d.location = v.location
	AND d.date = v.date
--WHERE d.continent IS NOT NULL
--ORDER BY location, date

SELECT *, (total_vaccination_count/population)*100 AS doses_per_pop
FROM DosesPerPop



--- Creating views to store data visualization later



--- View #1 (Death per Continent)
CREATE VIEW DeathPerContinent AS
SELECT 
	continent,
	MAX(total_deaths) as total_death_count
FROM PortfolioProject.dbo.[covid-deaths]
--WHERE DATALENGTH(iso_code) = 3
WHERE continent IS NOT NULL
GROUP BY continent
--ORDER BY total_death_count DESC  (CREATE VIEW doesn't allow ORDER BY function)



--- View #2 (Vaccines Doses Per Population Over Time)
CREATE VIEW DosesPerPopulation AS
WITH PopVsVac (continent, location, date, population, new_vaccinations, total_vaccination_count)
AS
(
SELECT 
	d.continent,
	d.location,
	d.date,
	d.population,
	v.new_vaccinations,
	SUM(cast(v.new_vaccinations as float)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS total_vaccination_count
	--(total_vaccinated_count/d.population)*100 AS percent_vaccinated
FROM PortfolioProject.dbo.[covid-deaths] d
JOIN PortfolioProject.dbo.[covid-vaccines] v
	ON d.location = v.location
	AND d.date = v.date
WHERE d.continent IS NOT NULL
--ORDER BY location, date
)
SELECT *, (total_vaccination_count/population)*100 AS doses_per_pop
FROM PopVsVac

SELECT *
FROM DosesPerPopulation