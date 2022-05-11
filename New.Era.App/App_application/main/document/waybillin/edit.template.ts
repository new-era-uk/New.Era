﻿// waybill in

const base: Template = require('/document/_common/stock.module');
const utils: Utils = require("std:utils");

const template: Template = {
	properties: {
		'TDocument.ESum': Number,
	},
	defaults: {
		'Document.WhTo'(this: any) { return this.Default.Warehouse; },
		'Document.DocApply.WriteSupplierPrices': true
	},
	validators: {
		'Document.WhTo': '@[Error.Required]'
	},
	events: {
		'Document.ServiceRows[].Item.change': itemChange,
		'Document.ServiceRows[].ItemRole.change': itemRoleChange
	}
};

export default utils.mergeTemplate(base, template);

// events
function itemChange(row, val) {
	base.events['Document.ServiceRows[].Item.change'].call(this, row, val);
	row.CostItem = val.Role.CostItem;
}

function itemRoleChange(row, val) {
	row.CostItem = val.CostItem;
}
