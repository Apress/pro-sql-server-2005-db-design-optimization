-------------------------------------------------------------------
-- Ad hoc SQL - flexibility and control
-------------------------------------------------------------------

CREATE DATABASE architectureChapter
GO
Use architectureChapter
go
-------------------------------------------------------------------

CREATE SCHEMA sales
GO
CREATE TABLE sales.contact
(
    contactId   int CONSTRAINT PKsales_contact PRIMARY KEY,
    firstName   varchar(30),
    lastName    varchar(30),
    companyName varchar(100),
    contactNotes  varchar(max),
    personalNotes varchar(max),
    CONSTRAINT AKsales_contact UNIQUE (firstName, lastName, companyName)
)

GO
-------------------------------------------------------------------

SELECT  contactId, firstName, lastName, companyName, 
        right(contactNotes,500) as notesEnd
FROM    sales.contact

GO
-------------------------------------------------------------------
SELECT contactId, firstName, lastName, companyName
FROM sales.contact

GO
-------------------------------------------------------------------

CREATE TABLE sales.purchase
(
    purchaseId int CONSTRAINT PKsales_purchase PRIMARY KEY,
    amount      numeric(10,2),
    purchaseDate datetime,
    contactId   int 
        CONSTRAINT FKsales_contact$hasPurchasesIn$sales_purchase
            REFERENCES sales.contact(contactId)
)
GO
-------------------------------------------------------------------

SELECT  contact.contactId, contact.firstName, contact.lastName,
                sales.yearToDateSales, sales.lastSaleDate
FROM   sales.contact as contact
          LEFT OUTER JOIN 
             (SELECT contactId, 
                     SUM(amount) AS yearToDateSales,
                     MAX(purchaseDate) AS lastSaleDate 
              FROM   sales.purchase
              WHERE  purchaseDate >= --the first day of the current year
                               cast(datepart(year,getdate()) as char(4)) + '0101'
              GROUP  by contactId) AS sales
              ON contact.contactId = sales.contactId
WHERE   contact.lastName like 'Johns%'

GO
-------------------------------------------------------------------

SELECT  contact.contactId, contact.firstName, contact.lastName
                --,sales.yearToDateSales, sales.lastSaleDate
FROM   sales.contact as contact
--          LEFT OUTER JOIN 
--             (SELECT contactId, 
--                     SUM(amount) AS yearToDateSales,
--                     MAX(purchaseDate) AS lastSaleDate 
--              FROM   sales.purchase
--             WHERE  purchaseDate >= --the first day of the current year
--                               cast(datepart(year,getdate()) as char(4)) + '0101'
--              GROUP  by contactId) AS sales
--              ON contact.contactId = sales.contactId
WHERE   contact.lastName like 'Johns%'


GO
-------------------------------------------------------------------

--note, no rows will be updated since no data has been added
UPDATE sales.contact
SET 	firstName = 'First Name',
       lastName = 'Last Name',
       companyName = 'Company Name',
       contactNotes = 'Notes about the contact',
       personalNotes = 'Notes about the person'
WHERE contactId = 1

GO
-------------------------------------------------------------------

UPDATE sales.contact
SET 	firstName = 'First Name'
WHERE contactId = 1
GO
-------------------------------------------------------------------

SELECT firstName, lastName, companyName
FROM   sales.contact
WHERE  firstName like 'firstNameValue%'
  AND  lastName like 'lastNamevalue%'

GO
-------------------------------------------------------------------

SELECT firstName, lastName, companyName
FROM   sales.contact
WHERE  lastName like 'lastNamevalue%'

GO
-------------------------------------------------------------------

-------------------------------------------------------------------
-- Ad hoc SQL - Performance
-------------------------------------------------------------------

ALTER DATABASE AdventureWorks
    SET PARAMETERIZATION SIMPLE
Go
SELECT address.AddressLine1, address.AddressLine2,
        address.City, state.StateProvinceCode, address.PostalCode
FROM   Person.Address AS address
         join Person.StateProvince as state
                on address.stateProvinceId = state.stateProvinceId
WHERE  address.AddressLine1 = '1, rue Pierre-Demoulin'
GO

SELECT address.AddressLine1, address.AddressLine2,
        address.City, state.StateProvinceCode, address.PostalCode
FROM   Person.Address AS address
         join Person.StateProvince AS state
                on address.stateProvinceId = state.stateProvinceId
WHERE  address.AddressLine1 = '1, rue Pierre-Demoulin'
GO
-------------------------------------------------------------------

SELECT address.AddressLine1, address.AddressLine2
FROM   Person.Address AS address
WHERE  address.AddressLine1 = '1, rue Pierre-Demoulin'
GO
-------------------------------------------------------------------

SELECT address.AddressLine1, address.AddressLine2,
        address.City, state.StateProvinceCode, address.PostalCode
FROM   Person.Address AS address
         join Person.StateProvince as state
                on address.stateProvinceId = state.stateProvinceId
WHERE  address.AddressLine1 = '1, rue Pierre-Demoulin'
GO
-------------------------------------------------------------------

ALTER DATABASE AdventureWorks
    SET PARAMETERIZATION FORCED
GO

SET SHOWPLAN_TEXT ON
go

SELECT address.AddressLine1, address.AddressLine2,
        address.City, state.StateProvinceCode, address.PostalCode
FROM   Person.Address AS address
         join Person.StateProvince as state
                on address.stateProvinceId = state.stateProvinceId
WHERE  address.AddressLine1 like '1, rue Pierre-Demoulin'
GO
-------------------------------------------------------------------

SELECT address.AddressLine1, address.AddressLine2,
        address.City, state.StateProvinceCode, address.PostalCode
FROM   Person.Address AS address
         join Person.StateProvince as state
                on address.stateProvinceId = state.stateProvinceId
WHERE  address.AddressLine1 like '1, rue Pierre-Demoulin'
GO
-------------------------------------------------------------------


-------------------------------------------------------------------
-- Stored Procedures
-------------------------------------------------------------------

CREATE PROCEDURE person.address$select
(
    @addressLine1 nvarchar(120) = '%',
    @city         nvarchar(60) = '%',
    @state        nchar(3) = '___', --special because it is a char column
    @postalCode   nvarchar(8) = '%'
) AS
--simple procedure to execute a single query
SELECT address.AddressLine1, address.AddressLine2,
        address.City, state.StateProvinceCode, address.PostalCode
FROM   Person.Address as address
         join Person.StateProvince as state
                on address.stateProvinceId = state.stateProvinceId
WHERE  address.AddressLine1 like @addressLine1
  AND  address.City like @city
  AND  state.StateProvinceCode like @state
  AND  address.PostalCode like @postalCode   
GO
-------------------------------------------------------------------

person.address$select @city = 'london'
GO

person.address$select @postalCode = '3%', @state = 'TN'
GO
-------------------------------------------------------------------

-------------------------------------------------------------------
-- Stored Procedures, Dynamic Procedures
-------------------------------------------------------------------

ALTER PROCEDURE person.address$select
(
    @addressLine1 nvarchar(120) = '%',
    @city         nvarchar(60) = '%',
    @state        nchar(3) = '___',
    @postalCode   nvarchar(50) = '%'
) AS
BEGIN
    DECLARE @query varchar(max)
    SET @query = 
               'SELECT address.AddressLine1, address.AddressLine2,
                        address.City, state.StateProvinceCode, address.PostalCode
                FROM   Person.Address as address
                        join Person.StateProvince as state
                                on address.stateProvinceId = state.stateProvinceId
                WHERE   address.City like ''' + @city + '''
                   AND  state.StateProvinceCode like ''' + @state + '''
                   AND  address.PostalCode like ''' + @postalCode + '''
                   --this param is last because it is largest to make the example 
                   --easier as this column is very large
                   AND  address.AddressLine1 like ''' + @addressLine1 + ''''

    SELECT @query --just for testing purposes
    EXECUTE (@query)
 END

GO
-------------------------------------------------------------------
EXECUTE person.address$select @city = 'london'
GO
EXECUTE person.address$select @addressLine1 = '~''select name from sysusers--'
GO
-------------------------------------------------------------------

ALTER PROCEDURE person.address$select
(
    @addressLine1 nvarchar(120) = '%',
    @city         nvarchar(60) = '%',
    @state        nchar(3) = '___',
    @postalCode   nvarchar(50) = '%'
) AS
BEGIN
    DECLARE @query varchar(max)
    SET @query = 
               'SELECT address.AddressLine1, address.AddressLine2,
                        address.City, state.StateProvinceCode, address.PostalCode
                FROM   Person.Address as address
                        join Person.StateProvince as state
                                on address.stateProvinceId = state.stateProvinceId
                WHERE   1=1'
    IF @city <> '%'
          SET @query = @query + ' AND address.City like ' + quotename(@city,'''') 
    IF @state <> '___'
            SET @query = @query + ' AND state.StateProvinceCode like ' + 
                                                              quotename(@state,'''') 
    IF @postalCode <> '%'
            SET @query = @query + ' AND address.City like ' + quotename(@city,'''') 
    IF @addressLine1 <> '%'
            SET @query = @query + ' AND address.addressLine1 like ' + 
                                            quotename(@addressLine1,'''') 
    SELECT  @query 
    EXECUTE (@query)
 END

GO
-------------------------------------------------------------------

-------------------------------------------------------------------
-- Security
-------------------------------------------------------------------
USE architectureChapter
GO

CREATE LOGIN fred with password = 'freddy'
CREATE USER  fred from login fred
GO
-------------------------------------------------------------------

CREATE PROCEDURE testChaining
AS
EXECUTE ('select * from sales.contact')
GO
GRANT EXECUTE ON testChaining TO fred
GO
-------------------------------------------------------------------

EXECUTE AS user = 'fred'
EXECUTE testChaining
REVERT
GO
-------------------------------------------------------------------

ALTER PROCEDURE testChaining
WITH EXECUTE AS SELF 
AS
EXECUTE ('select * from person.contact')
GO
-------------------------------------------------------------------

EXECUTE AS user = 'fred'
EXECUTE testChaining
REVERT

GO
-------------------------------------------------------------------

CREATE PROCEDURE dbo.doAnything
(
    @query nvarchar(4000)
) 
WITH EXECUTE AS OWNER 
AS
EXECUTE (@query)
GO
-------------------------------------------------------------------

CREATE PROCEDURE sales.contact$update
(
    @contactId   int,
    @firstName   varchar(30),
    @lastName    varchar(30),
    @companyName varchar(100),
    @contactNotes  varchar(max),
    @personalNotes varchar(max)
) 
AS
BEGIN TRY
        UPDATE  sales.contact
        SET     firstName = @firstName,
                lastName = @lastName,
                companyName = @companyName,
                contactNotes = @contactNotes,
                personalNotes = @personalNotes
         WHERE  contactId = @contactId
 END TRY
BEGIN CATCH
        EXECUTE dbo.errorLog$insert --from back in chapter 6
        RAISERROR ('Error creating new sales.contact',16,1)
END CATCH
GO
-------------------------------------------------------------------

CREATE TRIGGER sales.contact$insteadOfUpdate
ON sales.contact
INSTEAD OF UPDATE
AS
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
          --<peform action>
          UPDATE contact
          SET    firstName = inserted.firstName,
                 lastName = inserted.lastName,
                 companyName = inserted.companyName
		  FROM   sales.contact as contact
		           JOIN inserted
                        on inserted.contactId = contact.contactId

          UPDATE contact
          SET    personalNotes = inserted.personalNotes
		  FROM   sales.contact as contact
		           JOIN inserted
                        on inserted.contactId = contact.contactId
          --this correlated subquery checks for rows that have changed
          WHERE  EXISTS (SELECT *
                         FROM   deleted
                         WHERE  deleted.contactId = inserted.contactId
                           AND  deleted.personalNotes <> inserted.personalNotes
                                or (deleted.personalNotes is null and 
                                                 inserted.personalNotes is not null)
                                or (deleted.personalNotes is not null and 
                                                 inserted.personalNotes is null))

          UPDATE contact
          SET    contactNotes = inserted.contactNotes
		  FROM   sales.contact as contact
		           JOIN inserted
                        on inserted.contactId = contact.contactId
          --this correlated subquery checks for rows that have changed
          WHERE  EXISTS (SELECT *
                         FROM   deleted
                         WHERE  deleted.contactId = inserted.contactId
                           AND  deleted.contactNotes <> inserted.contactNotes
                                or (deleted.contactNotes is null and 
                                                  inserted.contactNotes is not null)
                                or (deleted.contactNotes is not null and 
                                                  inserted.contactNotes is null))
   END TRY
   BEGIN CATCH 
		IF @@trancount > 0 
               	ROLLBACK TRANSACTION

              EXECUTE dbo.errorLog$insert 

              DECLARE @ERROR_MESSAGE varchar(8000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END

GO
-------------------------------------------------------------------
