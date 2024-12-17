public class CampaignStage {
    final StageName name;

    public CampaignStage(StageName name) {
        this.name = name;
    }

    public CampaignStage addNextPossibleStage(CampaignStage stage) {
        return this;
    }

    public CampaignStage moveTo(StageName name) {
        return null;
    }

    public enum StageName {
        Planning,
        OpportunityIdentified,
        OpportunityDiscussed,
        ResponseShared,
        InNegotiation,
        ReviewOps,
        ReviewSales,
        BookingSent,
        ClosedWon,
        Revise,
        OpportunityLost
    }
}