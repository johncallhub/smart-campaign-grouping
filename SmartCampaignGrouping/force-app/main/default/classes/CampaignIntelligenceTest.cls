@isTest
public class CampaignIntelligenceTest {
    
    @TestSetup
    static void setupTestData() {
        List<Campaign> testCampaigns = new List<Campaign>{
            new Campaign(Name = 'CallHub June Rally 2024', Type = 'Outbound', IsActive = true),
            new Campaign(Name = 'Pardot Email June Rally Supporters', Type = 'Email', IsActive = true),
            new Campaign(Name = 'SMS June Rally Reminder', Type = 'SMS', IsActive = true),
            new Campaign(Name = 'Facebook June Rally Event', Type = 'Social', IsActive = true),
            new Campaign(Name = 'July Fundraiser Call', Type = 'Outbound', IsActive = true),
            new Campaign(Name = 'Text July Fundraising Ask', Type = 'SMS', IsActive = true),
            new Campaign(Name = 'Single Campaign', Type = 'Other', IsActive = true)
        };
        insert testCampaigns;
    }
    
    @isTest
    static void testAutoGroupCampaigns() {
        Test.startTest();
        
        CampaignIntelligence.autoGroupCampaigns();
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id, Suggested_Initiative_Name__c, Confidence_Score__c,
                   (SELECT Campaign__r.Name FROM Campaign_Suggestion_Members__r)
            FROM Campaign_Grouping_Suggestion__c
        ];
        
        System.assert(suggestions.size() > 0, 'Should create grouping suggestions');
        
        Boolean foundJuneRally = false;
        Boolean foundJulyFundraiser = false;
        
        for(Campaign_Grouping_Suggestion__c suggestion : suggestions) {
            if(suggestion.Suggested_Initiative_Name__c.contains('June Rally')) {
                foundJuneRally = true;
                System.assert(suggestion.Campaign_Suggestion_Members__r.size() >= 2, 
                    'June Rally should group multiple campaigns');
            }
            if(suggestion.Suggested_Initiative_Name__c.contains('July Fundraiser')) {
                foundJulyFundraiser = true;
            }
        }
        
        System.assert(foundJuneRally, 'Should find June Rally grouping');
        System.assert(foundJulyFundraiser, 'Should find July Fundraiser grouping');
    }
    
    @isTest
    static void testExtractKeyPattern() {
        Test.startTest();
        
        String pattern1 = CampaignIntelligence.extractKeyPattern('CallHub June Rally 2024');
        String pattern2 = CampaignIntelligence.extractKeyPattern('Pardot Email June Rally Supporters');
        String pattern3 = CampaignIntelligence.extractKeyPattern('July Fundraiser Phone Calls');
        String pattern4 = CampaignIntelligence.extractKeyPattern('Voter Registration Drive September');
        
        Test.stopTest();
        
        System.assertEquals('June Rally', pattern1, 'Should extract June Rally pattern');
        System.assertEquals('June Rally', pattern2, 'Should extract same pattern for related campaigns');
        System.assertEquals('July Fundraiser', pattern3, 'Should extract July Fundraiser pattern');
        System.assertEquals('September Registration Drive', pattern4, 'Should extract voter registration pattern');
    }
    
    @isTest
    static void testPatternStandardization() {
        Test.startTest();
        
        String pattern1 = CampaignIntelligence.extractKeyPattern('jan voter registration');
        String pattern2 = CampaignIntelligence.extractKeyPattern('January Voter outreach');
        String pattern3 = CampaignIntelligence.extractKeyPattern('feb fundrais event');
        
        Test.stopTest();
        
        System.assert(pattern1.contains('January'), 'Should standardize jan to January');
        System.assert(pattern2.contains('January'), 'Should keep January as January');
        System.assert(pattern3.contains('February'), 'Should standardize feb to February');
        System.assert(pattern3.contains('Fundraiser'), 'Should standardize fundrais to Fundraiser');
    }
    
    @isTest
    static void testInvocableMethod() {
        Test.startTest();
        
        CampaignIntelligence.autoGroupCampaigns();
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c
        ];
        
        System.assert(suggestions.size() > 0, 'Invocable method should create suggestions');
    }
    
    @isTest
    static void testNoCampaignsScenario() {
        delete [SELECT Id FROM Campaign];
        
        Test.startTest();
        
        CampaignIntelligence.autoGroupCampaigns();
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c
        ];
        
        System.assertEquals(0, suggestions.size(), 'Should not create suggestions when no campaigns exist');
    }
    
    @isTest
    static void testSingleCampaignScenario() {
        delete [SELECT Id FROM Campaign WHERE Name != 'Single Campaign'];
        
        Test.startTest();
        
        CampaignIntelligence.autoGroupCampaigns();
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c
        ];
        
        System.assertEquals(0, suggestions.size(), 'Should not create suggestions for single campaigns');
    }
    
    @isTest
    static void testAlreadyGroupedCampaigns() {
        Campaign parentCampaign = new Campaign(
            Name = 'Parent Initiative',
            Type = 'Initiative',
            IsActive = true
        );
        insert parentCampaign;
        
        List<Campaign> campaigns = [SELECT Id FROM Campaign LIMIT 3];
        for(Campaign c : campaigns) {
            c.ParentId = parentCampaign.Id;
            c.Campaign_Initiative__c = 'Parent Initiative';
        }
        update campaigns;
        
        Test.startTest();
        
        CampaignIntelligence.autoGroupCampaigns();
        
        Test.stopTest();
        
        List<Campaign_Grouping_Suggestion__c> suggestions = [
            SELECT Id FROM Campaign_Grouping_Suggestion__c
        ];
        
        System.assert(suggestions.size() < 3, 'Should create fewer suggestions when campaigns are already grouped');
    }
}