﻿/* ITEM ROLE */
drop procedure if exists cat.[ItemRole.Metadata];
drop procedure if exists cat.[ItemRole.Update];
drop type if exists cat.[ItemRole.TableType];
drop type if exists cat.[ItemRoleAccount.TableType];
go
------------------------------------------------
create type cat.[ItemRole.TableType] as table
(
	Id bigint,
	[Name] nvarchar(255),
	[Memo] nvarchar(255),
	[Color] nvarchar(32)
)
go
------------------------------------------------
create type cat.[ItemRoleAccount.TableType] as table
(
	Id bigint,
	[Plan] bigint,
	Account bigint,
	AccKind bigint
)
go
------------------------------------------------
create or alter procedure cat.[ItemRole.Index]
@TenantId int = 1,
@UserId bigint,
@Id bigint = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	select [ItemRoles!TItemRole!Array] = null,
		[Id!!Id] = ir.Id, [Name!!Name] = ir.[Name], ir.Memo, ir.Color
	from cat.ItemRoles ir
	where TenantId = @TenantId
	order by ir.Id;
end
go
------------------------------------------------
create or alter procedure cat.[ItemRole.Load]
@TenantId int = 1,
@UserId bigint,
@Id bigint = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	select [ItemRole!TItemRole!Object] = null,
		[Id!!Id] = ir.Id, [Name!!Name] = ir.[Name], ir.Memo, ir.Color,
		[Accounts!TRoleAccount!Array] = null
	from cat.ItemRoles ir
	where ir.TenantId = @TenantId and ir.Id = @Id;

	select [!TRoleAccount!Array] = null, [Id!!Id] = ira.Id, [Plan!TAccount!RefId] = ira.[Plan],
		[Account!TAccount!RefId] = ira.Account, [AccKind!TAccKind!RefId] = ira.AccKind,
		[!TItemRole.Accounts!ParentId] = ira.[Role]
	from cat.ItemRoleAccounts ira
	where ira.TenantId = @TenantId and ira.[Role] = @Id;

	select [!TAccount!Map] = null, [Id!!Id] = a.Id, [Code] = a.Code, [Name!!Name] = a.[Name]
	from acc.Accounts a
		inner join cat.ItemRoleAccounts ira on a.TenantId = ira.TenantId and a.Id in (ira.[Plan], ira.[Account])
	where ira.TenantId = @TenantId and ira.[Role] = @Id
	group by a.Id, a.Code, a.[Name];

	select [AccKinds!TAccKind!Array] = null, [Id!!Id] = ak.Id, [Name!!Name] = ak.[Name]
	from acc.AccKinds ak
	where TenantId = @TenantId;
end
go
---------------------------------------------
create or alter procedure cat.[ItemRole.Metadata]
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @Role cat.[ItemRole.TableType];
	declare @Accounts cat.[ItemRoleAccount.TableType];
	select [ItemRole!ItemRole!Metadata] = null, * from @Role;
	select [Accounts!ItemRole.Accounts!Metadata] = null, * from @Accounts;
end
go
---------------------------------------------
create or alter procedure cat.[ItemRole.Update]
@TenantId int = 1,
@UserId bigint,
@ItemRole cat.[ItemRole.TableType] readonly,
@Accounts cat.[ItemRoleAccount.TableType] readonly
as
begin
	set nocount on;
	set transaction isolation level read committed;
	set xact_abort on;
	
	declare @output  table (op sysname, id bigint);
	declare @id bigint;

	merge cat.ItemRoles as t
	using @ItemRole as s on (t.TenantId = @TenantId and t.Id = s.Id)
	when matched then update set
		t.[Name] = s.[Name], 
		t.[Memo] = s.[Memo],
		t.Color = s.Color
	when not matched by target then insert
		(TenantId, [Name], Memo, Color) values
		(@TenantId, [Name], Memo, Color)
	output $action, inserted.Id into @output (op, id);

	select top(1) @id = id from @output;
	
	merge cat.ItemRoleAccounts as t
	using @Accounts as s on (t.TenantId = @TenantId and t.Id = s.Id)
	when matched then update set
		t.[Plan] = s.[Plan],
		t.Account = s.Account,
		t.AccKind = s.AccKind
	when not matched by target then insert
		(TenantId, [Role], [Plan], Account, AccKind) values
		(@TenantId, @id, s.[Plan], s.Account, s.AccKind)
	when not matched by source and t.TenantId = @TenantId and t.[Role] = @id then delete;

	exec cat.[ItemRole.Load] @TenantId = @TenantId, @UserId = @UserId, @Id = @id;
end
go
---------------------------------------------
create or alter procedure cat.[ItemRole.Delete]
@TenantId int = 1,
@UserId bigint,
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read committed;

	update cat.ItemRoles set Void = 1 where TenantId = @TenantId and Id=@Id;
end
go
