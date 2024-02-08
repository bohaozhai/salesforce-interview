public with sharing class AccountTriggerHandler {
    
    public void assignManagers(List<Account> accounts) {
        List<UserWithAccountCount> managers =  getManagersWithAccountCount();

        if(!managers.isEmpty()) {
            for(Account acc :accounts) {

                if(acc.Account_Manager__c == null) {
                    managers.sort();
                    acc.Account_Manager__c = managers[0].userId;
                    managers[0].count ++;
                }
                
            }
        }
    }


    public List<UserWithAccountCount> getManagersWithAccountCount() {
        List<User> accountManagers = [SELECT Id, (SELECT Id FROM Account_Managers__r) FROM User WHERE ProfileId = :GlobalConstants.ACCOUNT_MANAGER_PROFILE];

        List<UserWithAccountCount> userWithAccountCounts = new List<UserWithAccountCount>();
        for(User am: accountManagers) {
            UserWithAccountCount ua = new UserWithAccountCount(am.id, am.Account_Managers__r.size());
           
            userWithAccountCounts.add(ua);
        }

        return userWithAccountCounts;
    }


    
    public Class UserWithAccountCount implements Comparable {
        public Id userId;
        public Integer count;

        public UserWithAccountCount(Id userId, Integer count) {
            this.userId = userId;
            this.count = count;
        }

        public Integer compareTo(Object obj) {
            UserWithAccountCount ua = (UserWithAccountCount)obj;
            return this.count > ua.count? 1 : (this.count < ua.count? -1 : 0);
        }

    }

}