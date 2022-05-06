﻿/* Item */
-------------------------------------------------
create or alter view cat.[view_Items]
as
select [Id!!Id] = i.Id, 
	[Name!!Name] = i.[Name], i.Article, i.Memo,
	[Unit.Id!TUnit!Id] = i.Unit, [Unit.Short!TUnit] = u.Short,
	[Role.Id!TItemRole!Id] = i.[Role], [Role.Name!TItemRole!Name] = ir.[Name], [Role.Color!TItemRole!] = ir.Color,
	[CostItem.Id!TCostItem!Id] = ir.CostItem, [CostItem.Name!TCostItem!Name] = ci.[Name],
	ItemRole = i.[Role],
	[!TenantId] = i.TenantId
from cat.Items i
	left join cat.Units u on i.TenantId = u.TenantId and i.Unit = u.Id
	left join cat.ItemRoles ir on i.TenantId = ir.TenantId and i.[Role] = ir.Id
	left join cat.CostItems ci on ir.TenantId = ci.TenantId and ir.CostItem =ci.Id
go
-------------------------------------------------
create or alter procedure cat.[Item.Group.Index]
@TenantId int = 1,
@UserId bigint,
@Group bigint = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	if @Group is null
		select top(1) @Group = Id from cat.ItemTree where TenantId = @TenantId and Parent = 0 and Id = [Root] and Id <> 0;

	with T(Id, _order, [Name], HasChildren, Icon)
	as (
		select Id = -1, 0, [Name] = N'@[NoGrouping]', 0, Icon=N'package-outline'
		union all
		-- hack = negative!
		select Id = -@Group, 2, [Name] = N'@[WithoutGroup]', 0, Icon=N'ban'
		union all
		select Id, 1, [Name],
			HasChildren= case when exists(
				select 1 from cat.ItemTree it where it.Void = 0 
				and it.Parent = t.Id and it.TenantId = @TenantId and t.TenantId = @TenantId
			) then 1 else 0 end,
			Icon = N'folder-outline'
		from cat.ItemTree t
			where t.TenantId = @TenantId and t.Void = 0 and t.Parent = @Group
	)
	select [Groups!TGroup!Tree] = null, [Id!!Id] = Id, [Name!!Name] = [Name], Icon,
		/*nested folders - lazy*/
		[Items!TGroup!Items] = null, 
		/* marker: subfolders exist */
		[HasSubItems!!HasChildren] = HasChildren,
		/*nested items (not folders!) */
		[Elements!TItem!LazyArray] = null
	from T
	order by _order, [Id];

	-- Elements definition
	select [!TItem!Array] = null, [Id!!Id] = i.Id, [Name!!Name] = i.[Name], 
		i.Article, i.Memo, [Role!TItemRole!RefId] = i.[Role], [ItemRole] = i.[Role],
		[Unit.Id!TUnit!Id] = i.Unit, [Unit.Short!TUnit] = u.Short
	from cat.Items i
		left join cat.Units u on i.TenantId = u.TenantId and i.Unit = u.Id
	where 0 <> 0;

	select [!TItemRole!Map] = null, [Id!!Id] = ir.Id, [Name!!Name] = ir.[Name], ir.Color
	from cat.ItemRoles ir 
	where 0 <> 0;

	-- filters
	select [Hierarchies!THie!Array] = null, [Id!!Id] = Id, [Name!!Name] = [Name]
	from cat.ItemTree where TenantId = @TenantId and Parent = 0 and Id <> Parent and Id <> 0;

	select [!$System!] = null,
		[!Hierarchies.Group!Filter] = @Group
end
go
-------------------------------------------------
create or alter procedure cat.[Item.Group.Expand]
@TenantId int = 1,
@UserId bigint,
@Id bigint,
@Group bigint = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	select [Items!TGroup!Tree] = null, [Id!!Id] = Id, [Name!!Name] = [Name],
		[Items!TGroup!Items] = null,
		[HasSubItems!!HasChildren] = case when exists(select 1 from cat.ItemTree c where c.Void=0 and c.Parent=a.Id) then 1 else 0 end,
		Icon = N'folder-outline'
	from cat.ItemTree a where Parent = @Id and Void=0;
end
go
-------------------------------------------------
create or alter procedure cat.[Item.Group.Elements]
@TenantId int = 1,
@UserId bigint,
@Id bigint = null, -- GroupId
@Offset int = 0, 
@PageSize int = 20,
@Order nvarchar(255) = N'name',
@Dir nvarchar(20) = N'asc',
@Fragment nvarchar(255) = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @Asc nvarchar(10), @Desc nvarchar(10), @RowCount int;
	declare @fr nvarchar(255);

	set @Asc = N'asc'; set @Desc = N'desc';
	set @Dir = lower(isnull(@Dir, @Asc));
	set @Order = lower(@Order);
	set @fr = N'%' + @Fragment + N'%';

	declare @items table(rowno int identity(1, 1), id bigint, unit bigint, [role] bigint, rowcnt int);
	--@Id = ite.Parent or 
	insert into @items(id, unit, [role], rowcnt)
	select i.Id, i.Unit, i.[Role],
		count(*) over()
	from cat.Items i
		left join cat.ItemTreeElems ite on i.TenantId = ite.TenantId and i.Id = ite.Item
	where i.TenantId = @TenantId
		and (@Id = -1 or @Id = ite.Parent or (@Id < 0 and i.Id not in (
			select Item from cat.ItemTreeElems intbl where intbl.TenantId = @TenantId and intbl.[Root] = -@Id /*hack:negative*/
		)))
		and (@fr is null or [Name] like @fr or Memo like @fr or Article like @fr)
	group by i.Id, i.Unit, i.[Name], i.Article, i.Memo, i.[Role]
	order by 
		case when @Dir = N'asc' then
			case @Order 
				when N'name' then i.[Name]
				when N'article' then i.[Article]
				when N'memo' then i.[Memo]
			end
		end asc,
		case when @Dir = N'desc' then
			case @Order
				when N'name' then i.[Name]
				when N'article' then i.[Article]
				when N'memo' then i.[Memo]
			end
		end desc,
		i.Id
	offset @Offset rows fetch next @PageSize rows only
	option (recompile);

	select [Elements!TItem!Array] = null, [Id!!Id] = i.Id, [Name!!Name] = i.[Name], 
		i.Article, i.Memo, [Role!TItemRole!RefId] = i.[Role], ItemRole = i.[Role],
		[Unit.Id!TUnit!Id] = i.Unit, [Unit.Short!TUnit] = u.Short,
		[!!RowCount]  = t.rowcnt
	from @items t inner join cat.Items i on i.TenantId = @TenantId and i.Id = t.id
		left join cat.Units u on i.TenantId = u.TenantId and i.Unit = u.Id
	order by t.rowno;

	with R([role]) as (select [role] from @items group by [role])
	select [!TItemRole!Map] = null, [Id!!Id] = ir.Id, [Name!!Name] = ir.[Name], ir.Color
	from cat.ItemRoles ir inner join R on ir.TenantId = @TenantId and ir.Id = R.[role];

	-- system data
	select [!$System!] = null,
		[!Elements!Offset] = @Offset, [!Elements!PageSize] = @PageSize, 
		[!Elements!SortOrder] = @Order, [!Elements!SortDir] = @Dir,
		[!Elements.Fragment!Filter] = @Fragment;
end
go
-------------------------------------------------
create or alter procedure cat.[Item.Plain.Index]
@TenantId int = 1,
@UserId bigint,
@Offset int = 0,
@PageSize int = 20,
@Order nvarchar(255) = N'date',
@Dir nvarchar(20) = N'asc',
@Fragment nvarchar(255) = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	set @Order = lower(@Order);
	set @Dir = lower(@Dir);
	
	declare @fr nvarchar(255);
	set @fr = N'%' + @Fragment + N'%';


	declare @items table(rowno int identity(1, 1), id bigint, unit bigint, rowcnt int);

	insert into @items(id, unit, rowcnt)
	select i.Id, i.Unit, 
		count(*) over()
	from cat.Items i
	where i.TenantId = @TenantId
		and (@fr is null or i.Name like @fr or i.FullName like @fr or i.Memo like @fr or i.Article like @fr)
	order by 
		case when @Dir = N'asc' then
			case @Order 
				when N'id' then i.[Id]
			end
		end asc,
		case when @Dir = N'asc' then
			case @Order 
				when N'name' then i.[Name]
				when N'fullname' then i.[FullName]
				when N'article' then i.[Article]
				when N'memo' then i.[Memo]
			end
		end asc,
		case when @Dir = N'desc' then
			case @Order
				when N'id' then i.[Id]
			end
		end desc,
		case when @Dir = N'desc' then
			case @Order
				when N'name' then i.[Name]
				when N'fullname' then i.[FullName]
				when N'article' then i.[Article]
				when N'memo' then i.[Memo]
			end
		end desc
	offset @Offset rows fetch next @PageSize rows only
	option (recompile);

	select [Items!TItem!Array] = null, [Id!!Id] = i.Id, [Name!!Name] = i.[Name], i.Article, i.Memo,
		[Role!TItemRole!RefId] = i.[Role], ItemRole = i.[Role],
		[Unit!TUnit!RefId] = i.Unit,
		[!!RowCount] = t.rowcnt
	from @items t inner join cat.Items i on i.TenantId = @TenantId and t.id = i.Id
	order by t.rowno;

	-- maps
	with T as (select unit from @items group by unit)
	select [!TUnit!Map] = null, [Id!!Id] = u.Id, u.[Short]
	from cat.Units u 
		inner join T t on u.TenantId = @TenantId and u.Id = unit;

	-- filter
	select [!$System!] = null, [!Items!Offset] = @Offset, [!Items!PageSize] = @PageSize, 
		[!Items!SortOrder] = @Order, [!Items!SortDir] = @Dir,
		[!Items.Fragment!Filter] = @Fragment;
end
go
------------------------------------------------
drop procedure if exists cat.[Item.Metadata];
drop procedure if exists cat.[Item.Update];
drop type if exists cat.[Item.TableType];
drop type if exists cat.[ItemTreeElem.TableType];
go
------------------------------------------------
create type cat.[Item.TableType]
as table(
	Id bigint null,
	[Name] nvarchar(255),
	Article nvarchar(32),
	FullName nvarchar(255),
	[Memo] nvarchar(255),
	[Role] bigint,
	Unit bigint
);
go
-------------------------------------------------
create type cat.[ItemTreeElem.TableType]
as table(
	[Group] bigint, -- Parent
	ParentId bigint -- Root
);
go
------------------------------------------------
create or alter procedure cat.[Item.Load]
@TenantId int = 1,
@UserId bigint,
@Id bigint = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	select [Item!TItem!Object] = null, [Id!!Id] = i.Id, [Name!!Name] = i.[Name], i.FullName, i.Article, i.Memo,
		[Role!TItemRole!RefId] = i.[Role], ItemRole = i.[Role],
		[Unit.Id!TUnit!Id] = i.Unit, [Unit.Short!TUnit] = u.Short
	from cat.Items i 
		left join cat.Units u on  i.TenantId = u.TenantId and i.Unit = u.Id
	where i.TenantId = @TenantId and i.Id=@Id and i.Void = 0;

	select [Hierarchies!THie!Array] = null, [Id!!Id] = Id, [Name!!Name] = [Name],
		[Elements!THieElem!Array] = null
	from cat.ItemTree where TenantId = @TenantId and Parent = 0 and Id = [Root] and Id <> 0;

	select [ItemRoles!TItemRole!Array] = null, [Id!!Id] = ir.Id, [Name!!Name] = ir.[Name], ir.Color
	from cat.ItemRoles ir 
	where ir.TenantId = @TenantId and ir.Void = 0;
	
	select [!THieElem!Array] = null, [!THie.Elements!ParentId] = iti.[Root],
		[Group] = iti.Parent,
		[Path] = cat.fn_GetItemBreadcrumbs(@TenantId, iti.Parent, null)
	from cat.ItemTreeElems iti 
	where TenantId = @TenantId  and iti.Item = @Id;
end
go
-------------------------------------------------
create or alter procedure cat.[Item.Metadata]
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	declare @Item cat.[Item.TableType];
	declare @Groups cat.[ItemTreeElem.TableType];
	select [Item!Item!Metadata] = null, * from @Item;
	select [Groups!Item.Hierarchies.Elements!Metadata] = null, * from @Groups;
end
go
-------------------------------------------------
create or alter procedure cat.[Item.Update]
@TenantId int = 1,
@UserId bigint,
@Item cat.[Item.TableType] readonly,
@Groups cat.[ItemTreeElem.TableType] readonly,
@RetId bigint = null output
as
begin
	set nocount on;
	set transaction isolation level read committed;

	/*
	declare @xml nvarchar(max);
	set @xml = (select * from @Groups for xml auto);
	throw 60000, @xml, 0;
	*/

	declare @output table(op sysname, id bigint);

	begin tran;
	merge cat.Items as t
	using @Item as s
	on (t.Id = s.Id and t.TenantId = @TenantId)
	when matched then
		update set 
			t.[Name] = s.[Name],
			t.FullName = s.FullName,
			t.[Article] = s.[Article],
			t.Memo = s.Memo,
			t.[Role] = s.[Role],
			t.Unit = s.Unit
	when not matched by target then 
		insert (TenantId, [Name], FullName, [Article], Memo, [Role], Unit)
		values (@TenantId, s.[Name], s.FullName, s.Article, s.Memo, s.[Role], s.Unit)
	output 
		$action op, inserted.Id id
	into @output(op, id);

	select top(1) @RetId = id from @output;

	merge cat.ItemTreeElems as t
	using @Groups as s
	on t.TenantId = @TenantId and t.[Root] = s.ParentId and t.[Parent] = s.[Group] and t.Item = @RetId
	when not matched by target then insert
		(TenantId, [Root], [Parent], Item) values
		(@TenantId, s.ParentId, s.[Group], @RetId)
	when not matched by source and t.TenantId=@TenantId and t.Item = @RetId then delete;

	commit tran;

	exec cat.[Item.Load] @TenantId = @TenantId, @UserId = @UserId, @Id = @RetId;
end
go
------------------------------------------------
create or alter procedure cat.[Item.Folder.GetPath]
@TenantId int = 1,
@UserId bigint,
@Id bigint,
@Root bigint
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	with T(Id, Parent, [Level]) as (
		select cast(null as bigint), @Id, 0
		union all
		select tr.Id, tr.Parent, [Level] + 1 
			from cat.ItemTree tr inner join T on tr.Id = T.Parent and tr.TenantId = @TenantId
		where tr.Id <> @Root
	)
	select [Result!TResult!Array] = null, [Id] = Id from T where Id is not null order by [Level] desc;
end
go
------------------------------------------------
create or alter procedure cat.[Item.Item.FindIndex]
@TenantId int = 1,
@UserId bigint,
@Id bigint,
@Parent bigint,
@Order nvarchar(255) = N'name',
@Dir nvarchar(20) = N'asc'
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @Asc nvarchar(10), @Desc nvarchar(10), @RowCount int;

	set @Asc = N'asc'; set @Desc = N'desc';
	set @Dir = lower(isnull(@Dir, @Asc));
	set @Order = lower(@Order);

	with T(Id, RowNumber)
	as (
		select Id, [RowNumber] = row_number() over (
				order by 
					case when @Order=N'id'   and @Dir=@Asc  then i.Id end asc,
					case when @Order=N'id'   and @Dir=@Desc then i.Id end desc,
					case when @Order=N'name' and @Dir=@Asc  then i.[Name] end asc,
					case when @Order=N'name' and @Dir=@Desc then i.[Name] end desc,
					case when @Order=N'article' and @Dir=@Asc  then i.Article end asc,
					case when @Order=N'article' and @Dir=@Desc then i.Article end desc,
					case when @Order=N'memo' and @Dir=@Asc  then i.Memo end asc,
					case when @Order=N'memo' and @Dir=@Desc then i.Memo end desc
			)
			from cat.Items i inner join cat.ItemTreeItems iti on
			i.TenantId = iti.TenantId and i.Id = iti.Item
			where iti.Parent = @Parent and iti.TenantId = @TenantId
	)
	select [Result!TResult!Object] = null, T.Id, RowNo = T.RowNumber - 1 /*row_number is 1-based*/
	from T
	where T.Id = @Id;
end
go
------------------------------------------------
create or alter procedure cat.[Item.Folder.Delete]
@TenantId int = 1,
@UserId bigint,
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read committed;
	set xact_abort on;

	if exists(select 1 from cat.ItemTree where TenantId=@TenantId and Parent = @Id and Void = 0) or
	   exists(select 1 from cat.ItemTree where TenantId=@TenantId and Parent = @Id and Void = 0)
		throw 60000, N'UI:@[Error.Delete.Folder]', 0;
	update cat.ItemTree set Void=1 where TenantId = @TenantId and Id = @Id;
end
go
------------------------------------------------
create or alter procedure cat.[Item.Item.Delete]
@TenantId int = 1,
@UserId bigint,
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read committed;
	set xact_abort on;
	-- TODO: check if there are any references
	begin tran
	update cat.Items set Void=1 where TenantId = @TenantId and Id = @Id;
	/*
	delete from cat.ItemTreeItems where
		TenantId = @TenantId and Item = @Id;
	*/
	commit tran;
end
go
-------------------------------------------------
create or alter procedure cat.[Item.Browse.Index]
@TenantId int = 1,
@UserId bigint,
@Id bigint = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	select [Items!TItem!Array] = null, *
	from cat.view_Items v
	where v.[!TenantId] = @TenantId
	order by v.[Id!!Id];
end
go
-------------------------------------------------
create or alter procedure cat.[Item.Find.Article]
@TenantId int = 1,
@UserId bigint,
@Text nvarchar(255) = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	select top(1) [Item!TItem!Object] = null, *
	from cat.view_Items v
	where v.[!TenantId] = @TenantId and v.Article = @Text;
end
go
-------------------------------------------------
create or alter procedure cat.[Item.Rems.Load]
@TenantId int = 1,
@UserId bigint,
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	select [Item!TItem!Object] = null, [Id!!Id] = Id, [Name!!Name] = [Name]
	from cat.Items where TenantId = @TenantId and Id = @Id;

	select [Rems!TRem!Array] = null, WhId =  Id, [WhName] = w.[Name]
	from cat.Warehouses w where TenantId = @TenantId
	order by Id;
end
go