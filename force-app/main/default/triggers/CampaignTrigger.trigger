trigger CampaignTrigger on Campaign (before insert, before update) {
    CampaignTriggerHandler.validate(Trigger.new);
}
