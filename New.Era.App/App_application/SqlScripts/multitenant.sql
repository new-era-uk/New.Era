﻿/*
version: 10.1.1012
generated: 21.04.2022 13:45:43
*/


/* SqlScripts/multitenant.sql */

/*
startup multitenant
*/

-------------------------------------------------
create or alter procedure appsec.OnCreateTenant 
@TenantId int
as
begin
	set nocount on
	exec ini.[Cat.OnCreateTenant] @TenantId = @TenantId;
	exec ini.[Forms.OnCreateTenant] @TenantId = @TenantId;
	exec ini.[Rep.OnCreateTenant] @TenantId = @TenantId;
end
go


