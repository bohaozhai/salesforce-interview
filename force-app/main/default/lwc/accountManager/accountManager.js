import { api, LightningElement } from "lwc";
import ACCOUNT_MANAGER_FIELD from '@salesforce/schema/Account.Account_Manager__c';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name'

export default class AccountManager extends LightningElement {
    fields = [ACCOUNT_NAME_FIELD, ACCOUNT_MANAGER_FIELD]
    @api recordId
    @api objectApiName
}