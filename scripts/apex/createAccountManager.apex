// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents
List<User> accountManagers = new List<User>();

Id profileId = [select Id from Profile where Name = 'Account Manager'].Id;

for(Integer i = 0; i<20;i++){
    accountManagers.add(new User(
        Username = 'account.manager'+i+'@example.com',
        LastName = 'manager'+i,
        Email = 'account.manager'+i+'@example.com',
        Alias = 'am'+i,
        ProfileId = profileId,
        TimeZoneSidKey = 'Australia/Sydney',
        EmailEncodingKey = 'UTF-8',
        LocaleSidKey = 'en_AU',
        LanguageLocaleKey = 'en_US'

    ));
}
insert accountManagers;