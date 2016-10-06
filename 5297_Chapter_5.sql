
-----------------------------------------------------------
-- Implementing the Design
-----------------------------------------------------------
CREATE DATABASE MovieRental
GO
USE MovieRental
GO
SELECT name, suser_sname(sid) as [login]
FROM sys.sysusers
WHERE name = 'dbo'
GO

-----------------------------------------------------------
--Basic Table Creation; Schema
-----------------------------------------------------------
USE AdventureWorks
GO

SELECT name, USER_NAME(principal_id) as principal
FROM sys.schemas
GO
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'Purchasing'
GO

USE MovieRental
GO
CREATE SCHEMA Inventory --tables pertaining to the videos to be rented
GO
CREATE SCHEMA People --tables pertaining to people (nonspecific)
GO
CREATE SCHEMA Rentals --tables pertaining to rentals to customers
GO
CREATE SCHEMA Alt
GO
-----------------------------------------------------------
-- Basic Table Creation;Nullability
-----------------------------------------------------------
ALTER DATABASE MovieRental
          SET ANSI_NULL_DEFAULT OFF

GO

--create test table
CREATE TABLE Alt.testNULL
(
        id int
)
GO
--check the values
EXEC sp_help 'Alt.testNULL'
GO

CREATE TABLE Inventory.Movie
(
    MovieId int NOT NULL,
    Name varchar(20) NOT NULL,
    ReleaseDate datetime NULL,
    Description varchar(200) NULL,
    GenreId int NOT NULL,
    MovieRatingId int NOT NULL
)
GO



-----------------------------------------------------------
-- Basic Table Creation;Surrogate Keys
-----------------------------------------------------------

CREATE TABLE Inventory.MovieRating (
    MovieRatingId int NOT NULL,
    Code varchar(20) NOT NULL,
    Description varchar(200) NULL,
    AllowYouthRentalFlag bit NOT NULL
)

INSERT INTO Inventory.MovieRating(MovieRatingId, Code, Description, AllowYouthRentalFlag)
VALUES (0, 'UR','Unrated',1)
INSERT INTO Inventory.MovieRating(MovieRatingId, Code, Description, AllowYouthRentalFlag)
VALUES (1, 'G','General Audiences',1)
INSERT INTO Inventory.MovieRating(MovieRatingId, Code, Description, AllowYouthRentalFlag)
VALUES (2, 'PG','Parental Guidance',1)
INSERT INTO Inventory.MovieRating(MovieRatingId, Code, Description, AllowYouthRentalFlag)
VALUES (3, 'PG-13','Parental Guidance for Children Under 13',1)
INSERT INTO Inventory.MovieRating(MovieRatingId, Code, Description, AllowYouthRentalFlag)
VALUES (4, 'R','Restricted, No Children Under 17 without Parent',0)
GO

CREATE TABLE Inventory.Genre (
    GenreId int NOT NULL,
    Name varchar(20) NOT NULL
)
GO
INSERT INTO Inventory.Genre (GenreId, Name)
VALUES (1,'Comedy')
INSERT INTO Inventory.Genre (GenreId, Name)
VALUES (2,'Drama')
INSERT INTO Inventory.Genre (GenreId, Name)
VALUES (3,'Thriller')
INSERT INTO Inventory.Genre (GenreId, Name)
VALUES (4,'Documentary')
GO

-----------------------------------------------------------
--Basic Table Creation;Generation Using the IDENTITY Property
-----------------------------------------------------------

DROP TABLE Inventory.Movie
GO
CREATE TABLE Inventory.Movie
(
    MovieId int NOT NULL IDENTITY(1,2),
    Name varchar(20) NOT NULL,
    ReleaseDate datetime NULL,
    Description varchar(200) NULL,
    GenreId int NOT NULL,
    MovieRatingId int NOT NULL
)

GO
INSERT INTO Inventory.Movie (Name, ReleaseDate,
Description, GenreId, MovieRatingId)
SELECT 'The Maltese Falcon','19411003',
        'A private detective finds himself surrounded by strange people ' +
        'looking for a statue filled with jewels',2,0
--Genre and Ratings values create as literal values because the Genre and
--Ratings tables are built with explicit values
--NOTE: ERROR IN TEXT: aunt's should be aunt''s

INSERT INTO Inventory.Movie (Name, ReleaseDate,
Description, GenreId, MovieRatingId)
SELECT 'Arsenic and Old Lace','19440923',
        'A man learns a disturbing secret about his aunt''s methods ' +
        'for treating gentleman callers',1,0
GO

SELECT MovieId, Name, ReleaseDate
FROM Inventory.Movie
GO
INSERT INTO Inventory.Movie (Name, ReleaseDate,
Description, GenreId, MovieRatingId)
SELECT 'Arsenic and Old Lace','19440923',
        'A man learns a disturbing secret about his aunt''s methods ' +
        'for treating gentleman callers',1,0
GO
SELECT MovieId, Name, ReleaseDate
FROM Inventory.Movie
GO
DELETE FROM Inventory.Movie
WHERE MovieId = 5 --This value may have changed
-----------------------------------------------------------
--Basic Table Creation;Uniqueness Keys;Primary Keys
-----------------------------------------------------------
CREATE TABLE Inventory.MovieFormat (
    MovieFormatId int NOT NULL
    CONSTRAINT PKMovieFormat PRIMARY KEY CLUSTERED,
    Name varchar(20) NOT NULL
)

INSERT INTO Inventory.MovieFormat(MovieFormatId, Name)
VALUES (1,'Video Tape')
INSERT INTO Inventory.MovieFormat(MovieFormatId, Name)
VALUES (1,'DVD')
GO

INSERT INTO Inventory.MovieFormat(MovieFormatId, Name)
VALUES (2,'DVD')
GO

CREATE TABLE Alt.Product
(
    Manufacturer varchar(30) NOT NULL,
    ModelNumber varchar(30) NOT NULL,
    CONSTRAINT PKProduct PRIMARY KEY NONCLUSTERED (Manufacturer, ModelNumber)
)
DROP TABLE Alt.Product --<<--table just for quick demo of syntax\
GO

ALTER TABLE Inventory.MovieRating
    ADD CONSTRAINT PKMovieRating PRIMARY KEY CLUSTERED (MovieRatingId)
ALTER TABLE Inventory.Genre
    ADD CONSTRAINT PKGenre PRIMARY KEY CLUSTERED (GenreId)
ALTER TABLE Inventory.Movie
    ADD CONSTRAINT PKMovie PRIMARY KEY CLUSTERED (MovieId)
GO

--NOTE:  THE SCHEMA IN THE BOOK WAS WRONG
CREATE TABLE dbo.Test (TestId int PRIMARY KEY)
GO
SELECT constraint_name
FROM information_schema.table_constraints
WHERE table_schema = 'dbo'
and table_name = 'test'

DROP TABLE dbo.TEST

-----------------------------------------------------------
--Basic Table Creation;Uniqueness Keys;Alternate Keys
-----------------------------------------------------------
GO
CREATE TABLE Inventory.Personality
(
    PersonalityId int NOT NULL IDENTITY(1,1)
    CONSTRAINT PKPersonality PRIMARY KEY,
    FirstName varchar(20) NOT NULL,
    LastName varchar(20) NOT NULL,
    NameUniqueifier varchar(5) NOT NULL,
    CONSTRAINT AKPersonality_PersonalityName UNIQUE NONCLUSTERED
    (FirstName, LastName, NameUniqueifier)
)
GO
ALTER TABLE Inventory.Genre
    ADD CONSTRAINT AKGenre_Name UNIQUE NONCLUSTERED (Name)
ALTER TABLE Inventory.MovieRating
    ADD CONSTRAINT AKMovieRating_Code UNIQUE NONCLUSTERED (Code)
ALTER TABLE Inventory.Movie
    ADD CONSTRAINT AKMovie_NameAndDate UNIQUE NONCLUSTERED (Name, ReleaseDate)

-----------------------------------------------------------
--Basic Table Creation;Uniqueness Keys;Viewing the Constraints
-----------------------------------------------------------

SELECT CONSTRAINT_SCHEMA, TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.table_constraints
ORDER BY CONSTRAINT_SCHEMA, TABLE_NAME
GO

-----------------------------------------------------------
--Basic Table Creation;Default Constraints
----------------------------------------------------------

CREATE TABLE People.Person (
    PersonId int NOT NULL IDENTITY(1,1)
    CONSTRAINT PKPerson PRIMARY KEY,
    FirstName varchar(20) NOT NULL,
    MiddleName varchar(20) NULL,
    LastName varchar(20) NOT NULL,
    SocialSecurityNumber char(11) --will be redefined using CLR later
    CONSTRAINT AKPerson_SSN UNIQUE
)
CREATE TABLE Rentals.Customer (
    CustomerId int NOT NULL
        CONSTRAINT PKCustomer PRIMARY KEY,
    CustomerNumber char(10)
        CONSTRAINT AKCustomer_CustomerNumber UNIQUE,
    PrimaryCustomerId int NULL,
    Picture varbinary(max) NULL,
    YouthRentalsOnlyFlag bit NOT NULL
        CONSTRAINT People_Person$can_be_a$Rentals_Customer FOREIGN KEY (CustomerId)
                                        REFERENCES People.Person (PersonId)
                                        ON DELETE CASCADE --cascade delete on SubType
                                        ON UPDATE NO ACTION,
        CONSTRAINT Rentals_Customer$can_rent_on_the_account_of$Rentals_Customer
                                        FOREIGN KEY (PrimaryCustomerId)
                                        REFERENCES Rentals.Customer (CustomerId)
                                        ON DELETE NO ACTION
                                        ON UPDATE NO ACTION
)
GO
ALTER TABLE Rentals.Customer
    ADD CONSTRAINT DfltCustomer_YouthRentalsOnlyFlag DEFAULT (0) FOR YouthRentalsOnlyFlag
GO
INSERT INTO People.Person(FirstName, MiddleName, LastName, SocialSecurityNumber)
VALUES ('Larry','','Quince','111-11-1111')
--skipping several of the columns that are either nullable or have defaults
INSERT INTO Rentals.Customer(CustomerId, CustomerNumber)
SELECT Person.PersonId, '1111111111'
FROM People.Person
WHERE SocialSecurityNumber = '111-11-1111'
GO
SELECT CustomerNumber, YouthRentalsOnlyFlag
FROM Rentals.Customer
GO

--Using the Alt schema for alternative examples
CREATE TABLE Alt.url
(
    scheme varchar(10) NOT NULL, --http, ftp
    computerName varchar(50) NOT NULL, --www, or whatever
    domainName varchar(50) NOT NULL, --base domain name (microsoft, amazon, etc.)
    siteType varchar(5) NOT NULL, --net, com, org
    filePath varchar(255) NOT NULL,
    fileName varchar(20) NOT NULL,
    parameter varchar(255) NOT NULL,
    PRIMARY KEY (scheme, computerName, domainName, siteType,
                filePath, fileName, parameter)
)
GO
INSERT INTO alt.url (scheme, computerName, domainName, siteType,
                     filePath, filename, parameter)
VALUES ('http','www','microsoft','com','','','')

SELECT scheme + '://' + computerName +
        case when len(rtrim(computerName)) > 0 then '.' else '' end +
        domainName + '.'
        + siteType
        + case when len(filePath) > 0 then '/' else '' end + filePath
        + case when len(fileName) > 0 then '/' else '' end + fileName
        + parameter as display
FROM alt.url

GO

ALTER TABLE Alt.url
    ADD CONSTRAINT dfltUrl_scheme DEFAULT ('http') FOR scheme
ALTER TABLE alt.url
    ADD CONSTRAINT dfltUrl_computerName DEFAULT ('www') FOR computerName
ALTER TABLE alt.url
    ADD CONSTRAINT dfltUrl_siteType DEFAULT ('com') FOR siteType
ALTER TABLE alt.url
    ADD CONSTRAINT dfltUrl_filePath DEFAULT ('') FOR filePath
ALTER TABLE alt.url
    ADD CONSTRAINT dfltUrl_fileName DEFAULT ('') FOR fileName
ALTER TABLE alt.url
    ADD CONSTRAINT dfltUrl_parameter DEFAULT ('') FOR parameter
GO
INSERT INTO alt.url (domainName)
VALUES ('usatoday')
GO
SELECT scheme + '://' + computerName +
        case when len(rtrim(computerName)) > 0 then '.' else '' end +
        domainName + '.'
        + siteType
        + case when len(filePath) > 0 then '/' else '' end + filePath
        + case when len(fileName) > 0 then '/' else '' end + fileName
        + parameter as display
FROM alt.url
GO

SELECT cast(column_name as varchaR(20)) as column_name, column_default
FROM information_schema.columns
WHERE table_schema = 'Alt'
AND table_name = 'url'
GO
-----------------------------------------------------------
--Basic Table Creation;Default Constraints;Rich Expressions
----------------------------------------------------------
GO
CREATE TABLE Rentals.MovieRental (
        MovieRentalId int NOT NULL IDENTITY(1,1)
        CONSTRAINT PKMovieRental PRIMARY KEY,
        ReturnDate smalldatetime NOT NULL,
        ActualReturnDate smalldatetime NULL,
        MovieRentalInventoryItemId int NOT NULL,
        CustomerId int NOT NULL,
        RentalDatetime smalldatetime NOT NULL,
        RentedByEmployeeId int NOT NULL,
        AmountPaid decimal(4,2) NOT NULL,
        CONSTRAINT AKMovieRental UNIQUE (RentalDatetime,MovieRentalInventoryItemId, CustomerId)
)
GO
ALTER TABLE Rentals.MovieRental
    ADD CONSTRAINT DfltMovieRental_RentalDatetime DEFAULT (GETDATE()) FOR RentalDatetime
ALTER TABLE Rentals.MovieRental
    ADD CONSTRAINT DfltMovieRental_ReturnDate
    --Default to 10:00 on the fourth day
    DEFAULT (DATEADD(Day,4,CONVERT(varchar(8),getdate(),112) + ' 22:00')) FOR ReturnDate
GO

INSERT Rentals.MovieRental (MovieRentalInventoryItemId, CustomerId,RentedByEmployeeId, AmountPaid)
VALUES (0,0,0,0.00)
GO
SELECT RentalDatetime, ReturnDate
FROM Rentals.MovieRental
GO
-----------------------------------------------------------
--Basic Table Creation; Relationships (Foreign Keys)
-----------------------------------------------------------
GO
ALTER TABLE Inventory.Movie
    ADD CONSTRAINT Inventory_MovieRating$defines_age_appropriateness_of$Inventory_Movie
        FOREIGN KEY (MovieRatingId) 
        REFERENCES Inventory.MovieRating (MovieRatingId)
            ON DELETE NO ACTION
            ON UPDATE NO ACTION
ALTER TABLE Inventory.Movie
    ADD CONSTRAINT Inventory_Genre$categorizes$Inventory_Movie
        FOREIGN KEY (GenreId)
        REFERENCES Inventory.Genre (GenreId)
            ON DELETE NO ACTION
            ON UPDATE NO ACTION
GO
INSERT INTO Inventory.Movie (Name, ReleaseDate,Description, GenreId, MovieRatingId)
SELECT 'Stripes','19810626',
    'A loser joins the Army, though the Army is not really ready for him',-1,-1
GO
INSERT INTO Inventory.Movie (Name, ReleaseDate,Description, GenreId, MovieRatingId)
SELECT 'Stripes','19810626','A loser joins the Army, though the Army is not really ready for him',
        MovieRating.MovieRatingId, Genre.GenreId
FROM Inventory.MovieRating as MovieRating
        CROSS JOIN Inventory.Genre as Genre
WHERE MovieRating.Code = 'R'
  AND Genre.Name = 'Comedy'
GO
DELETE FROM Inventory.Genre
WHERE Name = 'Comedy'
GO
----------------------------------------------------------------------------------------------------------------------
--Basic Table Creation; Relationships (Foreign Keys); Automated Relationship Options
----------------------------------------------------------------------------------------------------------------------
CREATE TABLE Inventory.MoviePersonality (
    MoviePersonalityId int NOT NULL IDENTITY (1,1) CONSTRAINT PKMoviePersonality PRIMARY KEY,
    MovieId int NOT NULL,
    PersonalityId int NOT NULL,
    CONSTRAINT AKMoviePersonality_MoviePersonality UNIQUE (PersonalityId,MovieId)
)
GO
ALTER TABLE Inventory.MoviePersonality
    ADD CONSTRAINT Inventory_Personality$is_linked_to_movies_via$Inventory_MoviePersonality
    FOREIGN KEY (MovieId) REFERENCES Inventory.Movie (MovieId)
        ON DELETE CASCADE
        ON UPDATE NO ACTION
ALTER TABLE Inventory.MoviePersonality
    ADD CONSTRAINT Inventory_Movie$is_linked_to_important_people_via$Inventory_MoviePersonality
    FOREIGN KEY (PersonalityId)
    REFERENCES Inventory.Personality (PersonalityId)
        ON DELETE CASCADE
        ON UPDATE NO ACTION
GO
INSERT INTO Inventory.Personality (FirstName, LastName, NameUniqueifier)
VALUES ('Cary','Grant','')
INSERT INTO Inventory.Personality (FirstName, LastName, NameUniqueifier)
VALUES ('Humphrey','Bogart','')
GO
INSERT INTO Inventory.MoviePersonality (MovieId, PersonalityId)
SELECT Movie.MovieId, Personality.PersonalityId
FROM Inventory.Movie as Movie
        CROSS JOIN Inventory.Personality as Personality
WHERE Movie.Name = 'The Maltese Falcon'
  AND Personality.FirstName = 'Humphrey'
  AND Personality.LastName = 'Bogart'
  AND Personality.NameUniqueifier = ''
UNION ALL
SELECT Movie.MovieId, Personality.PersonalityId
FROM Inventory.Movie as Movie
        CROSS JOIN Inventory.Personality as Personality
WHERE Movie.Name = 'Arsenic and Old Lace'
  AND Personality.FirstName = 'Cary'
  AND Personality.LastName = 'Grant' 
  AND Personality.NameUniqueifier = '' 
GO

SELECT Movie.Name as Movie, Personality.FirstName + ' '+ Personality.LastName as Personality
FROM Inventory.MoviePersonality as MoviePersonality
    LEFT OUTER JOIN Inventory.Personality as Personality
        ON MoviePersonality.PersonalityId = Personality.PersonalityId
    LEFT OUTER JOIN Inventory.Movie as Movie
        ON Movie.MovieId = MoviePersonality.MovieId
GO
DELETE FROM Inventory.Movie
WHERE Name = 'Arsenic and Old Lace'
GO
SELECT Movie.Name as Movie, Personality.FirstName + ' '+ Personality.LastName as Personality
FROM Inventory.MoviePersonality as MoviePersonality
    LEFT OUTER JOIN Inventory.Personality as Personality
        ON MoviePersonality.PersonalityId = Personality.PersonalityId
    LEFT OUTER JOIN Inventory.Movie as Movie
        ON Movie.MovieId = MoviePersonality.MovieId
GO

----------------------------------------------------------------------------------------------------------------------
--Basic Table Creation; Relationships (Foreign Keys); Automated Relationship Options;Cascade Operations
----------------------------------------------------------------------------------------------------------------------

CREATE TABLE Alt.Movie
(
    MovieCode varchar(20)
    CONSTRAINT PKMovie PRIMARY KEY,
    MovieName varchar(200)
)
CREATE TABLE Alt.MovieRentalPackage
(
    MovieRentalPackageCode varchar(25) CONSTRAINT PKMovieRentalPackage PRIMARY KEY,
    MovieCode varchar(20)
    CONSTRAINT Alt_Movie$is_rented_as$Alt_MovieRentalPackage
        FOREIGN KEY References Alt.Movie(MovieCode)
            ON DELETE CASCADE
            ON UPDATE CASCADE
)
GO
INSERT INTO Alt.Movie (MovieCode, MovieName)
VALUES ('ArseOldLace','Arsenic and Old Lace')
INSERT INTO Alt.MovieRentalPackage (MovieRentalPackageCode,MovieCode)
VALUES ('ArsenicOldLaceDVD','ArseOldLace')
GO
UPDATE Alt.Movie
SET MovieCode = 'ArsenicOldLace'
WHERE MovieCode = 'ArseOldLace' --< if you enjoyed this name you need help :)
GO
SELECT *
FROM Alt.Movie
SELECT *
FROM Alt.MovieRentalPackage
GO

----------------------------------------------------------------------------------------------------------------------
--Basic Table Creation; Relationships (Foreign Keys); Automated Relationship Options;Cascade Operations;Set Null
----------------------------------------------------------------------------------------------------------------------

ALTER TABLE Rentals.Customer
    ADD FavoriteMovieId INT NULL --allow nulls or SET NULL will be invalid
--Next define the foreign key constraint with SET NULL:
ALTER TABLE Rentals.Customer
    ADD FOREIGN KEY (FavoriteMovieId)
        REFERENCES Inventory.Movie (MovieId)
        ON DELETE SET NULL
        ON UPDATE NO ACTION
GO

INSERT INTO People.Person(FirstName, MiddleName, LastName, SocialSecurityNumber)
VALUES ('Jerry','J','Smork','222-22-2222')

INSERT INTO Rentals.Customer(CustomerId, CustomerNumber,PrimaryCustomerId, 
                            Picture, YouthRentalsOnlyFlag,FavoriteMovieId)
SELECT Person.PersonId, '2222222222',NULL, NULL, 0, NULL
FROM People.Person
WHERE SocialSecurityNumber = '222-22-2222'
GO

SELECT MovieId, ReleaseDate
FROM Inventory.Movie
WHERE Name = 'Stripes'
GO

UPDATE Rentals.Customer
SET FavoriteMovieId = 9 --<--You may have to change this value
WHERE CustomerNumber = '2222222222'
GO

SELECT Customer.CustomerNumber, Movie.Name AS FavoriteMovie
FROM Rentals.Customer AS Customer
        LEFT OUTER JOIN Inventory.Movie AS Movie
            ON Movie.MovieId = Customer.FavoriteMovieId
WHERE Customer.CustomerNumber = '2222222222'
GO

----------------------------------------------------------------------------------------------------------------------
--Basic Table Creation; Relationships (Foreign Keys); Automated Relationship Options;Cascade Operations;Set Default
----------------------------------------------------------------------------------------------------------------------
INSERT INTO Inventory.MovieFormat(MovieFormatId, Name)
VALUES (3, 'Playstation Portable')
GO
ALTER TABLE Rentals.Customer
    ADD DefaultMovieFormatId INT NOT NULL
    CONSTRAINT DfltCustomer_DefaultMovieFormatId DEFAULT (2) 
                --DVD (Can hard code because surrogate key hand created)
GO
ALTER TABLE Rentals.Customer
    --NOTE: NAME WAS LEFT OUT OF TEXT
    ADD CONSTRAINT rentals_movieFormat$is_the_default_choice_for$rentals_customer
        FOREIGN KEY (DefaultMovieFormatId)
        REFERENCES Inventory.MovieFormat (MovieFormatId)
            ON DELETE SET DEFAULT
            ON UPDATE NO ACTION
GO
UPDATE Rentals.Customer
SET DefaultMovieFormatId = 3
WHERE CustomerNumber = '2222222222'
GO
DELETE FROM Inventory.MovieFormat
WHERE Name = 'Playstation Portable'
GO
SELECT MovieFormat.Name
FROM Inventory.MovieFormat as MovieFormat
        JOIN Rentals.Customer
            ON MovieFormat.MovieFormatId = Customer.DefaultMovieFormatId
WHERE Customer.CustomerNumber = '2222222222'
GO
-----------------------------------------------------------
--Basic Table Creation; Large-Value Datatype Columns
-----------------------------------------------------------
SELECT len(
            cast(replicate('a',8000) as varchar(8000))
            + cast(replicate('a',8000) as varchar(8000))
)
SELECT len(
    cast(replicate('a',8000) as varchar(max))
    + cast(replicate('a',8000) as varchar(8000))
)
GO

-----------------------------------------------------------
--Basic Table Creation; Large-Value Datatype Columns
-----------------------------------------------------------

SELECT serverproperty('collation')
SELECT databasepropertyex('MovieRental','collation')
GO
-----------------------------------------------------------
--Basic Table Creation; Collation (Sort Order)
-----------------------------------------------------------
SELECT serverproperty('collation')
SELECT databasepropertyex('MovieRental','collation')
GO
SELECT *
FROM ::fn_helpcollations()
GO
CREATE TABLE alt.OtherCollate
(
    OtherCollateId integer IDENTITY CONSTRAINT PKOtherCollate Primary Key,
    Name nvarchar(30) NOT NULL,
    FrenchName nvarchar(30) COLLATE French_CI_AS_WS NULL,
    SpanishName nvarchar(30) COLLATE Modern_Spanish_CI_AS_WS NULL
)
GO
CREATE TABLE alt.collateTest
(
    name VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)
INSERT INTO alt.collateTest(name)
VALUES ('BOB')
INSERT INTO alt.collateTest(name)
VALUES ('bob')
GO
SELECT name
FROM alt.collateTest
WHERE name = 'BOB'
GO
SELECT name
FROM alt.collateTest
WHERE name = 'BOB' COLLATE Latin1_General_BIN
GO
SELECT name
FROM alt.collateTest
WHERE name COLLATE Latin1_General_BIN = 'BOB' COLLATE Latin1_General_BIN
GO
-----------------------------------------------------------
----Basic Table Creation;Computed Columns
-----------------------------------------------------------
GO
--NOTE: THIS WAS WRONG IN THE TEXT
ALTER TABLE Inventory.Personality
    ADD FullName as FirstName + ' ' + LastName + 
            case when len(NameUniqueifier) > 0 then '(' +  NameUniqueifier + ')' else '' end
GO
INSERT INTO Inventory.Personality (FirstName, LastName, NameUniqueifier)
VALUES ('John','Smith','I')
INSERT INTO Inventory.Personality (FirstName, LastName, NameUniqueifier)
VALUES ('John','Smith','II')
GO
SELECT *
FROM Inventory.Personality
GO
CREATE TABLE alt.calcColumns
(
    dateColumn datetime,
    dateSecond AS datepart(second,dateColumn) PERSISTED -- calculated column
)
SET NOCOUNT ON
DECLARE @i int
SET @i = 1
WHILE (@i < 200)
 BEGIN
    INSERT INTO alt.calcColumns (dateColumn) VALUES (getdate())
    WAITFOR DELAY '00:00:00.01' --or the query runs too fast
    SET @i = @i + 1
 END

SELECT dateSecond, max(dateColumn) as dateColumn, count(*) AS countStar
FROM alt.calcColumns
GROUP BY dateSecond
ORDER BY dateSecond
GO

CREATE TABLE alt.testCalc
(
    value varchar(10),
    valueCalc AS UPPER(value),
    value2 varchar(10)
)
GO
INSERT INTO alt.testCalc
VALUES ('test','test2')
GO
SELECT *
FROM alt.testCalc

-----------------------------------------------------------
----Basic Table Creation;Complex DataType
-----------------------------------------------------------
GO
CREATE TYPE SSN
    FROM char(11)
        NOT NULL
GO
CREATE TABLE alt.Person
(
    PersonId int NOT NULL,
    FirstName varchar(30) NOT NULL,
    LastName varchar(30) NOT NULL,
    SSN SSN --no null specification to make a point
    --generally it is a better idea to
    --include a null spec.
)
GO
INSERT Alt.Person
VALUES (1,'krusty','clown','234-43-3432')
GO
Select * from alt.person

SELECT PersonId, FirstName, LastName, SSN
FROM Alt.Person
go
INSERT Alt.Person
VALUES (2,'moe','sizlack',NULL)
GO
-----------------------------------------------------------
----Basic Table Creation;CLR-Based Datatypes
-----------------------------------------------------------
GO
EXEC sp_configure 'clr enabled', 1
go
RECONFIGURE
GO

-----------------------------------------------------------------------------
-- uses the object from the 5297_CLRProjects.zip file.  There is a CLR and 
-- C# version.  This code
-----------------------------------------------------------------------------

CREATE ASSEMBLY MyUDT from 'C:\ProDatabaseDesignSqlClr\VB\UDTSsn\bin\UDTSsn.dll' WITH PERMISSION_SET = SAFE
GO
CREATE TYPE [SSN_CLR] --NOTE: Named SSN in book
	EXTERNAL NAME [MyUDT].[Apress.ProSqlServerDatabaseDesign.SsnUdt]
GO

/*
CREATE TABLE People.Person (
    PersonId int NOT NULL IDENTITY(1,1) CONSTRAINT PKPerson PRIMARY KEY,
    FirstName varchar(20) NOT NULL,
    MiddleName varchar(20) NULL,
    LastName varchar(20) NOT NULL,
    SocialSecurityNumber char(11) --will be redefined using CLR later
            CONSTRAINT AKPerson_SSN UNIQUE
)
--GO
*/

ALTER TABLE People.Person
    ADD SocialSecurityNumberCLR SSN_CLR NULL
GO

UPDATE People.Person
SET SocialSecurityNumberCLR = SocialSecurityNumber
GO

ALTER TABLE People.Person
    DROP CONSTRAINT AKPerson_SSN
ALTER TABLE People.Person
    DROP COLUMN SocialSecurityNumber

EXEC sp_rename 'People.Person.SocialSecurityNumberCLR','SocialSecurityNumber', 'COLUMN';
GO
ALTER TABLE People.Person
    ALTER COLUMN SocialSecurityNumber SSN NOT NULL
ALTER TABLE People.Person
    ADD CONSTRAINT AKPerson_SSN UNIQUE (SocialSecurityNumber)
GO
SELECT SocialSecurityNumber, socialSecurityNumber.ToString() as CastedVersion
FROM People.Person
GO
-----------------------------------------------------------
-- Documentation
-----------------------------------------------------------
/*
CREATE SCHEMA Inventory --tables pertaining to the videos to be rented
CREATE TABLE Inventory.Movie
(
MovieId int NOT NULL,
Name varchar(20) NOT NULL,
ReleaseDate datetime NULL,
Description varchar(200) NULL,
GenreId int NOT NULL,
MovieRatingId int NOT NULL
)
*/

--dbo.person table description
EXEC sp_addextendedproperty @name = 'Description',
                            @value = 'tables pertaining to the videos to be rented',
                            @level0type = 'Schema', @level0name = 'Inventory'
--dbo.person table description
EXEC sp_addextendedproperty @name = 'Description',
                            @value = 'Defines movies that will be rentable in the store',
                            @level0type = 'Schema', @level0name = 'Inventory',
                            @level1type = 'Table', @level1name = 'Movie'
--dbo.person.personId description
EXEC sp_addextendedproperty @name = 'Description',
                            @value = 'Surrogate key of a movie instance',
                            @level0type = 'Schema', @level0name = 'Inventory',
                            @level1type = 'Table', @level1name = 'Movie',
                            @level2type = 'Column', @level2name = 'MovieId'
--dbo.person.firstName description
EXEC sp_addextendedproperty @name = 'Description',
                            @value = 'The known name of the movie',
                            @level0type = 'Schema', @level0name = 'Inventory',
                            @level1type = 'Table', @level1name = 'Movie',
                            @level2type = 'Column', @level2name = 'Name'
--dbo.person.lastName description
EXEC sp_addextendedproperty @name = 'Description',
                            @value = 'The date the movie was originally released',
                            @level0type = 'Schema', @level0name = 'Inventory',
                            @level1type = 'Table', @level1name = 'Movie',
                            @level2type = 'Column', @level2name = 'ReleaseDate'
GO
SELECT objname, value
FROM fn_listExtendedProperty ('Description',
'Schema','Inventory',
'Table','Movie',
'Column',null)