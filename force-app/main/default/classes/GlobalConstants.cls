public class GlobalConstants {
    public static Id ACCOUNT_MANAGER_PROFILE = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;

}