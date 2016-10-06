----------------------------------------------------------------
--Query Optimization Basics
----------------------------------------------------------------

USE AdventureWorks
go
SELECT  productModel.name as productModel,
        product.name as productName
FROM    production.product as product
        join production.productModel as productModel
            on productModel.productModelId = product.productModelId
WHERE   product.name like '%glove%'
GO

----------------------------------------------------------------
-- Transaction Syntax
----------------------------------------------------------------

BEGIN TRANSACTION one
ROLLBACK TRANSACTION one

GO
----------------------------------------------------------------


BEGIN TRANSACTION one
BEGIN TRANSACTION two
ROLLBACK TRANSACTION two

GO
----------------------------------------------------------------

--Not in book
ROLLBACK TRANSACTION
GO
----------------------------------------------------------------

select  recovery_model_desc 
from    sys.databases 
where   name = 'AdventureWorks'
GO
----------------------------------------------------------------

USE Master
GO

ALTER DATABASE AdventureWorks
  SET RECOVERY FULL
GO
----------------------------------------------------------------

EXEC sp_addumpdevice 'disk', 'TestAdventureWorks', 'C:\Temp\AdventureWorks.bak'
EXEC sp_addumpdevice 'disk', 
                       'TestAdventureWorksLog', 'C:\Temp\AdventureWorksLog.bak'
GO
----------------------------------------------------------------

BACKUP DATABASE AdventureWorks TO TestAdventureWorks
GO
----------------------------------------------------------------

USE AdventureWorks
GO
SELECT count(*) 
FROM   SALES.StoreContact

BEGIN TRANSACTION Test WITH MARK 'Test'
DELETE Sales.StoreContact
COMMIT TRANSACTION
GO
----------------------------------------------------------------

BACKUP LOG AdventureWorks  to TestAdventureWorksLog
GO
----------------------------------------------------------------

USE Master
GO
RESTORE DATABASE AdventureWorks FROM TestAdventureWorks WITH REPLACE, NORECOVERY

RESTORE LOG AdventureWorks FROM TestAdventureWorksLog WITH STOPBEFOREMARK = 'Test'
GO

----------------------------------------------------------------
-- Nesting transaction
----------------------------------------------------------------

SELECT @@TRANCOUNT AS zeroDeep
BEGIN TRANSACTION
SELECT @@TRANCOUNT AS oneDeep

GO
----------------------------------------------------------------

BEGIN TRANSACTION
SELECT @@TRANCOUNT AS twoDeep
COMMIT TRANSACTION --commits very last transaction started with BEGIN TRANSACTION

SELECT @@TRANCOUNT AS oneDeep

GO
----------------------------------------------------------------

COMMIT TRANSACTION
SELECT @@TRANCOUNT AS zeroDeep

GO
----------------------------------------------------------------


BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
select @@trancount as InTran
ROLLBACK TRANSACTION
select @@trancount as OutTran

GO
----------------------------------------------------------------

COMMIT TRANSACTION
GO
----------------------------------------------------------------

----------------------------------------------------------------
-- Savepoints
----------------------------------------------------------------

USE tempDb
GO
----------------------------------------------------------------

CREATE SCHEMA arts
CREATE TABLE arts.performer
(
    performerId int identity,
    name varchar(100)
)
GO
BEGIN TRANSACTION
INSERT INTO arts.performer(name) VALUES ('Elvis Costello')

SAVE TRANSACTION savePoint

INSERT INTO arts.performer(name) VALUES ('Air Supply')

ROLLBACK TRANSACTION savePoint

COMMIT TRANSACTION

SELECT * 
FROM arts.performer

GO
----------------------------------------------------------------
-- Stored Procedures
----------------------------------------------------------------

CREATE PROCEDURE tranTest
AS
BEGIN
  SELECT @@TRANCOUNT AS trancount

  BEGIN TRANSACTION
  ROLLBACK TRANSACTION
END
GO
----------------------------------------------------------------

BEGIN TRANSACTION
EXECUTE tranTest
COMMIT TRANSACTION
GO
----------------------------------------------------------------

ALTER PROCEDURE tranTest
AS
BEGIN
  DECLARE @savepoint varchar(32)
  --gives us a unique savepoint name, which can only be 32 characters
  SET @savepoint = cast(object_name(@@procid) AS varchar(29)) + 
                   cast(@@nestlevel AS varchar(3))
 
  BEGIN TRANSACTION
  SAVE TRANSACTION @savepoint 
    --do something here
  ROLLBACK TRANSACTION @savepoint
  COMMIT TRANSACTION
END
GO
----------------------------------------------------------------

--Not in text

BEGIN TRANSACTION
EXECUTE tranTest
COMMIT TRANSACTION
GO
----------------------------------------------------------------

ALTER PROCEDURE tranTest
AS
BEGIN
  DECLARE @savepoint varchar(30)
  --gives us a unique savepoint name
  SET @savepoint = cast(object_name(@@procid) AS varchar(27)) + 
                   cast(@@nestlevel AS varchar(3))
 
  BEGIN TRY
    BEGIN TRANSACTION
    SAVE TRANSACTION @savepoint 

    --do something here
    RAISERROR ('ouch',16,1)

    COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
    --if the transaction has not been rolled back elsewhere (like a trigger)
    --back out gracefully
    IF @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRANSACTION @savepoint
         COMMIT TRANSACTION
      END

    DECLARE @ERRORmessage varchar(2000)
    SET @ERRORmessage = ERROR_MESSAGE()
    RAISERROR (@ERRORmessage,16,1)	
    RETURN -100
  END CATCH
END
GO
----------------------------------------------------------------

CREATE SCHEMA menu
CREATE TABLE menu.foodItem
(
    foodItemId int not null identity(1,1)
        CONSTRAINT PKmenu_foodItem PRIMARY KEY,
    name varchar(30) not null
        CONSTRAINT AKmenu_foodItem_name UNIQUE,
    description varchar(60) not null,
        CONSTRAINT CHKmenu_foodItem_name CHECK (name <> ''),
        CONSTRAINT CHKmenu_foodItem_description CHECK (description <> '')
)
GO
----------------------------------------------------------------

CREATE PROCEDURE menu.foodItem$insert
(
    @name   varchar(30),
    @description varchar(60),
    @newFoodItemId int = null output --we will send back the new id here
)
AS
BEGIN
  SET NOCOUNT ON
  DECLARE @savepoint varchar(30)

  --gives us a unique savepoint name
  SET @savepoint = cast(object_name(@@procid) AS varchar(27)) + 
                   cast(@@nestlevel AS varchar(3))
 
  BEGIN TRY
    BEGIN TRANSACTION
    SAVE TRANSACTION @savepoint 

    INSERT INTO menu.foodItem(name, description)
    VALUES (@name, @description)

    set @newFoodItemId = scope_identity() --if you use an instead of trigger
                                          --you will have to use name to do the 
                                          --identity "grab"
    COMMIT TRANSACTION
  END TRY
  BEGIN CATCH
    --if the transaction has not been rolled back elsewhere (like a trigger)
    --back out gracefully
    IF @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRANSACTION @savepoint
         COMMIT TRANSACTION
      END

    --uncomment to use the error log procedure created back in chapter 6
    --EXECUTE dbo.errorLog$insert 

    DECLARE @ERROR_MESSAGE varchar(8000)
    SET @ERROR_MESSAGE = ERROR_MESSAGE()
    RAISERROR (@ERROR_MESSAGE,16,1)
    RETURN -100
  END CATCH
END
GO
----------------------------------------------------------------

DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Burger', 
                                        @description = 'Mmmm Burger', 
                                        @newFoodItemId = @foodItemId output
SELECT  @retval as returnValue
IF @retval >= 0
    SELECT  foodItemId, name, description 
    FROM    menu.foodItem
    where   foodItemId = @foodItemId
GO
----------------------------------------------------------------

DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger', 
                                        @description = '', 
                                        @newFoodItemId = @foodItemId output
SELECT  @retval as returnValue
IF @retval >= 0
    SELECT  foodItemId, name, description 
    FROM    menu.foodItem
    where   foodItemId = @foodItemId
GO
----------------------------------------------------------------

----------------------------------------------------------------
-- Isolation Level
----------------------------------------------------------------

CREATE TABLE dbo.testIsolationLevel
(
   testIsolationLevelId int identity(1,1)
                CONSTRAINT PKtestIsolationLevel PRIMARY KEY,
   value varchar(10)
)

INSERT dbo.testIsolationLevel(value)
VALUES ('Value1')
INSERT dbo.testIsolationLevel(value)
VALUES ('Value2')

GO
----------------------------------------------------------------

--READ COMMITTED

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL READ COMMITTED --this is the default
BEGIN TRANSACTION
INSERT INTO dbo.testIsolationLevel(value)
VALUES('Value3')

GO
----------------------------------------------------------------
/* --do this in another connection to SQL Server
--CONNECTION B
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT * 
FROM dbo.testIsolationLevel
*/
GO
----------------------------------------------------------------

--CONNECTION A

COMMIT TRANSACTION

GO
----------------------------------------------------------------


--READ COMMITTED

--CONNECTION A

SET TRANSACTION ISOLATION LEVEL READ COMMITTED

BEGIN TRANSACTION
SELECT * FROM dbo.testIsolationLevel

GO
----------------------------------------------------------------
/*
--CONNECTION B

DELETE FROM dbo.testIsolationLevel 
WHERE testIsolationLevelId = 1

*/

GO
----------------------------------------------------------------

--CONNECTION A
SELECT * 
FROM dbo.testIsolationLevel
COMMIT TRANSACTION

GO
----------------------------------------------------------------

--REPEATABLE READ

--CONNECTION A

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ

BEGIN TRANSACTION
SELECT * FROM dbo.testIsolationLevel

GO
----------------------------------------------------------------

/*
--CONNECTION B

INSERT INTO dbo.testIsolationLevel(value)
VALUES ('Value4')
*/

GO
----------------------------------------------------------------
/*
--CONNECTION B

DELETE FROM dbo.testIsolationLevel 
WHERE value = 'Value3'
*/
GO
----------------------------------------------------------------
--CONNECTION A

SELECT * FROM dbo.testIsolationLevel
COMMIT TRANSACTION

GO
----------------------------------------------------------------
--SNAPSHOT

ALTER DATABASE tempDb
SET ALLOW_SNAPSHOT_ISOLATION ON
GO
----------------------------------------------------------------

--CONNECTION A

SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRANSACTION
SELECT * from dbo.testIsolationLevel

GO
----------------------------------------------------------------

/*
--CONNECTION B

SET TRANSACTION ISOLATION LEVEL READ COMMITTED
INSERT INTO dbo.testIsolationLevel(value)
VALUES ('Value5')
*/

GO
----------------------------------------------------------------
/*
--CONNECTION B

DELETE FROM dbo.testIsolationLevel
WHERE  value = 'Value4'
*/

GO
----------------------------------------------------------------

--CONNECTION A

UPDATE dbo.testIsolationLevel
SET    value = 'Value2-mod'
WHERE  testIsolationLevelId = 2


GO
----------------------------------------------------------------

--CONNECTION A
COMMIT TRANSACTION
SELECT * from dbo.testIsolationLevel
GO
----------------------------------------------------------------

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRANSACTION

--touch the data
SELECT * from dbo.testIsolationLevel 

GO
----------------------------------------------------------------
/*
--CONNECTION B
SET TRANSACTION ISOLATION LEVEL SNAPSHOT

update dbo.testIsolationLevel
set value = 'Value5-mod2'
where testIsolationLevelId = 6 --might be different in yours
*/
GO
----------------------------------------------------------------

update dbo.testIsolationLevel
set value = 'Value5-mod'
where testIsolationLevelId = 6 --might be different in yours

Msg 3960, Level 16, State 2, Line 1
Snapshot isolation transaction aborted due to update conflict. You cannot use snapshot isolation to access table 'dbo.testIsolationLevel' directly or indirectly in database 'tempdb' to update, delete, or insert the row that has been modified or deleted by another transaction. Retry the transaction or change the isolation level for the update/delete statement.


----------------------------------------------------------------
--Application locks
----------------------------------------------------------------

--Connection A
BEGIN TRANSACTION
   DECLARE @result int
   EXEC @result = sp_getapplock @Resource = 'invoiceId=1', @LockMode = 'Exclusive'
   SELECT @result

GO
----------------------------------------------------------------
/*
--Connection B
BEGIN TRANSACTION
   DECLARE @result int
   EXEC @result = sp_getapplock @Resource = 'invoiceId=1', @LockMode = 'Shared'
   PRINT @result 
*/

GO
----------------------------------------------------------------
/*
--Connection B
BEGIN TRANSACTION
SELECT  APPLOCK_TEST('public','invoiceId=1','Exclusive','Transaction') as CanTakeLock
ROLLBACK TRANSACTION
*/

GO
----------------------------------------------------------------
--Not in text
COMMIT TRANSACTION

GO
----------------------------------------------------------------

----------------------------------------------------------------
--Optimistic locks
----------------------------------------------------------------
CREATE SCHEMA hr
CREATE TABLE hr.person  
(
     personId int IDENTITY(1,1) CONSTRAINT PKperson primary key,
     firstName varchar(60) NOT NULL,
     middleName varchar(60) NOT NULL,
     lastName varchar(60) NOT NULL,
     dateOfBirth datetime NOT NULL,
     rowLastModifyDate datetime NOT NULL 
         CONSTRAINT DFLTperson_rowLastModifyDate default getdate(),
     rowModifiedByUserIdentifier nvarchar(128) NOT NULL 
         CONSTRAINT DFLTperson_rowModifiedByUserIdentifier default suser_sname()
     
)
--Note the two columns for our optimistic lock, named rowLastModifyDate and 

GO
----------------------------------------------------------------

CREATE TRIGGER hr.person$InsteadOfUpdate
ON hr.person
INSTEAD OF UPDATE AS
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
	   --remember to update ALL columns when building instead of triggers
          UPDATE hr.person
          SET    firstName = inserted.firstName,
                 middleName = inserted.middleName,
                 lastName = inserted.lastName,
                 dateOfBirth = inserted.dateOfBirth,
                 rowLastModifyDate = default, --tells SQL Server to set the value to 
                 rowModifiedByUserIdentifier = default --the value in the default 
          FROM   hr.person                              --contraint
                     JOIN inserted
                             on hr.person.personId = inserted.personId          
   END TRY
   BEGIN CATCH 
		IF @@trancount > 0 
               	ROLLBACK TRANSACTION

              --EXECUTE dbo.errorLog$insert 

              DECLARE @ERROR_MESSAGE varchar(8000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO
----------------------------------------------------------------

INSERT INTO hr.person (firstName, middleName, lastName, dateOfBirth)
VALUES ('Leroy','T','Brown','19391212')

SELECT *
FROM   hr.person

GO
----------------------------------------------------------------

UPDATE hr.person
SET     middleName = 'Tee'
WHERE   personId = 1

SELECT rowLastModifyDate
FROM   hr.person
GO
----------------------------------------------------------------

ALTER TABLE hr.person
  ADD rowversion rowversion
GO

SELECT personId, rowversion 
FROM   hr.person

GO
----------------------------------------------------------------

----------------------------------------------------------------
--Coding for Row-Level Optimistic Locking
----------------------------------------------------------------

UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1  --include the key
  and   firstName = 'Leroy'
  and   middleName = 'Tee'
  and   lastName = 'Brown'
  and   dateOfBirth = '19391212'

GO
----------------------------------------------------------------

UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1  --include the key
  and   rowLastModifyDate = '<get the date>'

GO
----------------------------------------------------------------

UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1  
  and   rowversion = get the row value
GO
----------------------------------------------------------------

DELETE FROM hr.person
WHERE   rowversion = get the row value
GO
----------------------------------------------------------------


----------------------------------------------------------------
--Logical Unit of Work
----------------------------------------------------------------

CREATE SCHEMA invoicing
go
--leaving off who invoice is for
CREATE TABLE invoicing.invoice
(
     invoiceId int IDENTITY(1,1),
     number varchar(20) NOT NULL,
     objectVersion rowversion not null,
     constraint PKinvoicing_invoice primary key (invoiceId)  
)
--also forgetting what product that the line item is for
CREATE TABLE invoicing.invoiceLineItem
(
     invoiceLineItemId int NOT NULL,
     invoiceId int NULL,
     itemcCount int NOT NULL,
     cost int NOT NULL,
      constraint PKinvoicing_invoiceLineItem primary key (invoiceLineItemId),
      constraint FKinvoicing_invoiceLineItem$references$invoicing_invoice
            foreign key (invoiceId) references invoicing.invoice(invoiceId)
)

GO
----------------------------------------------------------------

CREATE PROCEDURE invoiceLineItem$del
(
    @invoiceId int, --we pass this because the client should have it 
                    --with the invoiceLineItem row
    @invoiceLineItemId int,
    @objectVersion rowversion
) as
 BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

	  UPDATE  invoice
        SET     number = number
        WHERE   invoiceId = @invoiceId
          And   objectVersion = @objectVersion

        DELETE  invoiceLineItem
        FROM    invoiceLineItem
        WHERE   invoiceLineItemId = @invoiceLineItemId 

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH 
              IF @@trancount > 0
                   ROLLBACK TRANSACTION

              --or this will get rolled back
              --EXECUTE dbo.errorLog$insert 

              DECLARE @ERROR_MESSAGE varchar(8000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
 END    


GO
----------------------------------------------------------------
