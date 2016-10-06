--------------------------------------------------------------------
-- Example Schema Creation
--------------------------------------------------------------------

CREATE DATABASE ProtectionChapter
GO
CREATE SCHEMA Music
GO
CREATE TABLE Music.Artist
(
   ArtistId int NOT NULL,
   Name varchar(60) NOT NULL,

   CONSTRAINT PKNameArtist PRIMARY KEY CLUSTERED (ArtistId),
   CONSTRAINT AKNameArtist_Name UNIQUE NONCLUSTERED (Name)
)
CREATE TABLE Music.Publisher
(
        PublisherId              int primary key,
        Name                      varchar(20),
        CatalogNumberMask varchar(100) 
        CONSTRAINT DfltNamePublisher_catalogNumberMask default ('%'),
        CONSTRAINT AKNamePublisher_Name UNIQUE NONCLUSTERED (Name),  
)
CREATE TABLE Music.Album
(
   AlbumId int NOT NULL,
   Name varchar(60) NOT NULL,
   ArtistId int NOT NULL,
   CatalogNumber varchar(20) NOT NULL,
   PublisherId int NOT null --not requiring this information

   CONSTRAINT PKAlbum PRIMARY KEY CLUSTERED(AlbumId),
   CONSTRAINT AKAlbum_Name UNIQUE NONCLUSTERED (Name),
   CONSTRAINT FKMusic_Artist$records$Music_Album 
            FOREIGN KEY (ArtistId) REFERENCES Music.Artist(ArtistId),
   CONSTRAINT FKMusic_Publisher$published$Music_Album
            FOREIGN KEY (PublisherId) REFERENCES Music.Publisher(PublisherId)
)
GO
----------------------------------------------------------------------------

INSERT INTO Music.Publisher (PublisherId, Name, CatalogNumberMask)
VALUES (1,'Capitol','[0-9][0-9][0-9]-[0-9][0-9][0-9a-z][0-9a-z][0-9a-z]-[0-9][0-9]')
INSERT INTO Music.Publisher (PublisherId, Name, CatalogNumberMask)
VALUES (2,'MCA', '[a-z][a-z][0-9][0-9][0-9][0-9][0-9]')
GO

INSERT INTO Music.Artist(ArtistId, Name)
VALUES (1, 'The Beatles')
INSERT INTO Music.Artist(ArtistId, Name)
VALUES (2, 'The Who')
GO

INSERT INTO Music.Album (AlbumId, Name, ArtistId, PublisherId, CatalogNumber)
VALUES (1, 'The White Album',1,1,'433-43ASD-33')
INSERT INTO Music.Album (AlbumId, Name, ArtistId, PublisherId, CatalogNumber)
VALUES (2, 'Revolver',1,1,'111-11111-11')
INSERT INTO Music.Album (AlbumId, Name, ArtistId, PublisherId, CatalogNumber)
VALUES (3, 'Quadrophenia',2,2,'CD12345')
GO

----------------------------------------------------------------------------
-- Basic Syntax;<BooleanExpression>
----------------------------------------------------------------------------
ALTER TABLE Music.Artist WITH CHECK 
   ADD CONSTRAINT chkArtist$Name$NoDuranNames
           CHECK (Name not like '%Duran%')
GO
----------------------------------------------------------------------------

INSERT INTO Music.Artist(ArtistId, Name)
VALUES (3, 'Duran Duran')

GO
----------------------------------------------------------------------------

INSERT INTO Music.Artist(ArtistId, Name)
VALUES (3, 'Madonna')
GO

----------------------------------------------------------------------------
-- Basic Syntax [WITH CHECK | WITH NOCHECK]
----------------------------------------------------------------------------

ALTER TABLE Music.Artist WITH NOCHECK 
   ADD CONSTRAINT chkArtist$Name$noMadonnaNames
           CHECK (Name not like '%Madonna%')
GO
----------------------------------------------------------------------------

UPDATE Music.Artist
SET Name = Name
GO
----------------------------------------------------------------------------

SELECT CHECK_CLAUSE, 
       objectproperty(object_id(CONSTRAINT_SCHEMA + '.' + 
                                 CONSTRAINT_NAME),'CnstIsNotTrusted') AS NotTrusted
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'Music'
  And CONSTRAINT_NAME = 'chkArtist$Name$noMadonnaNames'
GO
----------------------------------------------------------------------------
-- Basic Syntax; Simple Expressions
----------------------------------------------------------------------------

INSERT INTO Music.Album ( AlbumId, Name, ArtistId, PublisherId, CatalogNumber )
VALUES ( 4, '', 1, 1,'dummy value' ) 

GO
----------------------------------------------------------------------------

INSERT INTO Music.Album ( AlbumId, Name, ArtistId, PublisherId, CatalogNumber )
VALUES ( 5, '', 1, 1,'dummy value' ) 

GO
----------------------------------------------------------------------------

DELETE FROM Music.Album
WHERE  Name = ''

ALTER TABLE Music.album WITH CHECK 
   ADD CONSTRAINT chkdesignBook_album$Name$noEmptyString
           CHECK (LEN(RTRIM(Name)) > 0)

GO
----------------------------------------------------------------------------
-- Basic Syntax; Constraints Based on Functions
----------------------------------------------------------------------------

CREATE FUNCTION Music.Publisher$CatalogNumberValidate
(
   @CatalogNumber char(12),
   @PublisherId int --now based on the Artist id
) 
RETURNS bit
AS
BEGIN 
   DECLARE @LogicalValue bit, @CatalogNumberMask varchar(100)

   SELECT @LogicalValue = CASE WHEN @CatalogNumber LIKE CatalogNumberMask 
                                      THEN 1 
                               ELSE 0  END
   FROM   Music.Publisher
   WHERE  PublisherId = @PublisherId

   RETURN @LogicalValue
END

GO
----------------------------------------------------------------------------

SELECT Album.CatalogNumber, Publisher.CatalogNumberMask
FROM   Music.Album as Album
         JOIN Music.Publisher as Publisher
            ON Album.PublisherId = Publisher.PublisherId

GO
----------------------------------------------------------------------------

ALTER TABLE Music.album
   WITH CHECK ADD CONSTRAINT 
       chkAlbum$CatalogNumber$CatalogNumberValidate 
       CHECK (Music.Publisher$CatalogNumbervalidate(CatalogNumber,PublisherId) = 1) 

GO
----------------------------------------------------------------------------

--to find where your data is not ready for the constraint, 
--you run the following query
SELECT Album.Name, Album.CatalogNumber, Publisher.CatalogNumberMask
FROM Music.Album AS Album
       JOIN Music.Publisher AS Publisher
         on Publisher.PublisherId = Album.PublisherId
WHERE Music.Publisher$CatalogNumbervalidate
                        (Album.CatalogNumber,Album.PublisherId) <> 1

GO
----------------------------------------------------------------------------

INSERT  Music.Album(AlbumId, Name, ArtistId, PublisherId, CatalogNumber)
VALUES  (4,'who''s next',2,2,'1')

GO
----------------------------------------------------------------------------

INSERT  Music.Album(AlbumId, Name, ArtistId, CatalogNumber, PublisherId)
VALUES  (4,'who''s next',2,'AC12345',2)

SELECT * from Music.Album

GO
----------------------------------------------------------------------------
-- Handling Errors Caused By Constraints
----------------------------------------------------------------------------

--note, we use dbo here because the errorLog will be used by all schemas
CREATE TABLE dbo.ErrorMap 
(  
    ConstraintName sysname primary key,
    Message         varchar(2000)
)
go
INSERT dbo.ErrorMap(ConstraintName, Message)
VALUES ('chkAlbum$CatalogNumber$CatalogNumberValidate',
        'The catalog number does not match the format set up by the Publisher')

GO
----------------------------------------------------------------------------

CREATE PROCEDURE dbo.ErrorMap$MapError
(
    @ErrorNumber  int = NULL,
    @ErrorMessage nvarchar(2000) = NULL,
    @ErrorSeverity INT= NULL,
    @ErrorState INT = NULL
) AS
  BEGIN
    --use values in ERROR_ functions unless the user passes invalues
    SET @ErrorNumber = Coalesce(@ErrorNumber, ERROR_NUMBER())
    SET @ErrorMessage = Coalesce(@ErrorMessage, ERROR_MESSAGE())
    SET @ErrorSeverity = Coalesce(@ErrorSeverity, ERROR_SEVERITY())
    SET @ErrorState = Coalesce(@ErrorState,ERROR_STATE())

    DECLARE @originalMessage nvarchar(2000)
    SET @originalMessage = ERROR_MESSAGE()

    IF @ErrorNumber = 547
      BEGIN
           SET @ErrorMessage = 
                           (SELECT message 
                            FROM   dbo.ErrorMap 
                            WHERE  constraintName = 
             --this substring pulls the constraint name from the message
             substring( @ErrorMessage,CHARINDEX('constraint "',@ErrorMessage) + 12, 
                             charindex('"',substring(@ErrorMessage, 
                             CHARINDEX('constraint "',@ErrorMessage) + 12,2000))-1)
                            )      END
    ELSE
        SET @ErrorMessage = @ErrorMessage

    SET @ErrorState = CASE when @ErrorState = 0 THEN 1 ELSE @ErrorState END
    
    --if the error was not found, get the original message
    SET @ErrorMessage = isNull(@ErrorMessage, @originalMessage)
    RAISERROR (@ErrorMessage, @ErrorSeverity,@ErrorState )
  END

GO
----------------------------------------------------------------------------

BEGIN TRY
     INSERT  Music.Album(AlbumId, Name, ArtistId, CatalogNumber, PublisherId)
     VALUES  (5,'who are you',2,'badnumber',2)
END TRY
BEGIN CATCH
    EXEC dbo.ErrorMap$mapError 
END CATCH

GO
----------------------------------------------------------------------------
--note, we use dbo here because the errorLog will be used by all schemas

CREATE TABLE dbo.errorLog(
        ERROR_NUMBER int NOT NULL,
        ERROR_LOCATION sysname NOT NULL, 
        ERROR_MESSAGE varchar(4000),
        ERROR_DATE datetime NULL 
                     CONSTRAINT DFLTdbo_errorLog__error_date  DEFAULT (getdate()),
        ERROR_USER sysname NOT NULL 
                     CONSTRAINT DFLTdbo_errorLog__error_user  DEFAULT (user_name())
) 
GO
CREATE PROCEDURE dbo.errorLog$insert
(
        @ERROR_NUMBER int = NULL,
        @ERROR_LOCATION sysname = NULL,
        @ERROR_MESSAGE varchar(4000) = NULL
) as
 BEGIN
    BEGIN TRY
           INSERT INTO dbo.errorLog(ERROR_NUMBER, ERROR_LOCATION, ERROR_MESSAGE)
           SELECT isnull(@ERROR_NUMBER,ERROR_NUMBER()),
              isnull(@ERROR_LOCATION,ERROR_MESSAGE()),
              isnull(@ERROR_MESSAGE,ERROR_MESSAGE())        
        END TRY
        BEGIN CATCH
           INSERT INTO dbo.errorLog(ERROR_NUMBER, ERROR_LOCATION, ERROR_MESSAGE)
           VALUES (-100, 'dbo.errorLog$insert', 
                        'An invalid call was made to the error log procedure')        
        END CATCH
 END

GO
----------------------------------------------------------------------------
-- T-SQL After Triggers; Range Checks on Multiple Rows
----------------------------------------------------------------------------


CREATE SCHEMA Accounting
GO
----------------------------------------------------------------------------

CREATE TABLE Accounting.Account
(
        AccountNumber        char(10) constraint PKAccount primary key
        --would have other columns
)

CREATE TABLE Accounting.AccountActivity
(
        AccountNumber                char(10) 
            constraint Accounting_Account$has$Accounting_AccountActivity 
                       foreign key references Accounting.Account(AccountNumber),
       --this might be a value that each ATM/Teller generates 
        TransactionNumber        char(20),
        Date                        datetime,
        TransactionAmount        money,
        constraint PKAccountActivity 
                      primary key (AccountNumber, TransactionNumber)
)

GO
----------------------------------------------------------------------------

CREATE TRIGGER Accounting.AccountActivity$insertTrigger
ON Accounting.AccountActivity
AFTER INSERT,UPDATE AS
BEGIN
------------------------------------------------------------------------------
-- Purpose : Trigger on the <action> that fires for any <action> DML 
------------------------------------------------------------------------------
   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return 
   
   SET NOCOUNT ON
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   inserted
                             WHERE  inserted.AccountNumber = 
                               AccountActivity.AccountNumber)
                   GROUP BY AccountNumber
                   HAVING sum(TransactionAmount) < 0)
      BEGIN
         IF @rowsAffected = 1 
             SELECT @msg = 'Account: ' + AccountNumber + 
                  ' TransactionNumber:' + 
                   cast(TransactionNumber as varchar(36)) + 
                   ' for amount: ' + cast(TransactionAmount as varchar(10))+
                   ' cannot be processesed as it will cause a negative balance'
             FROM   inserted
        ELSE
          SELECT @msg = 'One of the rows caused a negative balance'
         RAISERROR (@msg, 16, 1)
      END
   END TRY
   BEGIN CATCH 
                IF @@trancount > 0 
                       ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE dbo.errorLog$insert 

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END

----------------------------------------------------------------------------

SELECT sys.trigger_events.type_desc
FROM sys.trigger_events 
JOIN sys.triggers 
ON sys.triggers.object_id = sys.trigger_events.object_id
WHERE sys.triggers.name = 'accountActivity$insertTrigger'
GO

----------------------------------------------------------------------------

--create some set up test data
INSERT into Accounting.Account(AccountNumber)
VALUES ('1111111111')
INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber, 
                                                          Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000001','20050712',100)
INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber, 
                                                          Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000002','20050713',100)

GO
----------------------------------------------------------------------------

INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber, 
                                                           Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000003','20050713',-300)

GO
----------------------------------------------------------------------------

--create new Account
INSERT  into Accounting.Account(AccountNumber)
VALUES ('2222222222')

--Now, this data will violate the constraint for the new Account:
INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
select '1111111111','A0000000000000000004','20050714',100
UNION
select '2222222222','A0000000000000000005','20050715',100
UNION
select '2222222222','A0000000000000000006','20050715',100
UNION
select '2222222222','A0000000000000000007','20050715',-201
GO

----------------------------------------------------------------------------
-- T-SQL After Triggers; Cascading Inserts
----------------------------------------------------------------------------

CREATE SCHEMA Internet
go
CREATE TABLE Internet.Url
(
    UrlId int not null identity(1,1) constraint PKUrl primary key,
    Name  varchar(60) not null constraint AKUrl_Name UNIQUE,
    Url   varchar(200) not null constraint AKUrl_Url UNIQUE
)

--Not a user manageable table, so not using identity key (as discussed in 
--Chapter 5 when I discussed choosing keys)
CREATE TABLE Internet.UrlStatusType
(
        UrlStatusTypeId  int not null constraint PKUrlStatusType PRIMARY KEY,
        Name varchar(20) NOT NULL CONSTRAINT AKUrlStatusType UNIQUE,
        DefaultFlag bit NOT NULL,
        DisplayOnSiteFlag bit NOT NULL
)

CREATE TABLE Internet.UrlStatus
(
        UrlStatusId int not null identity(1,1) CONSTRAINT PKUrlStatus PRIMARY KEY,
        UrlStatusTypeId int NOT NULL 
         CONSTRAINT Internet_UrlStatusType$defines_status_type_of$Internet_UrlStatus 
                      REFERENCES Internet.UrlStatusType(UrlStatusTypeId),
        UrlId int NOT NULL 
          CONSTRAINT internet_Url$has_status_history_in$internet_UrlStatus 
                      REFERENCES Internet.Url(UrlId),
        ActiveDate        datetime,
        CONSTRAINT AKUrlStatus_statusUrlDate 
                      UNIQUE (UrlStatusTypeId, UrlId, ActiveDate)
)
--set up status types
INSERT  Internet.UrlStatusType (UrlStatusTypeId, Name,
                                   DefaultFlag, DisplayOnSiteFlag)
SELECT 1, 'Unverified',1,0
union
SELECT 2, 'Verified',0,1
union
SELECT 3, 'Unable to locate',0,0
 
GO

----------------------------------------------------------------------------

CREATE TRIGGER Internet.Url$afterInsert
ON Internet.Url
AFTER INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return 
   
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
          --[validation blocks]
           --[modification blocks]

          --add a record to the UrlStatus table to tell it that the new record
          --should start out as the default status
          INSERT INTO Internet.UrlStatus (UrlId, UrlStatusTypeId, ActiveDate)
          SELECT INSERTED.UrlId, UrlStatusType.UrlStatusTypeId, 
                  current_timestamp
          FROM INSERTED
                CROSS JOIN (SELECT UrlStatusTypeId 
                            FROM   UrlStatusType     
                            WHERE  DefaultFlag = 1)  as UrlStatusType
                                             --use cross join with a WHERE clause
                                             --as this is not technically a join 
                                             --between INSERTED and UrlType
   END TRY
   BEGIN CATCH 
                IF @@trancount > 0 
                       ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE dbo.ErrorLog$insert 

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO
----------------------------------------------------------------------------

INSERT  into Internet.Url(Name, Url)
values ('Least read blog on the planet','http://spaces.msn.com/members/drsql')

SELECT * FROM Internet.Url
SELECT * FROM Internet.UrlStatus

GO
----------------------------------------------------------------------------
-- T-SQL After Triggers; Cascading from Child To Parent
----------------------------------------------------------------------------

--start a schema for entertainment related tables
CREATE SCHEMA Entertainment
go
CREATE TABLE Entertainment.GamePlatform
(
    GamePlatformId int CONSTRAINT PKGamePlatform PRIMARY KEY,
    Name  varchar(20) CONSTRAINT AKGamePlatform_Name UNIQUE
)
CREATE TABLE Entertainment.Game
(
    GameId  int CONSTRAINT PKGame PRIMARY KEY,
    Name    varchar(20) CONSTRAINT AKGame_Name UNIQUE
    --more details that are common to all platforms
)

--associative entity with cascade relationships back to Game and GamePlatform
CREATE TABLE Entertainment.GameInstance
(
    GamePlatformId int,
    GameId int,
    DatePurchased smalldatetime,
    CONSTRAINT PKGameInstance PRIMARY KEY (GamePlatformId, GameId),
    CONSTRAINT Entertainment_Game$is_owned_on_platform_by$Entertainment_GameInstance
      FOREIGN KEY (GameId)REFERENCES Entertainment.Game(GameId) ON DELETE CASCADE,
      CONSTRAINT Entertainment_GamePlatform$is_linked_to$Entertainment_GameInstance
      FOREIGN KEY (GamePlatformId) 
           REFERENCES Entertainment.GamePlatform(GamePlatformId)
                ON DELETE CASCADE
)

GO
----------------------------------------------------------------------------

INSERT  into Entertainment.Game (GameId, Name)
VALUES (1,'Super Mario Bros')
INSERT  into Entertainment.Game (GameId, Name)
VALUES (2,'Legend Of Zelda')

INSERT  into Entertainment.GamePlatform(GamePlatformId, Name)
VALUES (1,'Nintendo 64')
INSERT  into Entertainment.GamePlatform(GamePlatformId, Name)
VALUES (2,'Game Cube')

INSERT  into Entertainment.GameInstance(GamePlatformId, GameId, DatePurchased)
VALUES (1,1,'20000204')
INSERT  into Entertainment.GameInstance(GamePlatformId, GameId, DatePurchased)
VALUES (1,2,'20030510')
INSERT  into Entertainment.GameInstance(GamePlatformId, GameId, DatePurchased)
VALUES (2,2,'20030404')

--the full outer joins ensure that all rows are returned from all sets, leaving
--nulls where data is missing
SELECT  GamePlatform.Name as Platform, Game.Name as Game, GameInstance.DatePurchased
FROM    Entertainment.Game as Game
            full outer join Entertainment.GameInstance as GameInstance
                    on Game.GameId = GameInstance.GameId
            full outer join Entertainment.GamePlatform
                    on GamePlatform.GamePlatformId = GameInstance.GamePlatformId
GO
----------------------------------------------------------------------------

CREATE TRIGGER Entertainment.GameInstance$delete
ON Entertainment.GameInstance
FOR delete AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return 
   
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
          --[validation blocks]
          
          --[modification blocks] 
          --delete all Games
          DELETE Game       --where the GameInstance was delete
          WHERE  GameId in (SELECT deleted.GameId
                            FROM   deleted     --and there are no GameInstances left
                            WHERE  not exists (SELECT  *
                                               FROM    GameInstance
                                               WHERE   GameInstance.GameId = 
                                                                    deleted.GameId))
   END TRY
   BEGIN CATCH 
                IF @@trancount > 0 
                       ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE dbo.ErrorLog$insert 

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO

----------------------------------------------------------------------------
DELETE  Entertainment.GamePlatform
WHERE   GamePlatformId = 1
go
SELECT  GamePlatform.Name as platform, Game.Name as Game, GameInstance.DatePurchased
FROM    Entertainment.Game as Game
            FULL OUTER JOIN Entertainment.GameInstance as GameInstance
                    on Game.GameId = GameInstance.GameId
            FULL OUTER JOIN Entertainment.GamePlatform
                    on GamePlatform.GamePlatformId = GameInstance.GamePlatformId
GO

----------------------------------------------------------------------------

SELECT  * 
FROM    Entertainment.Game
GO

----------------------------------------------------------------------------
-- T-SQL After Triggers; Maintaining an Audit Trail
----------------------------------------------------------------------------

CREATE SCHEMA hr
go
CREATE TABLE hr.employee
(
    employee_id char(6) CONSTRAINT PKemployee PRIMARY KEY,
    first_name  varchar(20),
    last_name   varchar(20),
    salary      money
)
CREATE TABLE hr.employee_auditTrail
(
    employee_id          char(6),
    date_changed         datetime not null --default so we don't have to code for it
                CONSTRAINT DfltHr_employee_date_changed DEFAULT (current_timestamp),
    first_name           varchar(20),
    last_name            varchar(20),
    salary               money,
    --the following are the added columns to the original structure of hr.employee
    action               char(6) 
               CONSTRAINT ChkHr_employee_action --we don't log inserts, only changes
                                          CHECK(action in ('delete','update')),
    changed_by_user_name sysname
                CONSTRAINT DfltHr_employee_changed_by_user_name 
                                          DEFAULT (suser_sname()),
    CONSTRAINT PKemployee_auditTrail PRIMARY KEY (employee_id, date_changed)
)

GO
----------------------------------------------------------------------------

CREATE TRIGGER hr.employee$insertAndDeleteAuditTrail
ON hr.employee
AFTER UPDATE, DELETE AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return 
   
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount
   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --since we are only doing update and delete, we just 
          --need to see if there are any rows in
          --inserted to determine what action is being done.
          DECLARE @action char(6) 
          SET @action = case when (SELECT count(*) from inserted) > 0 
                        then 'update' else 'delete' end

          --since the deleted table contains all changes, we just insert all
          --of the rows in the deleted table and we are done.
          INSERT employee_auditTrail (employee_id, first_name, last_name, 
                                     salary, action)
          SELECT employee_id, first_name, last_name, salary, @action
          FROM   deleted

   END TRY
   BEGIN CATCH 
                IF @@trancount > 0 
                       ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE dbo.ErrorLog$insert 

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO
----------------------------------------------------------------------------

INSERT hr.employee (employee_id, first_name, last_name, salary)
VALUES (1, 'joe','schmo',10000) 
GO

----------------------------------------------------------------------------

UPDATE hr.employee
SET salary = salary * 1.10 --ten percent raise!
WHERE employee_id = 1

SELECT *
FROM   hr.employee
GO
----------------------------------------------------------------------------

SELECT *
FROM   hr.employee_auditTrail
GO

----------------------------------------------------------------------------
-- T-SQL Instead Of Triggers; Automatically Maintaining Columns
----------------------------------------------------------------------------

CREATE SCHEMA school
Go
CREATE TABLE school.student
(
      studentId       int identity not null CONSTRAINT PKschool_student PRIMARY KEY,
      studentIdNumber char(8) not null 
            CONSTRAINT AKschool_student_studentIdNumber UNIQUE,
      firstName       varchar(20) not null,
      lastName        varchar(20) not null,
--note that we add these columns to the implementation model, not to the logical 
--model these columns do not actually refer to the student being modeled, they are 
--required simply to help with programming and tracking
      rowCreateDate   datetime not null
            CONSTRAINT dfltSchool_student_rowCreateDate 
                                 DEFAULT (current_timestamp),
      rowCreateUser   sysname not null
            CONSTRAINT dfltSchool_student_rowCreateUser DEFAULT (current_user)
)
GO
----------------------------------------------------------------------------

CREATE TRIGGER school.student$insteadOfInsert
ON school.student
INSTEAD OF INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return 

   SET ROWCOUNT 0 --in case the client has modified the rowcount
   SET NOCOUNT ON --to avoid the rowcount messages

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --<perform action>
          INSERT INTO school.student(studentIdNumber, firstName, lastName, 
                                     rowCreateDate, rowCreateUser)
          SELECT studentIdNumber, firstName, lastName, 
                                        current_timestamp, suser_sname() 
          FROM  inserted   --no matter what the user put in the inserted row
   END TRY         --when the row was created, these values will be inserted
   BEGIN CATCH 
                IF @@trancount > 0 
                       ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE dbo.ErrorLog$insert 

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO

----------------------------------------------------------------------------

INSERT  into school.student(studentIdNumber, firstName, lastName)
VALUES ( '0000001','Leroy', 'Brown' )
GO
----------------------------------------------------------------------------

SELECT * FROM school.student
GO
----------------------------------------------------------------------------

INSERT  school.student(studentIdNumber, firstName, lastName, rowCreateDate, rowCreateUser)
VALUES ( '000002','Green', 'Jeans','99990101','some user' )
GO

----------------------------------------------------------------------------

SELECT * FROM school.student
GO

----------------------------------------------------------------------------
-- T-SQL Instead Of Triggers; Formatting User Input
----------------------------------------------------------------------------

CREATE SCHEMA Functions
Go

--tsql version
CREATE FUNCTION Functions.TitleCase
(
   @inputString varchar(2000)
)
RETURNS varchar(2000) AS
BEGIN 
   -- set the whole string to lower
   SET @inputString = LOWER(@inputstring) 
   -- then use stuff to replace the first character
   SET @inputString = 
   --STUFF in the uppercased character in to the next character,
   --replacing the lowercased letter
   STUFF(@inputString,1,1,UPPER(SUBSTRING(@inputString,1,1)))

   --@i is for the loop counter, initialized to 2
   DECLARE @i int 
   SET @i = 1 

   --loop from the second character to the end of the string
   WHILE @i < LEN(@inputString)
   BEGIN
      --if the character is a space
      IF SUBSTRING(@inputString,@i,1) = ' '
      BEGIN
         --STUFF in the uppercased character into the next character
         SET @inputString = STUFF(@inputString,@i + 
         1,1,UPPER(SUBSTRING(@inputString,@i + 1,1))) 
      END
      --increment the loop counter
      SET @i = @i + 1
   END
   RETURN @inputString
END
go

----------------------------------------------------------------------------

ALTER TRIGGER school.student$insteadOfInsert
ON school.student
INSTEAD OF INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return 

   SET ROWCOUNT 0 --in case the client has modified the rowcount
   SET NOCOUNT ON --to avoid the rowcount messages

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --<perform action>
          INSERT INTO school.student(studentIdNumber, firstName, lastName, 
                                     rowCreateDate, rowCreateUser)
          SELECT studentIdNumber, Functions.titleCase(firstName),              
                                   Functions.TitleCase(lastName),
                                        current_timestamp, suser_sname() 
          FROM  inserted   --no matter what the user put in the inserted row
   END TRY                 --when the row was created, these values will be inserted
   BEGIN CATCH 
                IF @@trancount > 0 
                       ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE dbo.ErrorLog$insert 

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END

GO

INSERT school.student(studentIdNumber, firstName, lastName)
VALUES ( '0000007','CaPtain', 'von kaNGAroo')

SELECT * 
FROM school.student

GO

-----------------------------------------------------------------------------
-- uses the object from the 5297_CLRProjects.zip file.  There is a CLR and 
-- C# version.  
-----------------------------------------------------------------------------

CREATE ASSEMBLY TitleCaseUDF_demo
AUTHORIZATION dbo --this is a user, not a schema
FROM 'C:\ProDatabaseDesignSqlClr\VB\UDFTitleCase\bin\UDFTitleCase.dll'
WITH PERMISSION_SET = SAFE
GO

--Can't use alterw
DROP FUNCTION Functions.TitleCase
GO

CREATE FUNCTION Functions.TitleCase(@inputString nvarchar(4000))
RETURNS nvarchar(4000) WITH EXECUTE AS CALLER
AS
EXTERNAL NAME TitleCaseUDF_demo.[Apress.ProSqlServerDatabaseDesign.UserDefinedFunctions].[TitleCase]
go

--Not In Book, Added
ALTER TRIGGER school.student$insteadOfInsert
ON school.student
INSTEAD OF INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return 

   SET ROWCOUNT 0 --in case the client has modified the rowcount
   SET NOCOUNT ON --to avoid the rowcount messages

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --<perform action>
          INSERT INTO school.student(studentIdNumber, firstName, lastName, 
                                     rowCreateDate, rowCreateUser)
          SELECT studentIdNumber, Functions.titleCase(firstName),              
                                   Functions.TitleCase(lastName),
                                        current_timestamp, suser_sname() 
          FROM  inserted   --no matter what the user put in the inserted row
   END TRY                 --when the row was created, these values will be inserted
   BEGIN CATCH 
                IF @@trancount > 0 
                       ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE dbo.ErrorLog$insert 

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END

GO

--Not In Book
INSERT school.student(studentIdNumber, firstName, lastName)
VALUES ( '0000008','LEONARDO', 'DA VINCI')

SELECT * 
FROM school.student



----------------------------------------------------------------------------
-- T-SQL Instead Of Triggers; Redirecting Invalid Data to an Exception Table
----------------------------------------------------------------------------

CREATE SCHEMA Measurements
go
CREATE TABLE Measurements.WeatherReading
(
    WeatherReadingId int identity 
              CONSTRAINT PKWeatherReading PRIMARY KEY,
    Date            datetime 
CONSTRAINT AKWeatherReading_Date UNIQUE,
    Temperature     float CONSTRAINT chkNews_WeatherReading_Temperature  
                                             CHECK(Temperature between -80 and 120)
)
GO

----------------------------------------------------------------------------

INSERT  into Measurements.WeatherReading (Date, Temperature)
SELECT '20050101 0:00',88.00
UNION ALL
SELECT '20050101 0:01',88.22
UNION ALL
SELECT '20050101 0:02',6000.32
UNION ALL
SELECT '20050101 0:03',89.22
UNION ALL
SELECT '20050101 0:04',90.01
GO

----------------------------------------------------------------------------
CREATE TABLE Measurements.WeatherReading_exception
(
    WeatherReadingId int identity 
                CONSTRAINT PKWeatherReading_exception PRIMARY KEY,
    Date            datetime,
    Temperature     float 
)
GO
----------------------------------------------------------------------------

CREATE TRIGGER Measurements.WeatherReading$InsteadOfInsert
ON Measurements.WeatherReading
INSTEAD OF INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return 
   
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
          --[validation blocks]
           --BAD data
          INSERT Measurements.WeatherReading_exception (Date, Temperature)
          SELECT Date, Temperature
          FROM   inserted
          WHERE  NOT(Temperature between -80 and 120)

          --[modification blocks]
          --<peform action>
           --GOOD data
          INSERT Measurements.WeatherReading (Date, Temperature)
          SELECT Date, Temperature
          FROM   inserted
          WHERE  (Temperature between -80 and 120)
   END TRY
   BEGIN CATCH 
                IF @@trancount > 0 
                       ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE dbo.ErrorLog$insert 

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO

----------------------------------------------------------------------------
INSERT  into Measurements.WeatherReading (Date, Temperature)
SELECT '20050101 0:00',88.00
UNION ALL
SELECT '20050101 0:01',88.22
UNION ALL
SELECT '20050101 0:02',6000.32
UNION ALL
SELECT '20050101 0:03',89.22
UNION ALL
SELECT '20050101 0:04',90.01
go

SELECT *
FROM Measurements.WeatherReading
GO
----------------------------------------------------------------------------

SELECT *
FROM   Measurements.WeatherReading_exception
GO
----------------------------------------------------------------------------
-- T-SQL Instead Of Triggers; Forcing No Action to be Performed on a Table
----------------------------------------------------------------------------

CREATE SCHEMA System
go
CREATE TABLE System.Version
(
    DatabaseVersion varchar(10)
)
INSERT  into System.Version (DatabaseVersion)
VALUES ('1.0.12') 
GO
----------------------------------------------------------------------------

CREATE TRIGGER System.Version$InsteadOfInsertUpdateDelete
ON System.Version
INSTEAD OF INSERT, UPDATE, DELETE AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected 
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to complain if no rows affected
   IF @rowsAffected = 0 return 
   
   --no error handling necessary, just the message.  We just don't do the action
   RAISERROR 
      ('The System.Version table may not be modified in production',
        16,1)
END
GO

----------------------------------------------------------------------------
DELETE system.version

GO
----------------------------------------------------------------------------

ALTER TABLE system.version
    DISABLE TRIGGER version$InsteadOfInsertUpdateDelete
GO
----------------------------------------------------------------------------

