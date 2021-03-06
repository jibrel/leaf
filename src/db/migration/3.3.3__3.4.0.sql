USE [LeafDB]
GO

/*
 * Update version.
 */
IF EXISTS (SELECT 1 FROM [ref].[Version])
    UPDATE ref.Version
    SET [Version] = '3.4.0'
ELSE 
    INSERT INTO ref.[Version] (Lock, Version)
    SELECT 'X', '3.4.0'

/*
 * app.GlobalPanelFilter
 */
IF OBJECT_ID('app.GlobalPanelFilter', 'U') IS NOT NULL 
	DROP TABLE [app].[GlobalPanelFilter];
GO

CREATE TABLE [app].[GlobalPanelFilter](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[IsInclusion] bit NOT NULL,
	[SessionType] [int] NULL,
	[SqlSetId] [int] NOT NULL,
	[SqlSetWhere] [nvarchar](1000) NULL,
	Created datetime NOT NULL,
	CreatedBy nvarchar(200) NOT NULL,
	Updated datetime NOT NULL,
	UpdatedBy nvarchar(200) NOT NULL
 CONSTRAINT [PK_GlobalPanelFilter] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

/*
 * ref.SessionType
 */
IF OBJECT_ID('ref.SessionType', 'U') IS NOT NULL 
	DROP TABLE [ref].[SessionType];
GO

CREATE TABLE [ref].[SessionType](
	[Id] [int] NOT NULL,
	[Variant] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_SessionType] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
INSERT [ref].[SessionType] ([Id], [Variant]) VALUES (1, N'QI')
GO
INSERT [ref].[SessionType] ([Id], [Variant]) VALUES (2, N'Research')
GO
ALTER TABLE [app].[GlobalPanelFilter]  WITH CHECK ADD  CONSTRAINT [FK_GlobalPanelFilter_SessionType] FOREIGN KEY([SessionType])
REFERENCES [ref].[SessionType] ([Id])
GO
ALTER TABLE [app].[GlobalPanelFilter] CHECK CONSTRAINT [FK_GlobalPanelFilter_SessionType]
GO
ALTER TABLE [app].[GlobalPanelFilter]  WITH CHECK ADD  CONSTRAINT [FK_GlobalPanelFilter_ConceptSqlSetId] FOREIGN KEY([SqlSetId])
REFERENCES [app].[ConceptSqlSet] ([Id])
GO
ALTER TABLE [app].[GlobalPanelFilter] CHECK CONSTRAINT [FK_GlobalPanelFilter_ConceptSqlSetId]
GO

/*
 * auth.SessionType
 */
IF TYPE_ID('auth.SessionType') IS NOT NULL
	DROP TYPE auth.SessionType;
GO

CREATE TYPE [auth].[SessionType] FROM [int] NOT NULL
GO

/*
 * Update Panel Filter columns
 */

-- Created
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'Created' AND Object_ID = Object_ID(N'app.PanelFilter'))
	BEGIN
		ALTER TABLE app.PanelFilter
		ADD Created DATETIME NOT NULL CONSTRAINT [DF_PanelFilter_Created] DEFAULT GETDATE()
	END

-- CreatedBy
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'CreatedBy' AND Object_ID = Object_ID(N'app.PanelFilter'))
	BEGIN
		ALTER TABLE app.PanelFilter
		ADD CreatedBy NVARCHAR(1000) NOT NULL CONSTRAINT TEMP_DEF1 DEFAULT 'leaf_3.4.0_migration'
		
		ALTER TABLE app.PanelFilter DROP CONSTRAINT TEMP_DEF1
	END

-- Updated
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'Updated' AND Object_ID = Object_ID(N'app.PanelFilter'))
	BEGIN
		ALTER TABLE app.PanelFilter
		ADD Updated DATETIME NOT NULL CONSTRAINT [DF_PanelFilter_Updated] DEFAULT GETDATE()
	END

-- UpdatedBy
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'UpdatedBy' AND Object_ID = Object_ID(N'app.PanelFilter'))
	BEGIN
		ALTER TABLE app.PanelFilter
		ADD UpdatedBy NVARCHAR(1000) NOT NULL CONSTRAINT TEMP_DEF1 DEFAULT 'leaf_3.4.0_migration'

		ALTER TABLE app.PanelFilter DROP CONSTRAINT TEMP_DEF1
	END

-- Constraints
IF OBJECT_ID('app.DF_PanelFilter_LastChanged') IS NOT NULL 
    ALTER TABLE app.PanelFilter DROP CONSTRAINT DF_PanelFilter_LastChanged

-- LastChanged
IF EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'LastChanged' AND Object_ID = Object_ID(N'app.PanelFilter'))
	BEGIN
		ALTER TABLE app.PanelFilter
		DROP COLUMN LastChanged
	END

-- ChangedBy
IF EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'ChangedBy' AND Object_ID = Object_ID(N'app.PanelFilter'))
	BEGIN
		ALTER TABLE app.PanelFilter
		DROP COLUMN ChangedBy
	END
GO

/*
 * [adm].[sp_CreatePanelFilter].
 */
IF OBJECT_ID('adm.sp_CreatePanelFilter', 'P') IS NOT NULL
    DROP PROCEDURE [adm].[sp_CreatePanelFilter];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/8/26
-- Description: Create a new app.PanelFilter.
-- =======================================
CREATE PROCEDURE [adm].[sp_CreatePanelFilter]
    @conceptId uniqueidentifier,
    @isInclusion bit,
	@uiDisplayText nvarchar(1000),
	@uiDisplayDescription nvarchar(4000),
	@user auth.[User]
AS
BEGIN
    SET NOCOUNT ON

	IF NOT EXISTS (SELECT 1 FROM app.Concept WHERE Id = @conceptId)
        THROW 70400, N'PanelFilter.Concept does not exist.', 1;

    IF (app.fn_NullOrWhitespace(@uiDisplayText) = 1)
        THROW 70400, N'PanelFilter.UiDisplayText is required.', 1;

	IF (app.fn_NullOrWhitespace(@uiDisplayDescription) = 1)
        THROW 70400, N'PanelFilter.UiDisplayDescription is required.', 1;

    BEGIN TRAN;
    BEGIN TRY

        IF EXISTS (SELECT 1 FROM app.PanelFilter WHERE ConceptId = @conceptId AND IsInclusion = @isInclusion)
            THROW 70409, N'PanelFilter already exists with that ConceptId and Inclusion setting.', 1;

        INSERT INTO app.PanelFilter (ConceptId, IsInclusion, UiDisplayText, UiDisplayDescription, Created, CreatedBy, Updated, UpdatedBy)
        OUTPUT 
			inserted.Id
		  , inserted.ConceptId
		  , inserted.IsInclusion
		  , inserted.UiDisplayText
		  , inserted.UiDisplayDescription
        VALUES (@conceptId, @isInclusion, @uiDisplayText, @uiDisplayDescription, GETDATE(), @user, GETDATE(), @user);
        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END
GO

/*
 * [adm].[sp_CreateGlobalPanelFilter].
 */
IF OBJECT_ID('adm.sp_CreateGlobalPanelFilter', 'P') IS NOT NULL
    DROP PROCEDURE [adm].[sp_CreateGlobalPanelFilter];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/8/26
-- Description: Create a new app.GlobalPanelFilter.
-- =======================================
CREATE PROCEDURE [adm].[sp_CreateGlobalPanelFilter]
    @sessionType auth.SessionType,
	@isInclusion bit,
	@sqlSetId int,
	@sqlSetWhere nvarchar(1000),
	@user auth.[User]
AS
BEGIN
    SET NOCOUNT ON

	SET @sessionType = CASE @sessionType WHEN 0 THEN NULL ELSE @sessionType END

    BEGIN TRAN;
    BEGIN TRY

        INSERT INTO app.GlobalPanelFilter (SessionType, IsInclusion, SqlSetId, SqlSetWhere, Created, CreatedBy, Updated, UpdatedBy)
        OUTPUT 
			inserted.Id
		  , inserted.SessionType
		  , inserted.IsInclusion
		  , inserted.SqlSetId
		  , inserted.SqlSetWhere
        VALUES (@sessionType, @isInclusion, @sqlSetId, @sqlSetWhere, GETDATE(), @user, GETDATE(), @user);
        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END
GO

/*
 * [adm].[sp_UpdatePanelFilter].
 */
IF OBJECT_ID('adm.sp_UpdatePanelFilter', 'P') IS NOT NULL
    DROP PROCEDURE [adm].[sp_UpdatePanelFilter];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/8/26
-- Description: Updates a app.PanelFilter.
-- =======================================
CREATE PROCEDURE [adm].[sp_UpdatePanelFilter]
	@id int,
    @conceptId uniqueidentifier,
    @isInclusion bit,
	@uiDisplayText nvarchar(1000),
	@uiDisplayDescription nvarchar(4000),
	@user auth.[User]
AS
BEGIN
    SET NOCOUNT ON

	IF NOT EXISTS (SELECT 1 FROM app.Concept WHERE Id = @conceptId)
        THROW 70400, N'PanelFilter.Concept does not exist.', 1;

    IF (app.fn_NullOrWhitespace(@uiDisplayText) = 1)
        THROW 70400, N'PanelFilter.UiDisplayText is required.', 1;

	IF (app.fn_NullOrWhitespace(@uiDisplayDescription) = 1)
        THROW 70400, N'PanelFilter.UiDisplayDescription is required.', 1;

    BEGIN TRAN;
    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM app.PanelFilter WHERE Id = @id)
            THROW 70409, N'PanelFilter does not exist.', 1;

		UPDATE app.PanelFilter
		SET ConceptId = @conceptId
		  , IsInclusion = @isInclusion
		  , UiDisplayText = @uiDisplayText
		  , UiDisplayDescription = @uiDisplayDescription
		  , Updated = GETDATE()
		  , UpdatedBy = @user
		OUTPUT inserted.Id, inserted.ConceptId, inserted.IsInclusion, inserted.UiDisplayText, inserted.UiDisplayDescription
		WHERE Id = @id

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END
GO

/*
 * [adm].[sp_UpdateGlobalPanelFilter].
 */
IF OBJECT_ID('adm.sp_UpdateGlobalPanelFilter', 'P') IS NOT NULL
    DROP PROCEDURE [adm].[sp_UpdateGlobalPanelFilter];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/8/26
-- Description: Updates an app.GlobalPanelFilter.
-- =======================================
CREATE PROCEDURE [adm].[sp_UpdateGlobalPanelFilter]
	@id int,
    @sessionType auth.SessionType,
	@isInclusion bit,
	@sqlSetId int,
	@sqlSetWhere nvarchar(1000),
	@user auth.[User]
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRAN;
    BEGIN TRY

		IF NOT EXISTS (SELECT 1 FROM app.GlobalPanelFilter WHERE Id = @id)
            THROW 70409, N'GlobalPanelFilter does not exist.', 1;

		SET @sessionType = CASE @sessionType WHEN 0 THEN NULL ELSE @sessionType END

		UPDATE app.GlobalPanelFilter
		SET SessionType = @sessionType
		  , IsInclusion = @isInclusion
		  , SqlSetId = @sqlSetId
		  , SqlSetWhere = @sqlSetWhere
		  , Updated = GETDATE()
		  , UpdatedBy = @user
		OUTPUT inserted.Id, inserted.SessionType, inserted.IsInclusion, inserted.SqlSetId, inserted.SqlSetWhere
		WHERE Id = @id

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END
GO

/*
 * [adm].[sp_DeletePanelFilter].
 */
IF OBJECT_ID('adm.sp_DeletePanelFilter', 'P') IS NOT NULL
    DROP PROCEDURE [adm].[sp_DeletePanelFilter];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/8/26
-- Description: Deletes an app.PanelFilter.
-- =======================================
CREATE PROCEDURE [adm].[sp_DeletePanelFilter]
	@id int
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRAN;
    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM app.PanelFilter WHERE Id = @id)
            THROW 70409, N'PanelFilter does not exist.', 1;

		DELETE app.PanelFilter
		OUTPUT deleted.Id
		WHERE Id = @id;

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END
GO

/*
 * [adm].[sp_DeleteGlobalPanelFilter].
 */
IF OBJECT_ID('adm.sp_DeleteGlobalPanelFilter', 'P') IS NOT NULL
    DROP PROCEDURE [adm].[sp_DeleteGlobalPanelFilter];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/8/26
-- Description: Deletes an app.GlobalPanelFilter.
-- =======================================
CREATE PROCEDURE [adm].[sp_DeleteGlobalPanelFilter]
	@id int
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRAN;
    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM app.GlobalPanelFilter WHERE Id = @id)
            THROW 70409, N'GlobalPanelFilter does not exist.', 1;

		DELETE app.GlobalPanelFilter
		OUTPUT deleted.Id
		WHERE Id = @id;

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        THROW;
    END CATCH;
END
GO

/*
 * [adm].[sp_GetPanelFilters].
 */
IF OBJECT_ID('adm.sp_GetPanelFilters', 'P') IS NOT NULL
    DROP PROCEDURE [adm].[sp_GetPanelFilters];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/8/26 
-- Description: Gets all panel filters.
-- =======================================
CREATE PROCEDURE [adm].[sp_GetPanelFilters]
AS
BEGIN
    
	SELECT
		Id
	  , ConceptId
	  , IsInclusion
	  , UiDisplayText
	  , UiDisplayDescription
	FROM app.PanelFilter

END
GO

/*
 * [adm].[sp_GetGlobalPanelFilters].
 */
IF OBJECT_ID('adm.sp_GetGlobalPanelFilters', 'P') IS NOT NULL
    DROP PROCEDURE [adm].[sp_GetGlobalPanelFilters];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/8/26
-- Description: Gets all GlobalPanelFilters.
-- =======================================
CREATE PROCEDURE [adm].[sp_GetGlobalPanelFilters]
AS
BEGIN
    
	SELECT
		Id
	  , SessionType
	  , IsInclusion
	  , SqlSetId
	  , SqlSetWhere
	FROM app.GlobalPanelFilter

END
GO

/*
 * [app].[sp_GetPreflightResourcesByIds].
 */
IF OBJECT_ID('app.sp_GetPreflightResourcesByIds', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetPreflightResourcesByIds];
GO
-- =======================================
-- Author:      Cliff Spital
-- Create date: 2019/2/4
-- Description: Performs a preflight resource check by Ids.
-- =======================================
CREATE PROCEDURE [app].[sp_GetPreflightResourcesByIds]
    @qids app.ResourceIdTable READONLY,
    @cids app.ResourceIdTable READONLY,
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @sessionType auth.SessionType,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

    exec app.sp_GetPreflightQueriesByIds @qids, @user, @groups, @admin = @admin;

    exec app.sp_GetPreflightConceptsByIds @cids, @user, @groups, @admin = @admin;

    exec app.sp_GetPreflightGlobalPanelFilters @sessionType;
END
GO

/*
 * [app].[sp_GetPreflightResourcesByUIds].
 */
IF OBJECT_ID('app.sp_GetPreflightResourcesByUIds', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetPreflightResourcesByUIds];
GO
-- =======================================
-- Author:      Cliff Spital
-- Create date: 2019/2/4
-- Description: Performs a preflight resources check by UIds
-- =======================================
CREATE PROCEDURE [app].[sp_GetPreflightResourcesByUIds]
    @quids app.ResourceUniversalIdTable READONLY,
    @cuids app.ResourceUniversalIdTable READONLY,
    @user auth.[User],
    @groups auth.GroupMembership READONLY,
    @sessionType auth.SessionType,
    @admin bit = 0
AS
BEGIN
    SET NOCOUNT ON

    exec app.sp_GetPreflightQueriesByUIds @quids, @user, @groups, @admin = @admin;

    exec app.sp_GetPreflightConceptsByUIds @cuids, @user, @groups, @admin = @admin;

    exec app.sp_GetPreflightGlobalPanelFilters @sessionType;
END
GO

/*
 * [app].[sp_GetPreflightGlobalPanelFilters].
 */
IF OBJECT_ID('app.sp_GetPreflightGlobalPanelFilters', 'P') IS NOT NULL
    DROP PROCEDURE [app].[sp_GetPreflightGlobalPanelFilters];
GO
-- =======================================
-- Author:      Nic Dobbins
-- Create date: 2019/9/5
-- Description: Retrieves global panel filters 
--              relevant to current session context
-- =======================================
CREATE PROCEDURE [app].[sp_GetPreflightGlobalPanelFilters]
    @sessionType auth.SessionType
AS
BEGIN
    SET NOCOUNT ON

    SELECT
        GPF.Id
      , GPF.IsInclusion
      , CS.SqlSetFrom
      , GPF.SqlSetWhere
    FROM app.GlobalPanelFilter AS GPF
         INNER JOIN app.ConceptSqlSet AS CS
            ON GPF.SqlSetId = CS.Id
    WHERE (GPF.SessionType = @sessionType OR GPF.SessionType IS NULL)
    
END
GO