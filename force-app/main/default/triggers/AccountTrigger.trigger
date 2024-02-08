trigger AccountTrigger on Account (before insert, before update) {

    // Trigger Switch can be implemented using Custom setting or custom metadata type, considering bulk import
    new AccountTriggerHandler().assignManagers(Trigger.New);
}