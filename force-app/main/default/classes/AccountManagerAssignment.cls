public with sharing class AccountManagerAssignment implements Schedulable {
    public void execute(SchedulableContext context) {
        List<User> accountManagers;
        List<Account> unassignedAccounts = [SELECT Id FROM Account WHERE Account_Manager__c = NULL];
        Iterator<Account> accountIterator = unassignedAccounts.iterator();

        while(accountIterator.hasNext()){
            Account unassignedAccount = accountIterator.next();
            if(accountManagers == null || accountManagers.isEmpty()){
                accountManagers = fetchAccountManager();
            }
            unassignedAccount.Account_Manager__c = accountManagers.remove(0).Id;
        }
        update unassignedAccounts;
    }

    private static List<User> fetchAccountManager(){
        List<User> accountManagers = [SELECT Id, (SELECT Id FROM Account_Managers__r) FROM User WHERE ProfileId = :GlobalConstants.ACCOUNT_MANAGER_PROFILE];
        accountManagers.sort();
        return accountManagers;
    }

    private class UserComparator implements Comparator<User> {
        public Integer compare(User user1, User user2) {
            return user1.Account_Managers__r.size() > user2.Account_Managers__r.size() ? 1 :
                user1.Account_Managers__r.size() < user2.Account_Managers__r.size() ? -1 : 0;
        }
    }
}